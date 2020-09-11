-- label open bottom / closed bottom structures as best as possible

-- add structure type column
ALTER TABLE fish_passage.preliminary_stream_crossings
ADD COLUMN IF NOT EXISTS modelled_crossing_type character varying (3);

-- double line rivers/waterbodies
UPDATE fish_passage.preliminary_stream_crossings
SET modelled_crossing_type = 'OBS'
WHERE edge_type IN (1200, 1250, 1300, 1350, 1400, 1450, 1475);

-- DRA structure types
UPDATE fish_passage.preliminary_stream_crossings
SET modelled_crossing_type = 'OBS'
WHERE transport_line_id IN
(SELECT
  x.transport_line_id
FROM fish_passage.preliminary_stream_crossings x
INNER JOIN whse_basemapping.transport_line r
ON x.transport_line_id = r.transport_line_id
WHERE r.transport_line_structure_code IN ('B','C','E','F','O','R','V'));

-- railway structure types
UPDATE fish_passage.preliminary_stream_crossings
SET modelled_crossing_type = 'OBS'
WHERE preliminary_crossing_id IN
(
  SELECT
    p.preliminary_crossing_id
  FROM fish_passage.preliminary_stream_crossings p
  INNER JOIN whse_basemapping.gba_railway_structure_lines_sp r
  ON ST_Intersects(ST_Buffer(p.geom, 5), r.geom)
  WHERE UPPER(r.structure_type) LIKE 'BRIDGE%'
);

--
-- add other bridge sources here
--

-- default to cbs
UPDATE fish_passage.preliminary_stream_crossings
SET modelled_crossing_type = 'CBS'
WHERE modelled_crossing_type IS NULL;