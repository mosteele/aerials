# !/bin/bash

src_aerial_dir='C:/Users/humphrig/Desktop/aerials_test'
vrt_dir="$src_aerial_dir/vrt"
rm -rf $vrt_dir
mkdir $vrt_dir

src_vrt="$src_aerial_dir/vrt/source_aerials.vrt"
resampled_vrt="$src_aerial_dir/vrt/resampled_aerials.vrt"

buildVrt() {
  echo 'building vrt from source aerials...'

  gdalbuildvrt \
    $src_vrt \
    $src_aerial_dir/*.tif

  echo $'\n'
}

resampleImagery() {
  echo 'resampling vrt using bilinear interpolation...'

  gdalwarp \
    -of 'VRT' \
    -r bilinear \
    $src_vrt \
    $resampled_vrt

  echo $'\n'
}

reprojectImagery() {
  target_epsg="$1"
  reprojected_vrt="$2"

  echo "reprojecting vrt to '${target_epsg}'..."

  gdalwarp \
    -of 'VRT' \
    -t_srs "$target_epsg" \
    $resampled_vrt \
    $reprojected_vrt

  echo $'\n'
}

writeVrtToTiles() {
  in_file="$1"
  out_dir="$2"

  gdal_retile.py \
    -co 'COMPRESS=JPEG' \
    -co 'TILED=YES' \
    -p
    $ospn_vrt \
    $src_aerial_dir/output/script_workflow.tif
}

addOverviews() {
  geotiff_dir="$1"

  for geotiff in $geotiff_dir/*.tif
  do 
    gdaladdo \
      -r gauss
      --config 'COMPRESS_OVERVIEW JPEG' \
      --config 'PHOTOMETRIC_OVERVIEW YCBCR' \
      --config 'INTERLEAVE_OVERVIEW PIXEL' \
      $geotiff
      2 4 8 16 32 64 128 256 512
  done
}

buildVrt;
resampleImagery;

oregon_spn='EPSG:2913'
ospn_vrt="$src_aerial_dir/vrt/aerials_2913.vrt"
ospn_dir="$src_aerial_dir/oregon_spn"
reprojectImagery $oregon_spn $ospn_vrt;
writeVrtToTiles $ospn_vrt $ospn_dir;
# addOverviews $ospn_dir;

# web_mercator='EPSG:3857'
# web_merc_vrt='aerials_3857.vrt'
# web_merc_dir="$src_aerial_dir/web_mercator"
# reprojectImagery $web_mercator $web_merc_vrt;
# writeVrtToTiles $web_merc_vrt $web_merc_dir;
# addOverviews $web_merc_dir;

# # these are commands being used previously:
# gdalwarp \ 
#   -r bilinear \
#   -t_srs "EPSG:2913" \
#   -co "TILED=YES" \
#   -co "COMPRESS=JPEG" \
#   $in_file \
#   $out_file

# wait

# gdaladdo \
#   -r gauss \
#   $out_file \
#   2 4 8 16 32 64 128 256 512

# wait
    # -co 'PHOTOMETRIC=YCBCR' \