# !/bin/bash
# one file from the aerial geotiffs came in a different projection than
# all the others, this script takes that file and makes an outut that
# is congruent to all of the others

in_file='E:/compressed4band/3in/1s1w01d.tif'
out_file='E:/compressed4band/temp/1s1w01d.tif'

# if there is an epsg code for the new version of the oregon state plane
# north projection I don't know it, so the full well-known-text (wkt)
# string must be used which appears below
new_ospn='PROJCS["NAD_1983_2011_Oregon_Statewide_Lambert_Ft_Intl",
    GEOGCS["GCS_NAD_1983_2011",
        DATUM["NAD_1983_2011",
            SPHEROID["GRS_1980",6378137,298.257222101]],
        PRIMEM["Greenwich",0],
        UNIT["degree",0.0174532925199433]],
    PROJECTION["Lambert_Conformal_Conic_2SP"],
    PARAMETER["standard_parallel_1",43],
    PARAMETER["standard_parallel_2",45.5],
    PARAMETER["latitude_of_origin",41.75],
    PARAMETER["central_meridian",-120.5],
    PARAMETER["false_easting",1312335.958005249],
    PARAMETER["false_northing",0],
    UNIT["foot",0.3048, 
        AUTHORITY["EPSG","9002"]]]'

echo "gdalwarp \
	-co 'COMPRESS=JPEG' \
	-co 'TFW=YES' \
	-t_srs $new_ospn \
	$in_file \
	$out_file"

gdalwarp \
	-co 'COMPRESS=JPEG' \
	-co 'TFW=YES' \
	-t_srs "$new_ospn" \
	$in_file \
	$out_file

echo "gdaladdo \
	--config COMPRESS_OVERVIEW JPEG \
	--config INTERLEAVE_OVERVIEW PIXEL \
	$out_file \
	2 4 8 16 32 64 128 256"

gdaladdo \
	--config COMPRESS_OVERVIEW JPEG \
	--config INTERLEAVE_OVERVIEW PIXEL \
	$out_file \
	2 4 8 16 32 64 128 256