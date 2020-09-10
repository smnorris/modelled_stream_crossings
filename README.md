# bcstreamcrossings

Generate potential locations of transportation-stream crossings in British Columbia

In addition to running the simple intersection of roads/railways and stream linework, this tool:
- removes duplicate crossings as best as possible (road data comes from several sources)
- identifies crossings that are likely to be bridges/open bottom structures
- maintains consistent crossing id values when re-running the job with the latest road data


## Requirements

- a FWA database created by [fwapg](https://github.com/smnorris/fwapg)
- PostgreSQL (requires >= v12)
- PostGIS (tested with >=v3.0.1)
- GDAL (tested with >= v2.4.4)


## Installation

The repository is a collection of sql files and shell scripts - no installation is required.

To get the latest:

    git clone https://github.com/smnorris/bcstreamcrossings.git
    cd bcstreamcrossings


