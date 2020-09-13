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
  -- RAILWAY
  SELECT
    railway_track_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_basemapping.gba_railway_tracks_sp r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
),

-- overlay with streams, creating intersection points
intersections AS
(
  SELECT
    r.railway_track_id,
    s.linear_feature_id,
    s.blue_line_key,
    s.wscode_ltree,
    s.localcode_ltree,
    s.length_metre,
    s.downstream_route_measure,
    s.geom as geom_s,
    s.edge_type,
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

-- spatial join to railway structures to find bridges
intersections_structures AS
(
  SELECT
    railway_track_id,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    geom_s,
    CASE
        WHEN i.edge_type IN (1200, 1250, 1300, 1350, 1400, 1450, 1475)
        OR UPPER(r.structure_type) LIKE 'BRIDGE%'
        THEN 'OBS'
        ELSE 'CBS'
    END as modelled_crossing_type,
    geom_x
  FROM intersections i
  LEFT OUTER JOIN whse_basemapping.gba_railway_structure_lines_sp r
  ON ST_Intersects(ST_Buffer(i.geom_x, 1), r.geom)
),

-- to eliminate duplication, cluster the crossings
clusters AS
(
  -- 20m clustering for railways
  SELECT
    max(railway_track_id) as railway_track_id,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    modelled_crossing_type,
    geom_s,
    ST_Centroid(unnest(ST_ClusterWithin(geom_x, 20))) as geom_x
  FROM intersections_structures
  GROUP BY linear_feature_id, blue_line_key, wscode_ltree, localcode_ltree, geom_s, length_metre, downstream_route_measure, modelled_crossing_type
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

-- finally, generate output point from the measure
INSERT INTO fish_passage.modelled_stream_crossings
(railway_track_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  modelled_crossing_type,
  geom)
SELECT
  railway_track_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure_pt as downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  :wsg AS watershed_group_code,
  modelled_crossing_type,
  (ST_Dump(ST_LocateAlong(geom_s, downstream_route_measure_pt))).geom as geom
FROM intersections_measures;