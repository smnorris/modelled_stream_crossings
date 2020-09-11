WITH wsg AS
(SELECT watershed_group_code, geom
  FROM whse_basemapping.fwa_watershed_groups_poly
  WHERE watershed_group_code = :wsg),

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
 WHERE transport_line_type_code NOT IN ('F','FP','FR','T','TD','TR','TS','RP','RWA')

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
 WHERE life_cycle_status_code not in ('RETIRED', 'PENDING')

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
 WHERE status = 'Approved' AND road_type_desc != 'Snow Ice Road'

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
 WHERE petrlm_development_road_type != 'WINT'

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
 )

-- intersect with streams
SELECT
  r.transport_line_id,
  r.ften_road_segment_id,
  r.og_road_segment_permit_id,
  r.og_petrlm_dev_rd_pre06_pub_id,
  r.railway_track_id,
  -- there can be linear outputs where roads and streams line up
  -- use st_centorid to ensure only points are returned
  ST_Centroid(
    (ST_Dump(
      ST_Intersection(
        (ST_Dump(ST_Force2d(r.geom))).geom,
        (ST_Dump(ST_Force2d(s.geom))).geom
      )
    )).geom
  )   as geom
FROM roads r
INNER JOIN whse_basemapping.fwa_stream_networks_sp s
ON ST_Intersects(r.geom, s.geom)
WHERE s.fwa_watershed_code NOT LIKE '999%' -- do not include streams that are not part of the network
AND s.edge_type NOT IN (1410, 1425)        -- do not include subsurface flow
AND s.watershed_group_code = :wsg ;