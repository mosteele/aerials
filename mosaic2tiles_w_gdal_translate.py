# Resources:
# thanks to Even Rouault for pointing to the first link:
# http://download.osgeo.org/gdal/workshop/foss4ge2015/workshop_gdal.html#__RefHeading__5909_1333016408
# http://gis.stackexchange.com/questions/7608/shapefile-prj-to-postgis-srid-lookup-table/7615#7615
# https://pcjericks.github.io/py-gdalogr-cookbook/projection.html
# http://gis.stackexchange.com/questions/60371/gdal-python-how-do-i-get-coordinate-system-name-from-spatialreference

import sys
import fiona
import subprocess
from os import path
from osgeo import gdal, ogr, osr
from shapely.geometry import shape

aerials_dir = '//gisstore/gis/PUBLIC/GIS_Projects/Aerials'
photo_foursects = path.join(aerials_dir, 'shp', 'photo_foursects.shp')

# # get vrt path and target tile directory from command line parameters
vrt_path = path.abspath(sys.argv[1])
tile_dir = path.abspath(sys.argv[2])

# creation option below (-co) reduce the size of the files (compress,
# photometric) and internally tile them (tiled) so that smaller portions 
# of the file alone can be retrived when appropriate
co1 = '-co "COMPRESS=JPEG"'
co2 = '-co "PHOTOMETRIC=YCBCR"'
co3 = '-co "TILED=YES"'
creation_ops = '{0} {1} {2}'.format(co1, co2, co3)
cache_max = '--config GDAL_CACHEMAX 1000'
projwin_srs = '-projwin_srs "EPSG:2913"'
gdal_template = 'gdal_translate {0} {1} {2} {3} {4}'

# Get the epsg of the projected coordinate system of the input vrt
vrt = gdal.Open(vrt_path)
vrt_prj = vrt.GetProjection()
vrt_srs = osr.SpatialReference(wkt=vrt_prj)
vrt_epsg = vrt_srs.GetAuthorityCode(None)

# create a transformation object from the oregon state plane north to
# the input vrt projection if they are different
reproject = False
if vrt_epsg != '2913':
	s_srs = osr.SpatialReference()
	s_srs.ImportFromEPSG(2913)

	t_srs = osr.SpatialReference()
	t_srs.ImportFromEPSG(int(vrt_epsg))

	transform = osr.CoordinateTransformation(s_srs, t_srs)
	reproject = True
	wkt_template = 'POINT ({0} {1})'

with fiona.open(photo_foursects) as foursects:
	for fs in foursects:
		fs_name = fs['properties']['foursect'].replace('-', '_')
		geom = shape(fs['geometry'])

		# bounding box is a returned as a tuple like: 
		# (x-min, y-min, x-max, y-max)		
		b_box = geom.bounds

		# if the bounding box coordinates need to be reprojected, turn them
		# into two points (lower left & upper right corners), reproject those
		# then extract the new coordinates from the points
		if reproject:
			corner_pts = [(b_box[0], b_box[1]), (b_box[2], b_box[3])]

			b_box = []
			for x, y in corner_pts:
				wkt_pt = wkt_template.format(x, y)
				ogr_pt = ogr.CreateGeometryFromWkt(wkt_pt)
				
				ogr_pt.Transform(transform)
				b_box.extend([ogr_pt.GetX(), ogr_pt.GetY()])
		
		# the bounding box coordinates must be in the following order for
		# gdal_translate: x-min, y-max, x-max, y-min which is different
		# from how they are returned from shapely, they're reordered below
		pwin_order = [1, 4, 3, 2]
		pwin_coords = [str(j) for i,j in sorted(zip(pwin_order,b_box))]
		
		projwin = '-projwin {0}'.format(' '.join(pwin_coords))
		tile_path = path.join(tile_dir, '{0}.tif'.format(fs_name))
		gdal_cmd = gdal_template.format(projwin, creation_ops, 
			cache_max, vrt_path, tile_path)
		
		print '\n', gdal_cmd
		subprocess.call(gdal_cmd)

		break