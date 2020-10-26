#!/bin/bash
set -euxo pipefail

# create empty crossings table
psql -f sql/01_create_output_table.sql

# load preliminary crossings by source and watershed group
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/02_intersect_dra.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/03_intersect_ften.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/04_intersect_ogc.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/05_intersect_ogcpre06.sql -v wsg={1}

time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/06_intersect_railway.sql -v wsg={1}

psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (transport_line_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (ften_road_section_lines_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (og_road_segment_permit_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (og_petrlm_dev_rd_pre06_pub_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (railway_track_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (blue_line_key);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings (linear_feature_id);"
psql -c "CREATE INDEX ON fish_passage.modelled_stream_crossings USING GIST (geom);"

# backup for debugging the duplicate removal
#psql -c "create table temp.modelled_stream_crossings_bk AS SELECT * FROM fish_passage.modelled_stream_crossings;"

# remove duplicate crossings introduced by using multiple sources
psql -f sql/07_remove_duplicates.sql

# find and label open bottom structures/bridges
psql -f sql/08_identify_open_bottom_structures.sql

# report on results
mkdir -p reports
psql2csv < sql/report01_total.sql > reports/01_total.csv
psql2csv < sql/report02_source.sql > reports/02_source.csv
psql2csv < sql/report03_type_source_wsg.sql > reports/03_type_source_wsg.csv
psql2csv < sql/report04_obs_sources.sql > reports/04_obs_sources.csv