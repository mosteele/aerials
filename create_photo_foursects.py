# resources:
# http://gis.stackexchange.com/questions/149959/dissolve-polygons-based-on-attributes-with-python-shapely-fiona
# http://www.macwright.org/2012/10/31/gis-with-python-shapely-fiona.html
# plus shapely and fiona documentation

import fiona
from os import path
from shapely.ops import unary_union
from shapely.geometry import shape, mapping

rlis_dir = '//gisstore/gis/Rlis'
aerials_dir = '//gisstore/gis/PUBLIC/GIS_Projects/Aerials'
metro_dir = 'E:/admin/project_area'

photo_qtr_sects = path.join(metro_dir, 'photo14.shp')
sections = path.join(rlis_dir, 'TAXLOTS', 'sections.shp')
foursects = path.join(aerials_dir, 'shp', 'photo_foursects.shp')

# this mapping defines the groups of sections that make up foursects
foursect_mapping = {
	'a': [1, 2, 11, 12],	'b': [3, 4, 9, 10],		'c': [5, 6, 7, 8],
	'd': [17, 18, 19, 20], 	'e': [15, 16, 21, 22], 	'f': [13, 14, 23, 24],
	'g': [25, 26, 35, 36], 	'h': [27, 28, 33, 34], 	'i': [29, 30, 31, 32]
}

def createPhotoFoursects():
	"""Create foursects out of smaller section units for areas covered by
	the aerial flight define in the 'photo_qtr_sects' shapefile"""

	# the mapping must be reversed to be used as a tool to define groups
	reverse_mapping = {i:k for k,v in foursect_mapping.iteritems() for i in v}

	# union the photo quarter sections into a single geometry
	qtr_sect_geoms = []
	with fiona.open(photo_qtr_sects) as q_sects:
		for qs in q_sects: 
			qtr_sect_geoms.append(shape(qs['geometry']))

	unioned_qs = unary_union(qtr_sect_geoms)

	foursect_dict = {}
	with fiona.open(sections) as sects:
		meta_data = sects.meta.copy()

		for s in sects:
			geom = shape(s['geometry'])
			
			if geom.centroid.intersects(unioned_qs):
				# derive the foursect id of each section based it its section
				# id and the foursect mapping dictionary
				sect_id = s['properties']['SECTION']
				township = sect_id[:4]
				foursect = reverse_mapping[int(sect_id[4:])]

				foursect_id = '{0}-{1}'.format(township, foursect)
				if foursect_id not in foursect_dict:
					foursect_dict[foursect_id] = [geom]
				else:
					foursect_dict[foursect_id].append(geom)
				
	# modify properties such that only the field 'foursect' exists
	new_properties = [('foursect', 'str')]
	meta_data['schema']['properties'] = new_properties

	with fiona.open(foursects, 'w', **meta_data) as f_sects:
		for fid, geoms in foursect_dict.iteritems():
			# not totally clear on why 'mapping' needs to be used below, but it
			# seems that unary union only returns a representation and mapping
			# in turn produces a writeable object
			fs_feat = {
			 	'geometry': mapping(unary_union(geoms)),
			 	'properties': {'foursect': fid}}
			
			f_sects.write(fs_feat)

createPhotoFoursects()