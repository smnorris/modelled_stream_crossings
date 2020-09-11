DROP TABLE IF EXISTS fish_passage.preliminary_stream_crossings;

CREATE TABLE fish_passage.preliminary_stream_crossings
(
  preliminary_crossing_id serial primary key,
  transport_line_id integer,
  ften_road_segment_id text,
  og_road_segment_permit_id integer,
  og_petrlm_dev_rd_pre06_pub_id integer,
  railway_track_id integer,
  linear_feature_id bigint,
  blue_line_key integer,
  downstream_route_measure double precision,
  wscode_ltree ltree,
  localcode_ltree ltree,
  edge_type integer,
  watershed_group_code character varying(4),
  geom geometry(PointZM, 3005)
);