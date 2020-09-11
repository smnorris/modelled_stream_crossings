# bcstreamcrossings

Generate potential locations of road/railway stream crossings and associated structures in British Columbia.

In addition to generating the intersection points of roads/railways and streams, this tool attempts to:

- remove duplicate crossings
- identify crossings that are likely to be bridges/open bottom structures
- maintain a consistent unique identifier value (`crossing_id`) for distinct crossing locations

## Data sources

### Transportation features

All road and railway features as defined by these queries are used to generate stream crossings - the queries attempt to extract only transportation features at which there is likely to be a stream crossing structure.

| Source         | Query |
| ------------- | ------------- |
| [Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads)  | `transport_line_type_code NOT IN ('F','FP','FR','T','TD','TR','TS','RP','RWA') AND transport_line_surface_code NOT IN ('D') AND transport_line_structure_code != 'T'` |
| [Forest Tenure Roads](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines)  | `life_cycle_status_code NOT IN ('RETIRED', 'PENDING')` |
| [OGC Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits)  | `status = 'Approved' AND road_type_desc != 'Snow Ice Road'` |
| [OGC Development Roads pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | `petrlm_development_road_type != 'WINT'` |
| [NRN Railway Tracks](https://catalogue.data.gov.bc.ca/dataset/railway-track-line)  | `structure_type != 'Tunnel'` (via spatial join to `gba_structure_lines`) |

### Stream features

Streams are from the [BC Freshwater Atlas](https://catalogue.data.gov.bc.ca/dataset/freshwater-atlas-stream-network)

## Requirements

- a FWA database created by [fwapg](https://github.com/smnorris/fwapg)
- PostgreSQL (requires >= v12)
- PostGIS (tested with >=v3.0.1)
- GDAL (tested with >= v2.4.4)
- Python (>=3.6)
- [bcdata](https://github.com/smnorris/bcdata)
- wget, unzip


## Installation

The repository is a collection of sql files and shell scripts - no installation is required.

To get the latest:

    git clone https://github.com/smnorris/bcstreamcrossings.git
    cd bcstreamcrossings


## Run the scripts

Scripts presume that environment variables `PGHOST, PGUSER, PGDATABASE, PGPORT, DATABASE_URL` are set to the appropriate db and that password authentication for the database is not required.

If required, download the data:

```
$ ./01_load.sh
```

Run the overlays and produce the outputs:
```
$ ./02_process.sh
```

## Outputs
