# Resources:
# thanks to Even Rouault for pointing me to the first link:
# http://download.osgeo.org/gdal/workshop/foss4ge2015/workshop_gdal.html#__RefHeading__5909_1333016408
# http://gis.stackexchange.com/questions/7608/shapefile-prj-to-postgis-srid-lookup-table/7615#7615
# https://pcjericks.github.io/py-gdalogr-cookbook/projection.html
# http://gis.stackexchange.com/questions/60371/gdal-python-how-do-i-get-coordinate-system-name-from-spatialreference

import os
import sys
import fiona
import subprocess
from os import path
from osgeo import gdal, ogr, osr
from shapely.geometry import shape

def createTranformation():
	"""Create a transformation object from the oregon state plane north
	to the input vrt projection if they are different"""
	
	transform = None

	# Get the epsg of the projected coordinate system of the input vrt
	vrt = gdal.Open(vrt_path)
	vrt_prj = vrt.GetProjection()
	vrt_srs = osr.SpatialReference(wkt=vrt_prj)
	vrt_epsg = vrt_srs.GetAuthorityCode(None)

	if vrt_epsg != '2913':
		s_srs = osr.SpatialReference()
		s_srs.ImportFromEPSG(2913)

		t_srs = osr.SpatialReference()
		t_srs.ImportFromEPSG(int(vrt_epsg))

		transform = osr.CoordinateTransformation(s_srs, t_srs)

	return transform

def getFlightTiles(flight_shp, unit):
	"""The photo flight was only flown over a subset of the units that 
	exists in the survey unit datasets, based on the desired output unit
	this function returns only parcels that were a part of the flight"""

	survey_dir = '//gisstore/gis/Rlis/TAXLOTS'
	unit_dict = {
		'SECTION': 'sections.shp'
	}

	if unit == 'QTRSEC':
		flight_tiles = flight_shp
	elif unit == 'SECTION':
		sections_set = set()
		with fiona.open(flight_shp) as flight:
			for ft in flight:
				s_id = ft['properties']['QTRSEC'][:-1]
				sections_set.add(s_id)

		section_path = path.join(survey_dir, unit_dict[unit])
		with fiona.open(section_path) as sections:
			metadata = sections.meta.copy()

			section_name = '{0}_sections'.format(path.basename(flight_shp))
			flight_tiles = path.join(project_dir, 'shp', section_name)
			with fiona.open(flight_tiles, 'w', **metadata) as flight_sects:
				for s in sections:
					name = s['properties'][unit]
					if name in sections_set:
						flight_sects.write(s)
	else:
		print 'This unit type is misspelled or not handled by this code'
		exit()

	return flight_tiles

def extractTilesFromMosaic(out_format, creation_ops, config, unit):
	"""""" 

	transform = createTranformation()
	flight_tiles = getFlightTiles(flight14_shp, unit)

	format_str = '-of "{0}"'.format(out_format)
	creation_str = ' '.join(['-co "{0}"'.format(co) for co in creation_ops])
	config_str = ' '.join(['--config {0}'.format(cfg) for cfg in config])
	gdal_template = 'gdal_translate {0} {1} {2} {3} {4} {5}'

	with fiona.open(flight_tiles) as tiles:
		for t in tiles:
			geom = shape(t['geometry'])
			props = t['properties']
			survey_name = props[unit]

			# bounding box is a returned as a tuple like: 
			# (x-min, y-min, x-max, y-max)		
			b_box = geom.bounds

			# if the bounding box coordinates need to be reprojected, turn them
			# into two points (lower left & upper right corners), reproject 
			# those then extract the new coordinates from the points
			if transform:
				corner_pts = [(b_box[0], b_box[1]), (b_box[2], b_box[3])]

				b_box = []
				for x, y in corner_pts:
					wkt_pt = 'POINT ({0} {1})'.format(x, y)
					ogr_pt = ogr.CreateGeometryFromWkt(wkt_pt)
					
					ogr_pt.Transform(transform)
					b_box.extend([ogr_pt.GetX(), ogr_pt.GetY()])
			
			# the bounding box coordinates must be in the following order for
			# gdal_translate: x-min, y-max, x-max, y-min which is different
			# from how they are returned from shapely, they're reordered below
			pwin_order = [1, 4, 3, 2]
			pwin_coords = [str(j) for i,j in sorted(zip(pwin_order,b_box))]
			projwin_str = '-projwin {0}'.format(' '.join(pwin_coords))
			
			# for cad consumption tiles need to be stored in a folder that is
			# name by the township that they belong to which is the first four
			# characters of a child of a township
			tile_sub_dir = path.join(tile_dir, survey_name[:4])
			if not path.exists(tile_sub_dir):
				os.makedirs(tile_sub_dir)

			tile_path = path.join(tile_sub_dir, '{0}.jpg'.format(survey_name))
			gdal_cmd = gdal_template.format(format_str, projwin_str, 
				creation_str, config_str, vrt_path, tile_path)
			
			# flush is used here so print statements will be sent directly to 
			# a log file, without this they collect and are written intermittently
			print '\n', gdal_cmd
			sys.stdout.flush()

			subprocess.call(gdal_cmd)

# get vrt path, target tile directory and the survey unit to base the tiles upon
# from command line parameters
vrt_path = path.abspath(sys.argv[1])
tile_dir = path.abspath(sys.argv[2])
tile_unit = path.abspath(sys.argv[3])

survey_dir = '//gisstore/gis/Rlis/TAXLOTS'
project_dir = '//gisstore/gis/PUBLIC/GIS_Projects/Aerials'
flight14_shp = path.join(project_dir, 'shp', 'photo14.shp')

# creation option below (-co) reduce the size of the files (compress,
# photometric) and internally tile them (tiled) so that smaller portions 
# of the file alone can be retrived when appropriate
out_format = 'JPEG'
creation_ops = ['WORLDFILE=YES']
config = ['GDAL_CACHEMAX 1000']
unit = 'SECTION'

extractTilesFromMosaic(out_format, creation_ops, config, unit)