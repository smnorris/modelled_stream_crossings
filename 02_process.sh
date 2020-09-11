#!/bin/bash
set -euxo pipefail

# create empty crossings table
psql -f sql/01_create_preliminary_crossings.sql

# load preliminary crossings by watershed group
time psql -t -P border=0,footer=no \
-c "SELECT ''''||watershed_group_code||'''' FROM whse_basemapping.fwa_watershed_groups_poly" \
    | sed -e '$d' \
    | parallel --colsep ' ' psql -f sql/02_intersect.sql -v wsg={1}