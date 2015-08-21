import sys
import fiona
import subprocess
from os import path
from osgeo import gdal
from shapely.geometry import shape

# some of the gdal-python stuff here was derived from below, thanks to
# Even Rouault for pointing me to this:
# http://download.osgeo.org/gdal/workshop/foss4ge2015/workshop_gdal.html#__RefHeading__5909_1333016408

aerials_dir = '//gisstore/gis/PUBLIC/GIS_Projects/Aerials'
photo_foursects = path.join(aerials_dir, 'shp', 'photo_foursects.shp')

# # get vrt path and target tile directory from command line parameters
# vrt_path = path.abspath(sys.argv[1])
# tile_dir = path.abspath(sys.argv[2])
# tile_basename = path.basename(tile_dir)

# vrt = gdal.Open(vrt_path)
# vrt_x = vrt.RasterXSize
# vrt_y = vrt.RasterYSize

# creation option below (-co) reduce the size of the files (compress,
# photometric) and internally tile them (tiled) so that smaller portions 
# of the file alone can be retrived when appropriate
co1 = '-co "COMPRESS=JPEG"'
co2 = '-co "PHOTOMETRIC=YCBCR"'
co3 = '-co "TILED=YES"'
creation_ops = '{0} {1} {2}'.format(co1, co2, co3)

projwin_template = '-srcwin {0} {1} {2} {3}'
projwin_srs = 'EPSG:2913'
gdal_template = 'gdal_translate {0} {1} {2} {3}'

with fiona.open(photo_foursects) as foursects:
	for fs in foursects:
		fs_name = fs['properties']['foursect'].replace('-', '_')
		geom = shape(fs['geometry'])
		
		# bounding box is a returned as a tuple like: 
		# (minx, miny, maxx, maxy)
		b_box = geom.bounds
		print b_box
		print fs_name













# srcwin_template = '-srcwin {0} {1} {2} {3}'
# gdal_template = 'gdal_translate {0} {1} {2} {3}'

# # given that pixels are 1/4 of a foot in this case the following tile
# # sizes result in the paired units (note the output will not align with
# # official government boundaries for these units):
# # 10,560 px = quarter section
# # 21,120 px = section
# # 42,240 px = foursect
# default_px = 42240

# y = 0
# while y < vrt_y:
# 	x = 0
# 	if y + default_px < vrt_y:
# 		tile_y = default_px
# 	else:
# 		tile_y = vrt_y - y 

# 	while x < vrt_x:
# 		if x + default_px < vrt_x:
# 			tile_x = default_px
# 		else:
# 			tile_x = vrt_x - x

# 		srcwin = srcwin_template.format(x, y, tile_x, tile_y)
# 		row = int(math.ceil(y/default_px))
# 		col = int(math.ceil(x/default_px))
# 		tile_name = '{0}_{1}_{2}.tif'.format(tile_basename, row, col)
# 		tile_path = path.join(tile_dir, tile_name)

# 		gdal_cmd = gdal_template.format(srcwin, creation_ops, vrt_path, tile_path)
# 		print '\n', gdal_cmd
# 		subprocess.call(gdal_cmd)

# 		x += default_px
# 	y += default_px