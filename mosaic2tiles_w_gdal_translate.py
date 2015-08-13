import sys
import math
import subprocess
from os import path
from osgeo import gdal

# reference:
# http://download.osgeo.org/gdal/workshop/foss4ge2015/workshop_gdal.html#__RefHeading__5909_1333016408

# get vrt path and target tile directory from command line parameters
vrt_path = path.abspath(sys.argv[1])
tile_dir = path.abspath(sys.argv[2])
tile_basename = path.basename(tile_dir)

vrt = gdal.Open(vrt_path)
vrt_x = vrt.RasterXSize
vrt_y = vrt.RasterYSize

# creation option below (-co) reduce the size of the files (compress,
# photometric) and internally tile them (tiled) so that smaller portions 
# of the file alone can be retrived when appropriate
co1 = '-co "COMPRESS=JPEG"'
co2 = '-co "PHOTOMETRIC=YCBCR"'
co3 = '-co "TILED=YES"'
creation_ops = '{0} {1} {2}'.format(co1, co2, co3)

srcwin_template = '-srcwin {0} {1} {2} {3}'
gdal_template = 'gdal_translate {0} {1} {2} {3}'

y = 0
default_px = 22000

while y < vrt_y:
	x = 0
	if y + default_px < vrt_y:
		tile_y = default_px
	else:
		tile_y = vrt_y - y 

	while x < 40000: #vrt_x:
		if x + default_px < vrt_x:
			tile_x = default_px
		else:
			tile_x = vrt_x - x

		srcwin = srcwin_template.format(x, y, tile_x, default_px)

		row = int(math.ceil(y/default_px))
		col = int(math.ceil(x/default_px))
		tile_name = '{0}_{1}_{2}.tif'.format(tile_basename, row, col)
		tile_path = path.join(tile_dir, tile_name)

		gdal_cmd = gdal_template.format(srcwin, creation_ops, vrt_path, tile_path)
		print '\n', gdal_cmd
		subprocess.call(gdal_cmd)

		x += default_px

	break
	y += default_px