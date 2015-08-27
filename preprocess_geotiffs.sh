# !/bin/bash

# This script preps a series of geotiff aerial imagery to be hosted by
# GeoServer by smoothing through resampling, reprojection, tiling and
# reducing file size

# resources:
# good stuff from paul ramsey on reducing the size of the tiffs without
# losing visible image quality:
# http://blog.cleverelephant.ca/2015/02/geotiff-compression-for-dummies.html
# http://gis.stackexchange.com/questions/120/make-the-nodata-area-of-a-resampled-orthophoto-overview-white

buildVrt() {
  # create a virtual mosaic of the geotiffs, this will be easier to work
  # with than many separate files and eliminates the need too repeatedly
  # execute some of the later tasks

  echo $'generating text file containing input geotiff paths...\n'

  mosaic_vrt="$1"
  geotiff_list="${vrt_dir}/geotiff_input_list.txt"

  # gdalbuildvrt can't handle a huge number of input files as direct input,
  # in these cases they must be submitted as text file which is being 
  # generated here
  find ${src_aerial_dir}/*.tif > $geotiff_list

  echo 'building mosaic vrt from source aerials...'

  # within the vrt utilize only the first three bands (r,g,b), the fourth 
  # band is infrared and is not needed, nodata in the source data is white
  # settings here make new nodata match that
  gdalbuildvrt \
    -b 1 -b 2 -b 3 \
    -hidenodata \
    -vrtnodata '255 255 255' \
    --config GDAL_MAXCACHE 1000 \
    -input_file_list $geotiff_list \
    $mosaic_vrt

  echo $'\n'
}

reprojectResampleImagery() {
  # reproject and resample the mosaiced vrt using the parameters indicated
  # below, bilinear has produced visually pleasing results for me in the past

  target_epsg="$1"
  warped_vrt="$2"
  resample_method='bilinear'

  # gdalwarp can't overwrite vrt's so delete the output tile if it exists
  rm -f $warped_vrt

  echo "reprojecting vrt to '${target_epsg}',"
  echo "resampling vrt using '${resample_method}' method..."

  # -wm and --config gdal_maxcache settings give gdal warp more memory and
  # thus speed up processing
  gdalwarp \
    -of 'VRT' \
    -t_srs "$target_epsg" \
    -r "$resample_method" \
    -wo 'SKIP_NOSOURCE=YES' \
    -wm '500' \
    --config GDAL_MAXCACHE 512 \
    $mosaic_vrt \
    $warped_vrt

  echo $'\n'
}

writeVrtToTiles() {
  # Write the mosaiced vrt to more manageable subset geotiffs (tiles), 

  mosaic_vrt="$1"
  tile_dir="$2"

  # make sure the target tile directory is empty
  mkdir -p $tile_dir
  rm -f ${tile_dir}/*.tif

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

  # the three config parameters below reduce the size of the overviews
  for geotiff in ${tile_dir}/*.tif; do 
    gdaladdo \
      -r gauss \
      --config COMPRESS_OVERVIEW JPEG \
      --config PHOTOMETRIC_OVERVIEW YCBCR \
      --config INTERLEAVE_OVERVIEW PIXEL \
      $geotiff \
      2 4 8 16 32 64 128 256
  done

  echo $'\n'
}

project_dir='G:/PUBLIC/GIS_Projects/Aerials'
script_dir="${project_dir}/git/aerials"
src_aerial_dir='E:/compressed4band/3in'

# create a directory to hold vrt's if it doesn't yet exist
vrt_dir="${project_dir}/vrt"
mkdir -p $vrt_dir
mosaic_vrt="${vrt_dir}/aerials_mosaic.vrt"
buildVrt $mosaic_vrt;

# # create tiles in oregon state plane north projection (2913)
# oregon_spn='EPSG:2913'
# ospn_vrt="${vrt_dir}/aerials_2913.vrt"
# ospn_dir="${project_dir}/oregon_spn_2014"
# reprojectResampleImagery $oregon_spn $ospn_vrt;
# writeVrtToTiles $ospn_vrt $ospn_dir;
# addOverviews $ospn_dir;

# create tiles in web mercator projection (3857)
web_mercator='EPSG:3857'
web_merc_vrt="${vrt_dir}/aerials_3857.vrt"
web_merc_dir="${project_dir}/web_merc_2014"
reprojectResampleImagery $web_mercator $web_merc_vrt;
time writeVrtToTiles $web_merc_vrt $web_merc_dir;
time addOverviews $web_merc_dir;