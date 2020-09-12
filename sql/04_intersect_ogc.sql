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
  AND s.localcode_ltree IS NOT NULL          -- exclude streams with no local code / invalid local code
),

roads AS
(
  -- OGC PERMITS
  SELECT
    og_road_segment_permit_id,
    NULL::int AS og_petrlm_dev_rd_pre06_pub_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_mineral_tenure.og_road_segment_permit_sp r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE status = 'Approved' AND road_type_desc != 'Snow Ice Road' -- exclude winter roads

  UNION ALL

  -- OGC PERMITS PRE 06
  SELECT
    NULL::int AS og_road_segment_permit_id,
    og_petrlm_dev_rd_pre06_pub_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE petrlm_development_road_type != 'WINT' -- exclude winter roads

),

-- overlay with streams, creating intersection points and labelling bridges
intersections AS
(
  SELECT
    r.og_road_segment_permit_id,
    r.og_petrlm_dev_rd_pre06_pub_id,
    s.linear_feature_id,
    s.blue_line_key,
    s.wscode_ltree,
    s.localcode_ltree,
    s.length_metre,
    s.downstream_route_measure,
    s.geom as geom_s,
    CASE
      WHEN s.edge_type IN (1200, 1250, 1300, 1350, 1400, 1450, 1475)
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
clusters AS
(
  -- 10m clustering
  SELECT
    max(og_road_segment_permit_id) AS og_road_segment_permit_id,
    max(og_petrlm_dev_rd_pre06_pub_id) AS og_petrlm_dev_rd_pre06_pub_id,
    linear_feature_id,
    blue_line_key,
    wscode_ltree,
    localcode_ltree,
    length_metre,
    downstream_route_measure,
    geom_s,
    modelled_crossing_type,
    ST_Centroid(unnest(ST_ClusterWithin(geom_x, 10))) as geom_x
  FROM intersections
  GROUP BY linear_feature_id, blue_line_key, wscode_ltree, localcode_ltree, geom_s, modelled_crossing_type, length_metre, downstream_route_measure
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
  (og_road_segment_permit_id,
  og_petrlm_dev_rd_pre06_pub_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  modelled_crossing_type,
  geom)
SELECT
  og_road_segment_permit_id,
  og_petrlm_dev_rd_pre06_pub_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure_pt as downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  :wsg AS watershed_group_code,
  modelled_crossing_type,
  (ST_Dump(ST_LocateAlong(geom_s, downstream_route_measure_pt))).geom as geom
FROM intersections_measures;