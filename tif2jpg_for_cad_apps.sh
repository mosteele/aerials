# Grant Humphries for TriMet, 2014
# GDAL version: 1.11.2
# Python version: 2.7.8 (32-bit) 
# ---------------------------------

convertTif2Jpg() {
	src_tiff_dir="$1"
	dst_tiff_dir="$2"

	# For each .tif take the file name and truncate it down to its first 
	# four letters.  Then create a new folder with that name in the output
	# directory when unique.  Within these tiff files the first four letters
	# identify the township that they belong to
	for tif_file in "$src_tiff_dir/*.tif"; do
		township_dir="${dst_tiff_dir}/${tif_file:0:4}"
		mkdir -p $township_dir

		# Convert each aerial into the Oregon State Plane North Projection
		# and put the output into the newly created sub-folder.  The 
		# 'TILED=YES' internally tiles the image so it can read in chunks 
		# and 'COMPRESS=JPEG' reduces the file size 
		vrt_file=${tif_file/.tif/.vrt}

		gdalwarp \
			-of 'VRT' \
			-t_srs 'EPSG:2913' \
			${src_tiff_dir}/${tif_file} \
			${vrt_dir}/${vrt_file}

		# Convert the reprojected imagery into .jpg format.  The first command 
		# below replaces the .tif at the end of the file name with .jpg in a
		# new variable.  'WORLDFILE=YES' create a files that has the image's
		# spatial reference information
		jpeg_file=${tif_file/.tif/.jpg}
		
		gdal_translate \
			-of 'JPEG' \
			-co 'TILED=YES' \
			-co 'COMPRESS=JPEG' \
			-co 'WORLDFILE=YES' \
			${vrt_dir}/${vrt_file} \
			${township_dir}/${jpeg_file}
	done
}

copyAerialShps() {
	# Add shapefiles that describe the geospatial position of the aerials
	# to the target directory structure
	src_shp_dir="$1"
	dst_shp_dir="$2/shapefiles"
	sub_dirs=('flightlines' 'project_area' 'photo_centers')

	mkdir -p $dst_shp_dir

	for sd in "${sub_dirs[@]}"; do
		shp_sub_dir="${src_shp_dir}/${sd}"
		for shp_file in "${shp_sub_dir}/*"; do
			cp "${shp_sub_dir}/${shp_file}" "${dst_shp_dir}/${shp_file}"
		done
	done
} 

updateProductionCurrentFiles() {
	
}

src_aerials_dir='E:'
src_aerials_shp_dir="${src_aerials_dir}/admin"
src_aerials_tif_dir="${src_aerials_dir}/compressed4band/3in"

dst_aerials_dir='G:/AERIALS'
dst_staging_dir="${dst_aerials_dir}/tempCurrent"
production_dir="${dst_aerials_dir}/Current"
mkdir -p $tmp_dst_aerials_tif_dir

vrt_dir='C:/Users/humphrig/Desktop/temp'
mkdir -p $vrt_dir

convertTif2Jpg $src_aerials_tif_dir $dst_staging_dir;
copyAerialShps $src_aerials_shp_dir $dst_staging_dir


# ******Once this script has run be sure to set the permission on the 
# 'New_Current' folder to 'Everyone'******

# *******don't forget to time the script******

::Ran in ~22 hours on 4/1/14