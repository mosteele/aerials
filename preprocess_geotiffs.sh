# !/bin/bash

# This script preps a series of geotiff aerial imagery to be hosted by
# GeoServer by smoothing through resampling, reprojection, tiling and
# reducing file size

# resources:
# good stuff from paul ramsey on reducing the size of the tiffs without
# losing visible image quality:
# http://blog.cleverelephant.ca/2015/02/geotiff-compression-for-dummies.html

buildVrt() {
  # create a virtual mosaic of the geotiffs, and only utilize the first
  # three bands (r,g,b), the fourth band is infrared and is not needed

  mosaic_vrt="$1"

  echo 'building vrt from source aerials...'

  gdalbuildvrt \
    -b 1 -b 2 -b 3 \
    $mosaic_vrt \
    ${src_aerial_dir}/*.tif

  echo $'\n'
}

reprojectResampleImagery() {
  # reproject and resample the mosaiced vrt using the parameters indicated
  # below, bilinear has produced visually pleasing results for me in the past

  target_epsg="$1"
  warped_vrt="$2"
  resample_method='bilinear'

  echo "reprojecting vrt to '${target_epsg}',"
  echo "resampling vrt using '${resample_method}' method..."

  gdalwarp \
    -of 'VRT' \
    -t_srs "$target_epsg" \
    -r "$resample_method" \
    $mosaic_vrt \
    $warped_vrt

  echo $'\n'
}

writeVrtToTiles() {
  # Write the mosaiced vrt to more manageable subset geotiffs (tiles), 

  mosaic_vrt="$1"
  tile_dir="$2"

  # make sure gdal_retile has an empty directory to write to
  rm -rf $tile_dir
  mkdir $tile_dir

  echo 'creating geotiff tiles from mosaic vrt...'

  py_gdal_translate="${script_dir}/mosaic2tiles_w_gdal_translate.py"
  python $py_gdal_translate $mosaic_vrt $tile_dir

  echo $'\n'
}

addOverviews() {
  # Overviews are lower resolution versions of the original image that are
  # stored within the source file, applications can retrive these overviews
  # at lower zoom levels in lieu of the original for faster loading times

  tile_dir="$1"

  echo "adding overviews to geotiffs in the following directory: $tile_dir"

  # config parameters below reduce the size of the overviews
  for geotiff in ${tile_dir}/*.tif; do 
    gdaladdo \
      -r gauss \
      --config COMPRESS_OVERVIEW JPEG \
      --config PHOTOMETRIC_OVERVIEW YCBCR \
      --config INTERLEAVE_OVERVIEW PIXEL \
      $geotiff \
      2 4 8 16 32 64 128
  done

  echo $'\n'
}

project_dir='G:/PUBLIC/GIS_Projects/Aerials'
script_dir="${project_dir}/git/aerials"
src_aerial_dir='E:/compressed4band/3in'
# src_aerial_dir='C:/Users/humphrig/Desktop/aerials_test'

# delete a vrt directory if it exists, then recreate, this is in place
# because some gdal tools can't overwrite existing vrt's
vrt_dir="${project_dir}/web_merc_2014/vrt"
rm -rf $vrt_dir
mkdir $vrt_dir

mosaic_vrt="${vrt_dir}/aerials_mosaic.vrt"
buildVrt $mosaic_vrt;

# # create tiles in oregon state plane north projection (2913)
# oregon_spn='EPSG:2913'
# ospn_vrt="${vrt_dir}/aerials_2913.vrt"
# ospn_dir="${src_aerial_dir}/oregon_spn"
# reprojectResampleImagery $oregon_spn $ospn_vrt;
# writeVrtToTiles $ospn_vrt $ospn_dir;
# addOverviews $ospn_dir;

# create tiles in web mercator projection (3857)
# web_mercator='EPSG:3857'
# web_merc_vrt="${vrt_dir}/aerials_3857.vrt"
# web_merc_dir="${project_dir}/web_merc_2014"
# reprojectResampleImagery $web_mercator $web_merc_vrt;
# writeVrtToTiles $web_merc_vrt $web_merc_dir;
# addOverviews $web_merc_dir;