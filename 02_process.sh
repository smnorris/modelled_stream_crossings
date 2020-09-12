#!/bin/bash
set -euxo pipefail

# create empty crossings table
psql -f sql/01_create_output_table.sql

# load preliminary crossings by source and watershed group
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly WHERE watershed_group_code IN ('VICT','COWN','SANJ')" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/02_intersect_dra.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly WHERE watershed_group_code IN ('VICT','COWN','SANJ')" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/03_intersect_ften.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly WHERE watershed_group_code IN ('VICT','COWN','SANJ')" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/04_intersect_ogc.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly WHERE watershed_group_code IN ('VICT','COWN','SANJ')" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/05_intersect_railway.sql -v wsg={1}


# create indexes
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (transport_line_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (ften_road_segment_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (og_road_segment_permit_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (og_petrlm_dev_rd_pre06_pub_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (railway_track_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (blue_line_key);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings (linear_feature_id);"
psql -c "CREATE INDEX ON fish_passage.preliminary_stream_crossings USING GIST (geom);"
