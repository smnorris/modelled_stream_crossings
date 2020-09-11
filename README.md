# bcstreamcrossings

Generate potential locations of road/railway stream crossings and associated structures in British Columbia.

In addition to generating the intersection points of roads/railways and streams, this tool:

- removes duplicate crossings as best as possible
- identifies crossings that are likely to be bridges/open bottom structures
- maintains a consistent unique identifier value for each output crossing

## Data sources

### Transportation features

All road and railway features as defined by these queries are used to generate stream crossings - the queries attempt to extract only transportation features at which there is likely to be a stream crossing structure.

| Source         | Query |
| ------------- | ------------- |
| [Digital Road Atlas (DRA)](https://catalogue.data.gov.bc.ca/dataset/digital-road-atlas-dra-master-partially-attributed-roads)  | `road_class NOT IN ('trail', 'ferry', 'proposed', 'water')` |
| [Forest Tenure Roads](https://catalogue.data.gov.bc.ca/dataset/forest-tenure-road-section-lines)  | `life_cycle_status_code not in ('RETIRED', 'PENDING')` |
| [OGC Road Segment Permits](https://catalogue.data.gov.bc.ca/dataset/oil-and-gas-commission-road-segment-permits)  | `status = 'Approved' AND road_type_desc != 'Snow Ice Road'` |
| [OGC Development Roads pre-2006](https://catalogue.data.gov.bc.ca/dataset/ogc-petroleum-development-roads-pre-2006-public-version) | `petrlm_development_road_type != 'WINT'` |
| [NRN Railway Tracks](https://catalogue.data.gov.bc.ca/dataset/railway-track-line)  |  |

### Stream features

Streams are from the [BC Freshwater Atlas stream network](https://github.com/smnorris/fwapg)

## Requirements

- a FWA database created by [fwapg](https://github.com/smnorris/fwapg)
- PostgreSQL (requires >= v12)
- PostGIS (tested with >=v3.0.1)
- GDAL (tested with >= v2.4.4)
- Python (>=3.6)
- [bcdata](https://github.com/smnorris/bcdata)


## Installation

The repository is a collection of sql files and shell scripts - no installation is required.

To get the latest:

    git clone https://github.com/smnorris/bcstreamcrossings.git
    cd bcstreamcrossings


