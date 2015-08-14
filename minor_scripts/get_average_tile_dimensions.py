import os
from os import path
from osgeo import gdal

raw_aerials = 'E:/compressed4band/3in'

dims_dict = {'x': [], 'y': []}
for item in os.listdir(raw_aerials):
	if item.endswith('.tif'):
		print item
		tiff_path = path.join(raw_aerials, item)
		tiff = gdal.Open(tiff_path)
		dims_dict['x'].append(tiff.RasterXSize)
		dims_dict['y'].append(tiff.RasterYSize)

		tiff = None

dims_avg = {k: sum(v)/len(v) for k, v in dims_dict.iteritems()}
print dims_avg