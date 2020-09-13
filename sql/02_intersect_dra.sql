WITH wsg AS
(
  SELECT watershed_group_code, geom
  FROM whse_basemapping.fwa_watershed_groups_poly
  WHERE watershed_group_code = :wsg
),

streams AS
(
  SELECT s.*
  FROM whse_basemapping.fwa_stream_networks_sp s
  INNER JOIN wsg
  ON s.watershed_group_code = wsg.watershed_group_code
  WHERE s.fwa_watershed_code NOT LIKE '999%' -- exclude streams that are not part of the network
  AND s.edge_type NOT IN (1410, 1425)        -- exclude subsurface flow
  AND s.localcode_ltree IS NOT NULL          -- exclude streams with no local code
),

roads AS
(
  -- DRA
  SELECT
    transport_line_id,
    transport_line_type_code,
    transport_line_structure_code,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_basemapping.transport_line r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE transport_line_type_code NOT IN ('F','FP','FR','T','TD','TR','TS','RP','RWA') -- exclude trails and ferry/water
  AND transport_line_surface_code != 'D'                                              -- exclude decomissioned roads
  AND COALESCE(transport_line_structure_code, '') != 'T'                              -- exclude tunnels
),

-- overlay with streams, creating intersection points and labelling bridges
intersections AS
(
  SELECT
    r.transport_line_id,
    r.transport_line_type_code,
    r.transport_line_structure_code,
    s.linear_feature_id,
    s.blue_line_key,
    s.wscode_ltree,
    s.localcode_ltree,
    s.length_metre,
    s.downstream_route_measure,
    s.geom as geom_s,
    CASE
      WHEN s.edge_type IN (1200, 1250, 1300, 1350, 1400, 1450, 1475) OR
           r.transport_line_structure_code IN ('B','C','E','F','O','R','V')
      THEN 'OBS'
      ELSE 'CBS'
    END as modelled_crossing_type,
    -- dump any collections/mulitpart features to singlepart
    (ST_Dump(
      ST_Intersection(
        (ST_Dump(ST_Force2d(r.geom))).geom,
        (ST_Dump(ST_Force2d(s.geom))).geom
      )
    )).geom AS geom_x
  FROM roads r
  INNER JOIN streams s
  ON ST_Intersects(r.geom, s.geom)
),

-- to eliminate duplication, cluster the crossings,
-- merging points on the same type of road/structure and on the same stream
-- do this for variable widths depending on level of road
clusters AS
(
  -- 30m clustering for freeways/highways
  SELECT
    max(transport_line_id) AS transport_line_id,
    transport_line_type_code,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    geom_s,
    modelled_crossing_type,
    ST_Centroid(unnest(ST_ClusterWithin(geom_x, 30))) as geom_x
  FROM intersections
  WHERE transport_line_type_code IN ('RF', 'RH1', 'RH2')
  GROUP BY transport_line_type_code, linear_feature_id, blue_line_key, wscode_ltree, localcode_ltree, geom_s, modelled_crossing_type, length_metre, downstream_route_measure
  UNION ALL
  -- 20m for arterial / collector
  SELECT
    max(transport_line_id) AS transport_line_id,
    transport_line_type_code,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    geom_s,
    modelled_crossing_type,
    ST_Centroid(unnest(ST_ClusterWithin(geom_x, 20))) as geom_x
  FROM intersections
  WHERE transport_line_type_code IN ('RA1', 'RA2', 'RC1', 'RC2')
  GROUP BY transport_line_type_code, linear_feature_id, blue_line_key, wscode_ltree, localcode_ltree, geom_s, modelled_crossing_type, length_metre, downstream_route_measure
  UNION ALL
  -- 12.5m for everything else
  SELECT
    max(transport_line_id) AS transport_line_id,
    transport_line_type_code,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    geom_s,
    modelled_crossing_type,
    ST_Centroid(unnest(ST_ClusterWithin(geom_x, 12.5))) as geom_x
  FROM intersections
  WHERE transport_line_type_code NOT IN ('RF', 'RH1', 'RH2','RA1', 'RA2', 'RC1', 'RC2')
  GROUP BY transport_line_type_code, linear_feature_id, blue_line_key, wscode_ltree, localcode_ltree, geom_s, modelled_crossing_type, length_metre, downstream_route_measure
),

-- derive measures
intersections_measures AS
(
  SELECT
    i.*,
    ST_LineLocatePoint(
       ST_Linemerge(geom_s),
       geom_x
      ) * length_metre + downstream_route_measure
    AS downstream_route_measure_pt
  FROM clusters i
)

-- finally, generate the point from the measure.
INSERT INTO fish_passage.modelled_stream_crossings
  (transport_line_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  modelled_crossing_type,
  geom)
SELECT
  transport_line_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure_pt as downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  :wsg AS watershed_group_code,
  modelled_crossing_type,
  (ST_Dump(ST_LocateAlong(geom_s, downstream_route_measure_pt))).geom as geom
FROM intersections_measures;