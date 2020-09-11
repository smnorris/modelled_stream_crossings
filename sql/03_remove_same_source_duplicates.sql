-- for duplicates same-source roads, simply find duplicates within noted threshold and delete
-- the crossing with the lower id (random)

-- DRA
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
SELECT
  nn.preliminary_crossing_id
FROM fish_passage.preliminary_stream_crossings t1
CROSS JOIN LATERAL
  (SELECT
   preliminary_crossing_id,
   ST_Distance(t1.geom, t2.geom) as dist
   FROM fish_passage.preliminary_stream_crossings t2
   WHERE t2.transport_line_id IS NOT NULL
   ORDER BY t1.geom <-> t2.geom
   LIMIT 10) as nn
WHERE t1.transport_line_id IS NOT NULL
AND nn.dist < 10
AND t1.preliminary_crossing_id < nn.preliminary_crossing_id
);

-- FTEN
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
SELECT
  nn.preliminary_crossing_id
FROM fish_passage.preliminary_stream_crossings t1
CROSS JOIN LATERAL
  (SELECT
   preliminary_crossing_id,
   ST_Distance(t1.geom, t2.geom) as dist
   FROM fish_passage.preliminary_stream_crossings t2
   WHERE t2.ften_road_segment_id IS NOT NULL
   ORDER BY t1.geom <-> t2.geom
   LIMIT 10) as nn
WHERE t1.ften_road_segment_id IS NOT NULL
AND nn.dist < 10
AND t1.preliminary_crossing_id < nn.preliminary_crossing_id
);

-- OGC
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
SELECT
  nn.preliminary_crossing_id
FROM fish_passage.preliminary_stream_crossings t1
CROSS JOIN LATERAL
  (SELECT
   preliminary_crossing_id,
   ST_Distance(t1.geom, t2.geom) as dist
   FROM fish_passage.preliminary_stream_crossings t2
   WHERE t2.og_road_segment_permit_id IS NOT NULL
   ORDER BY t1.geom <-> t2.geom
   LIMIT 10) as nn
WHERE t1.og_road_segment_permit_id IS NOT NULL
AND nn.dist < 10
AND t1.preliminary_crossing_id < nn.preliminary_crossing_id
);

-- OGC pre06
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
SELECT
  nn.preliminary_crossing_id
FROM fish_passage.preliminary_stream_crossings t1
CROSS JOIN LATERAL
  (SELECT
   preliminary_crossing_id,
   ST_Distance(t1.geom, t2.geom) as dist
   FROM fish_passage.preliminary_stream_crossings t2
   WHERE t2.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL
   ORDER BY t1.geom <-> t2.geom
   LIMIT 10) as nn
WHERE t1.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL
AND nn.dist < 10
AND t1.preliminary_crossing_id < nn.preliminary_crossing_id
);

-- railway
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
SELECT
  nn.preliminary_crossing_id
FROM fish_passage.preliminary_stream_crossings t1
CROSS JOIN LATERAL
  (SELECT
   preliminary_crossing_id,
   ST_Distance(t1.geom, t2.geom) as dist
   FROM fish_passage.preliminary_stream_crossings t2
   WHERE t2.railway_track_id IS NOT NULL
   ORDER BY t1.geom <-> t2.geom
   LIMIT 10) as nn
WHERE t1.railway_track_id IS NOT NULL
AND nn.dist < 10
AND t1.preliminary_crossing_id < nn.preliminary_crossing_id
);

-- also, remove railway tunnels
DELETE FROM fish_passage.preliminary_stream_crossings
WHERE preliminary_crossing_id IN
(
  SELECT
    p.preliminary_crossing_id
  FROM fish_passage.preliminary_stream_crossings p
  INNER JOIN whse_basemapping.gba_railway_structure_lines_sp r
  ON ST_Intersects(ST_Buffer(p.geom, 5), r.geom)
  WHERE r.structure_type = 'Tunnel'
);