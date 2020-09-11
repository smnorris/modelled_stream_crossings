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
),

roads AS
(
  -- DRA
  SELECT
    transport_line_id,
    NULL::text AS ften_road_segment_id,
    NULL::int AS og_road_segment_permit_id,
    NULL::int AS og_petrlm_dev_rd_pre06_pub_id,
    NULL::int AS railway_track_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_basemapping.transport_line r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE transport_line_type_code NOT IN ('F','FP','FR','T','TD','TR','TS','RP','RWA') -- exclude trails and ferry/water
  AND transport_line_surface_code NOT IN ('D')  -- exclude decomissioned roads

  UNION ALL

  -- FTEN
  SELECT
    NULL::int AS transport_line_id,
    id AS ften_road_segment_id,  -- this id is supplied by the WFS, may want to choose something that be linked back to BCGW?
    NULL::int AS og_road_segment_permit_id,
    NULL::int AS og_petrlm_dev_rd_pre06_pub_id,
    NULL::int AS railway_track_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_forest_tenure.ften_road_segment_lines_svw r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE life_cycle_status_code not in ('RETIRED', 'PENDING')  -- active tenures only

  UNION ALL

  -- OGC PERMITS
  SELECT
    NULL::int AS transport_line_id,
    NULL::text AS ften_road_segment_id,
    og_road_segment_permit_id,
    NULL::int AS og_petrlm_dev_rd_pre06_pub_id,
    NULL::int AS railway_track_id,
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
    NULL::int AS transport_line_id,
    NULL::text AS ften_road_segment_id,
    NULL::int AS og_road_segment_permit_id,
    og_petrlm_dev_rd_pre06_pub_id,
    NULL::int AS railway_track_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_mineral_tenure.og_petrlm_dev_rds_pre06_pub_sp r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
  WHERE petrlm_development_road_type != 'WINT' -- exclude winter roads

  UNION ALL

  -- RAILWAY
  SELECT
    NULL::int AS transport_line_id,
    NULL::text AS ften_road_segment_id,
    NULL::int AS og_road_segment_permit_id,
    NULL::int og_petrlm_dev_rd_pre06_pub_id,
    railway_track_id,
    CASE
       WHEN ST_Within(r.geom, w.geom) THEN r.geom
       ELSE ST_Intersection(r.geom, w.geom)
    END as geom
  FROM whse_basemapping.gba_railway_tracks_sp r
  INNER JOIN wsg w
  ON ST_Intersects(r.geom, w.geom)
),

intersections AS
(
  SELECT
    r.transport_line_id,
    r.ften_road_segment_id,
    r.og_road_segment_permit_id,
    r.og_petrlm_dev_rd_pre06_pub_id,
    r.railway_track_id,
    s.linear_feature_id,
    s.blue_line_key,
    s.downstream_route_measure,
    s.length_metre,
    s.wscode_ltree,
    s.localcode_ltree,
    s.watershed_group_code,
    -- create intersections, dump any collections/mulitpart features to singlepart
    (ST_Dump(
      ST_Intersection(
        (ST_Dump(ST_Force2d(r.geom))).geom,
        (ST_Dump(ST_Force2d(s.geom))).geom
      )
    )).geom AS geom_x,
    s.geom AS geom_s
  FROM roads r
  INNER JOIN streams s
  ON ST_Intersects(r.geom, s.geom)
),

-- derive measure of point depending on geometry type
intersections_measures
AS
(
  SELECT
    i.*,
    CASE
      WHEN ST_Dimension(geom_x) = 0
      THEN ST_LineLocatePoint(
             ST_Linemerge(geom_s),
             geom_x
            ) * length_metre + downstream_route_measure
      -- streams and roads can overlap, resulting in a line intersection - handle this case
      -- by creating centorid
      WHEN ST_Dimension(geom_x) = 1
      THEN ST_LineLocatePoint(
             ST_Linemerge(geom_s),
             ST_Centroid(geom_x)
           ) * length_metre + downstream_route_measure
    END as downstream_route_measure_pt
  FROM intersections i
)

-- finally, generate the point from the measure.
INSERT INTO fish_passage.preliminary_stream_crossings
  (transport_line_id,
  ften_road_segment_id,
  og_road_segment_permit_id,
  og_petrlm_dev_rd_pre06_pub_id,
  railway_track_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  geom)
SELECT
  transport_line_id,
  ften_road_segment_id,
  og_road_segment_permit_id,
  og_petrlm_dev_rd_pre06_pub_id,
  railway_track_id,
  linear_feature_id,
  blue_line_key,
  downstream_route_measure_pt as downstream_route_measure,
  wscode_ltree,
  localcode_ltree,
  watershed_group_code,
  (ST_Dump(ST_LocateAlong(geom_s, downstream_route_measure_pt))).geom as geom
FROM intersections_measures;