# AI Coding Agent Instructions for Precipitation Tiles Pipeline

## Project Overview
This is a geospatial data processing pipeline that converts GFS (Global Forecast System) precipitation rate (PRATE) data into web-friendly tile formats. The pipeline transforms GRIB2 weather data through GeoTIFF and finally into TerrainRGB-encoded PMTiles for efficient web mapping.

## Data Flow Architecture
```
GRIB2 → GeoTIFF → Web Mercator → TerrainRGB → Raster Tiles → MBTiles → PMTiles
  ↓         ↓           ↓            ↓            ↓           ↓         ↓
grib2/    tif/    tif_3857/  tif_3857_terrainrgb/  (temp)  (temp)  terrainrgb/
```

**Critical Understanding**: This is a 3-stage pipeline where each stage depends on the previous one's output:
1. `01_fetch_prate.sh` - Downloads and extracts PRATE data from NOAA GFS
2. `02_create_geotiff.sh` - Converts GRIB2 to GeoTIFF with unit conversion (kg/m²/s → mm/h)
3. `03_create_prate_terrainRGB.sh` - Creates web tiles via projection, TerrainRGB encoding, and PMTiles conversion

## Key Technical Patterns

### Docker-Heavy Workflow
All geospatial processing uses Docker containers to avoid dependency management:
- `28mm/wgrib2` - GRIB2 data extraction
- `ghcr.io/osgeo/gdal:alpine-normal-latest` - Geospatial transformations
- `helmi03/rio-rgbify` - TerrainRGB encoding

Always maintain the user/group mapping pattern: `-u "$(id -u)":"$(id -g)"` and volume mounting: `-v "$PWD":/work -w /work`

### Time-Based Data Organization
Files follow strict naming: `prate_YYYYMMDD_HHH.{extension}` where HHH is forecast hour (000-384).
The pipeline processes time ranges, not individual files - always consider START_HOUR to END_HOUR ranges.

### Japanese Error Messages
All user-facing messages and error handling are in Japanese. When modifying scripts, maintain this convention:
- `エラー:` for errors
- `完了` for completion
- Parameter validation messages in Japanese

### Coordinate System Transformations
- Input: EPSG:4326 (WGS84) from GRIB2
- Processing: EPSG:3857 (Web Mercator) for web compatibility
- Bounds: Hardcoded to `-180 -85.051129 180 85.051129` (Web Mercator limits)

### TerrainRGB Encoding Parameters
Precipitation rates are encoded with specific parameters in `rio-rgbify`:
- Base value: `-10000` (handles negative/zero values)
- Interval: `0.1` (0.1mm/h precision)
- This encoding allows 24-bit precipitation storage in RGB channels

## Development Workflows

### Running the Pipeline
```bash
# Full pipeline for today's data
./run_pipeline.sh

# Specific date and time range
./run_pipeline.sh 20251101 0 12

# Individual stages only
./run_pipeline.sh 20251101 0 12 fetch
./run_pipeline.sh 20251101 0 12 geotiff  # Requires existing GRIB2 data
./run_pipeline.sh 20251101 0 12 terrainrgb  # Requires existing GeoTIFF data
```

### Data Validation
- GRIB2 files should contain PRATE data with pattern "PRATE:surface:X hour fcst:"
- GeoTIFF values are multiplied by 3600 to convert kg/m²/s to mm/h
- Final PMTiles should be significantly smaller than intermediate MBTiles

### Common Issues
1. **Missing Docker images** - Scripts will fail silently if Docker images aren't pulled
2. **Forecast hour mismatch** - GRIB2 extraction uses forecast hour, not file hour suffix
3. **File permissions** - Docker user mapping is critical for file ownership
4. **Disk space** - Intermediate files can be large; cleanup happens automatically in stage 3

## File Organization
- `/grib2/` - Raw GRIB2 files (gitignored, ~50MB each)
- `/tif/` - GeoTIFF files (gitignored, ~200MB each)  
- `/tif_3857/` - Reprojected TIFFs (gitignored)
- `/tif_3857_terrainrgb/` - TerrainRGB TIFFs (gitignored)
- `/terrainrgb/` - Final PMTiles output (gitignored, ~5MB each)

Only shell scripts and this instruction file are version controlled. All data outputs are gitignored due to size.

## External Dependencies
- NOAA GFS data from AWS S3: `s3://noaa-gfs-bdp-pds/gfs.YYYYMMDD/00/atmos/`
- Node.js tools: `mb-util`, `pmtiles` (assumed to be installed globally)
- Docker with internet access for pulling geospatial processing images

When modifying scripts, test against existing GRIB2 files before processing new forecast hours to avoid unnecessary data downloads during development.