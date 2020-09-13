with by_source AS
(
SELECT
  watershed_group_code,
  CASE
    WHEN transport_line_id IS NOT NULL THEN 'DRA'
    WHEN transport_line_id IS NULL AND ften_road_segment_id IS NOT NULL THEN 'FTEN'
    WHEN transport_line_id IS NULL AND ften_road_segment_id IS NULL AND og_road_segment_permit_id IS NOT NULL THEN 'OGC'
    WHEN transport_line_id IS NULL AND ften_road_segment_id IS NULL AND og_road_segment_permit_id IS NULL AND og_petrlm_dev_rd_pre06_pub_id IS NOT NULL THEN 'OGC'
    WHEN railway_track_id IS NOT NULL THEN 'RAILWAY'
  END as source,
  modelled_crossing_type,
  array_to_string(modelled_crossing_type_source, ';') as bridge_source
FROM fish_passage.modelled_stream_crossings
)

SELECT
  watershed_group_code,
  modelled_crossing_type,
  source,
  bridge_source,
  count(*) as n
FROM by_source
GROUP BY watershed_group_code, modelled_crossing_type, source, bridge_source
ORDER BY watershed_group_code, modelled_crossing_type, source, bridge_source