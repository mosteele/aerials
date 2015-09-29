# !/bin/bash

pixel_char='u'

for dir in G:/AERIALS/tempCurrent/*; do
	if [ -d "$dir" -a ${dir##*/} != 'shp' ]; then
		for file in ${dir}/*; do
			basename=${file##*/}
			name=${basename%%.*}
			ext=${basename#*.}

			pixel_file="${dir}/${name}${pixel_char}.${ext}"
			mv $file $pixel_file
		done 
	fi
done