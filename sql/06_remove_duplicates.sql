-- data sources in order of priority (spatially)
-- (we don't consider railways, happily there is just one source)
-- 1. DRA
-- 2. FTEN
-- 3. OGC permits
-- 4. OGC pre-06


-- But, FTEN data can be the most useful for resource road fish passage work,
-- so we want to retain these as best as possible.

-- For each DRA crossing, find the closest FTEN crossing (within 20m)
WITH matched_ften_xings AS
(
    SELECT
      t1.preliminary_crossing_id as id,
      t1.transport_line_id,
      nn.preliminary_crossing_id,
      nn.ften_road_segment_id
    FROM fish_passage.preliminary_stream_crossings t1
    CROSS JOIN LATERAL
      (SELECT
       preliminary_crossing_id,
       ften_road_segment_id,
       ST_Distance(t1.geom, t2.geom) as dist
       FROM fish_passage.preliminary_stream_crossings t2
       WHERE t2.ften_road_segment_id IS NOT NULL
       ORDER BY t1.geom <-> t2.geom
       LIMIT 1) as nn
    WHERE t1.transport_line_id IS NOT NULL
    AND nn.dist < 20
    ORDER BY t1.preliminary_crossing_id
)

-- If there is a match, give the DRA crossing the ften_road_segment_id value from the match
-- (the select and update takes about 4min on my db)
UPDATE fish_passage.preliminary_stream_crossings x
SET ften_road_segment_id = y.ften_road_segment_id
FROM matched_ften_xings y
WHERE x.preliminary_crossing_id = y.id;


-- with the FTEN id now stored in the DRA based crossing, we can delete the FTEN crossings
DELETE

-- next, go ahead and delete OGC road crossings within 20m of DRA crossings

