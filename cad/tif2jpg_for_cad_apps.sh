# !/bin/bash

# Grant Humphries for TriMet, 2014-15
# GDAL version: 1.11.2
# Python version: 2.7.8 (32-bit) 
# ---------------------------------

buildMosaicVrt() {
	# create a virtual mosaic of the geotiffs, this will be easier to work
	# with than many separate files and eliminates the need too repeatedly
	# execute some of the later tasks

	mosaic_vrt="$1"
	aerials_dir="$2"
	resolution="$3" # should be indicated in input raster units

	# resolution parameter is supplied set resolution options
	if [ -z $resolution ]
		then
			res_options=''
		else
			res_options="-tr $resolution $resolution -tap"
	fi

	echo 'building mosaic vrt from source aerials...'

	# nodata in the source data is white settings here make new nodata match
	gdalbuildvrt \
		$res_options \
		-hidenodata \
		-vrtnodata '255 255 255' \
		--config GDAL_MAXCACHE 1000 \
		$mosaic_vrt \
		${aerials_dir}/*.tif

	echo $'\n'
}

extractJpgTiles() {
	mosaic_vrt="$1"
	dst_jpg_dir="$2"
	tile_unit="$3"

	echo 'creating jpeg tiles from mosaic vrt...'

	extract_script="${code_dir}/cad/extract_jpg_tiles_from_vrt.py"
	python $extract_script $mosaic_vrt $dst_jpg_dir $tile_unit

	echo $'\n'
}

copyAerialShps() {
	# Add shapefiles that describe the geospatial position of the aerials
	# to the target directory structure
	src_shp_dir="$1"
	dst_shp_dir="$2"
	mkdir -p $dst_shp_dir

	echo 'copying over related aerial shapefiles...'

	sub_dirs=('flightlines' 'project_area' 'photo_centers')
	for sd in "${sub_dirs[@]}"; do
		shp_sub_dir="${src_shp_dir}/${sd}"
		
		for shp_file in $shp_sub_dir/*; do
			if [ -f "$shp_file" ]; then
				echo $shp_file

				basename=${shp_file##*/}
				cp $shp_file "${dst_shp_dir}/${basename}"
			fi
		done
	done

	echo $'\n'
} 

updateGrantPermissionsToProduction() {
	msg1='Are you sure you want to replace the existing production'
	msg2=$'aerials?  Press enter to continue, ctrl+c to quit:\n'
	read -p "${msg1} ${msg2}"

	# get the modification year from a random jpeg in the current dir
	# h/t to http://stackoverflow.com/questions/701505/best-way-to-choose-a-random-file-from-a-directory-in-a-shell-script
	old_jpgs=(${current_dir}/*/*.jpg)
	random_jpg="${old_jpgs[RANDOM % ${#old_jpgs[@]}]}"
	jpg_year="$(date +%Y -r $random_jpg)"

	# if the data in the current directory was modified in the current
	# year move it and replace it with the staging data	
	current_year="$(date +%Y)"
	if [ "$jpg_year" -lt "$current_year" ]; then
		last_year="$(expr $jpg_year - 1)"
		
		echo "mv $current_dir ${production_dir}/${last_year}_Summer_Jpg"
		mv $current_dir "${production_dir}/${last_year}_Summer_Jpg"
		
		echo "mv $staging_dir $current_dir"
		mv $staging_dir $current_dir

		# Grant read and execute permissions on the production folder 
		# to the user 'Everyone'.  The ':r' on the grant action replaces
		# any previous permissions, ':RX' is read, execute the '/t' flag
		# makes the action recurse to any children and '/q' flag 
		# suppresses success messages.  Within double forward slashes the
		# first slash escapes the second as this is a Windows command
		echo 'granting file permissions...'
		icacls ${current_dir} //grant:r Everyone:RX //t //q
	fi
}

project_dir='G:/PUBLIC/GIS_Projects/Aerials'
code_dir="${project_dir}/git/aerials"
ospn_tiles="${project_dir}/oregon_spn_2014"
production_dir='G:/AERIALS'
staging_dir="${production_dir}/tempCurrent"
current_dir="${production_dir}/Current"

# generate 6" jpeg's
resolution='0.5' # feet
six_inch_vrt="${project_dir}/vrt/six_inch_for_jpg.vrt"
buildMosaicVrt $six_inch_vrt $ospn_tiles $resolution;

sections='SECTION'
time extractJpgTiles $six_inch_vrt $staging_dir $sections;

# generate 3" jpeg's
three_inch_vrt="${project_dir}/vrt/three_inch_for_jpg.vrt"
buildMosaicVrt $three_inch_vrt $ospn_tiles;

qtr_sections='QTRSEC'
time extractJpgTiles $three_inch_vrt $staging_dir $qtr_sections;

# finish up by transfering shapefiles, granting file permissions
# and moving the new files into place
src_shp_dir='E:/admin'
dst_shp_dir="${staging_dir}/shp"
copyAerialShps $src_shp_dir $dst_shp_dir;

updateGrantPermissionsToProduction;