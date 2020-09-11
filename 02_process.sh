#!/bin/bash
set -euxo pipefail

# create empty crossings table
psql -f sql/01_create_preliminary_crossings.sql

# load preliminary crossings by watershed group (~6min)
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/02_intersect.sql -v wsg={1}

# create indexes
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (transport_line_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (ften_road_segment_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (og_road_segment_permit_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (og_petrlm_dev_rd_pre06_pub_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (railway_track_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (blue_line_key);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (linear_feature_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings USING GIST (geom);"
