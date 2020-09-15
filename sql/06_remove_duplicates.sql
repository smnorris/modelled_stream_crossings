-- Remove crossing duplication from multiple data sources.

-- When removing duplicates, we consider sources in this order
-- of presumed spatial accuracy (FTEN and OGC are tenures, not as-built)
-- 1. DRA
-- 2. FTEN
-- 3. OGC permits
-- 4. OGC pre-06
-- (we don't consider railways, happily there is just one source)

-- As FTEN data can be the most useful for resource road fish passage work
-- we want to retain FTEN attributes as best as possible - transfer the FTEN ids
-- to the DRA based points via a nearest neighbour spatial join.

-- -----------------------------------------------------------
-- For FTEN crossings within 20m of a DRA point, assign the closest DRA point the FTEN id
-- -----------------------------------------------------------
WITH matched_ften_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ften,
      t1.ften_road_segment_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.ften_road_segment_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
UPDATE fish_passage.modelled_stream_crossings x
SET ften_road_segment_id = y.ften_road_segment_id
FROM matched_ften_xings y
WHERE x.modelled_crossing_id = y.modelled_crossing_id_keep;

-- repeat the matching to delete duplicate ften crossings
WITH matched_ften_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ften,
      t1.ften_road_segment_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.ften_road_segment_id IS NOT NULL AND t1.transport_line_id IS NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
DELETE FROM  fish_passage.modelled_stream_crossings x
WHERE modelled_crossing_id IN (SELECT modelled_crossing_id_ften FROM matched_ften_xings);


-- -----------------------------------------------------------
-- Find OGC permit crossings within 20m of DRA/FTEN crossings
-- -----------------------------------------------------------
WITH matched_ogc_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ogc,
      t1.og_road_segment_permit_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id,
      nn.ften_road_segment_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ften_road_segment_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       OR t2.ften_road_segment_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.og_road_segment_permit_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
UPDATE fish_passage.modelled_stream_crossings x
SET og_road_segment_permit_id = y.og_road_segment_permit_id
FROM matched_ogc_xings y
WHERE x.modelled_crossing_id = y.modelled_crossing_id_keep;


WITH matched_ogc_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ogc,
      t1.og_road_segment_permit_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id,
      nn.ften_road_segment_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ften_road_segment_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       OR t2.ften_road_segment_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.og_road_segment_permit_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
DELETE FROM fish_passage.modelled_stream_crossings
WHERE modelled_crossing_id IN
(SELECT modelled_crossing_id_ogc FROM matched_ogc_xings);

-- -----------------------------------------------------------
-- Find OGC pre06 crossings within 20m of DRA/FTEN/OGC crossings
-- -----------------------------------------------------------
WITH matched_ogcpre06_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ogc,
      t1.og_petrlm_dev_rd_pre06_pub_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id,
      nn.ften_road_segment_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ften_road_segment_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       OR t2.ften_road_segment_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
UPDATE fish_passage.modelled_stream_crossings x
SET og_petrlm_dev_rd_pre06_pub_id = y.og_petrlm_dev_rd_pre06_pub_id
FROM matched_ogcpre06_xings y
WHERE x.modelled_crossing_id = y.modelled_crossing_id_keep;

WITH matched_ogcpre06_xings AS
(
   SELECT
      t1.modelled_crossing_id as modelled_crossing_id_ogc,
      t1.og_petrlm_dev_rd_pre06_pub_id,
      nn.modelled_crossing_id as modelled_crossing_id_keep,
      nn.transport_line_id,
      nn.ften_road_segment_id
    FROM fish_passage.modelled_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
         modelled_crossing_id,
         transport_line_id,
         ften_road_segment_id,
         ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.modelled_stream_crossings t2
       WHERE t2.transport_line_id IS NOT NULL
       OR t2.ften_road_segment_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.og_petrlm_dev_rd_pre06_pub_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.modelled_crossing_id
)
DELETE FROM fish_passage.modelled_stream_crossings
WHERE modelled_crossing_id IN
(SELECT modelled_crossing_id_ogc FROM matched_ogcpre06_xings);