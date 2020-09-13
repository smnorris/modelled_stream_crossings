-- classify crossings within 15m of an MOT bridge as OBS

WITH mot_bridges AS
(
  SELECT
    a.hwy_structure_class_id,
    nn.modelled_crossing_id
  FROM whse_imagery_and_base_maps.mot_road_structure_sp a
  CROSS JOIN LATERAL
    (SELECT
       modelled_crossing_id,
       ST_Distance(a.geom, b.geom) as dist
     FROM fish_passage.modelled_stream_crossings b
     ORDER BY a.geom <-> b.geom
     LIMIT 1) as nn
  WHERE UPPER(a.bmis_structure_type) = 'BRIDGE'
  AND nn.dist < 15
)

UPDATE fish_passage.modelled_stream_crossings x
SET modelled_crossing_type = 'OBS'
FROM mot_bridges y
WHERE x.modelled_crossing_id = y.modelled_crossing_id;

