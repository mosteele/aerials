::Grant Humphries for TriMet, 2014
::Windows Version: 7 Professional, SP1
::GDAL Version: 1.10.1
::---------------------------------

::Portions of this script derived from here:
::http://stackoverflow.com/questions/16691943/how-to-loop-through-several-files-using-gdal-and-cmd
::Once this script has run be sure to set the permission on the 'New_Current' folder to 'Everyone'

@ECHO OFF
SETLOCAL EnableDelayedExpansion

::Store the start time of the script in a variable
SET t0=%time: =0%

::Assign project file paths to variables, these names should not begin with a number
SET SixInch=G:\AERIALS\2013_July\rgb3band
SET Resampled=G:\AERIALS\2013_July\rgb3band_aux\resamples
SET Output=G:\AERIALS\New_Current

::In order for variables to be return, when EnableDelayedExpansion is on, they must be bracketed with 
::percentage signs.  Note that things work differently inside of a for loop
IF NOT EXIST %Output% MKDIR %Output%

::For each .tif take the file name and truncate it down to its first four letters.  Then create a new_folder
::with that name in the output directory when unique.  Note that within the For block it results in fewer
::errors to use REM instead of :: to comment out lines
FOR /F %%i IN ('DIR /B %SixInch%\*.tif') DO (
	REM The %%i phrase is a varible that holds the name of each file that is being looped through in the 
	REM folder named above, however to be called up it must be assigned to standard batch file variable
	SET file_name=%%i

	REM Within a for loop, when EnableDelayedExpansion is on, variables must be bracketed with exclamation
	REM points, percentage signs won't work in these cases.  The notation ':~x,y' used below generates a 
	REM substring.  The 'x' is the starting point in the string, a zero-based index, and the 'y' is the
	REM number of characters to be included.  Negative numbers can also be used to start from the end of the
	REM string
	SET new_folder=!Output!\!file_name:~0,4!
	ECHO !new_folder!

	IF NOT EXIST !new_folder! MKDIR !new_folder!

	REM Convert each aerial into the Oregon State Plane North Projection and put the output into the newly
	REM created sub-folder.  The "tiled=yes" and "compress=jpeg" compress the tile reducing the file size
	REM and the "tfw=yes"
	gdalwarp -t_srs "epsg:2913" -co "tiled=yes" -co "compress=jpeg" -co "tfw=yes" !SixInch!\!file_name! !new_folder!\!file_name!

	REM Convert the reprojected imagery into .jpg format.  The first clause below replaces the .tif at the
	REM end of the file name and replaces it with .jpg and stores that new name in a varaible
	SET jpeg_file=!file_name:.tif=.jpg!
	gdal_translate -of "jpeg" -co "worldfile=yes" !new_folder!\!file_name! !new_folder!\!jpeg_file!
)

::ECHO Continue to Process Resampled Aerials?
::PAUSE

::The reprojection and conversion that occured in the loop above only covered the 6-inch aerial imagery,
::the same tasks now need to be done for the other resolutions which are stored in a different folder
FOR /F %%i IN ('DIR /B %Resampled%\*.tif') DO (
	SET file_name=%%i
	SET out_folder=!Output!\!file_name:~0,4!

	gdalwarp -t_srs "epsg:2913" -co "tiled=yes" -co "compress=jpeg" -co "tfw=yes" !Resampled!\!file_name! !out_folder!\!file_name!

	SET jpeg_file=!file_name:.tif=.jpg!
	gdal_translate -of "jpeg" -co "worldfile=yes" !out_folder!\!file_name! !out_folder!\!jpeg_file!
)

::ECHO Transfer Supplementary Location Files?
::PAUSE

::Add supplementary files that describe the geo-spatial position of the aerials. The folders and their
::contents will be copied using the xcopy command
SET base_folder=%SixInch:~0,-9%
ECHO %base_folder%

SET flight_lines=flightlines
XCOPY %base_folder%\%flight_lines% %Output%\%flight_lines% /S /E /I

SET photo_centers=photo_centers
XCOPY %base_folder%\%photo_centers% %Output%\%photo_centers% /S /E /I

::Store script end time in a variable
SET t=%time: =0%

::Parse start and end times into hours, minutes and seconds.  The numbers must be added to a 1 and then
::subtracted from 100 to elimate leading zeros.  The /A parameter makes it so that arithmethic computations
::can take place before the value is assigned to the variable
SET /A s_hours=1%t0:~0,2% - 100
SET /A s_mins=1%t0:~3,2% - 100
SET /A s_secs=1%t0:~6,2% - 100

::Convert all time units to seconds and add them
SET /A start_secs = %s_hours% * 3600 + %s_mins% * 60 + %s_secs%

::Now do the same thing for the end time
SET /A e_hours=1%t:~0,2% - 100
SET /A e_mins=1%t:~3,2% - 100
SET /A e_secs=1%t:~6,2% - 100

SET /A end_secs = %e_hours% * 3600 + %e_mins% * 60 + %e_secs%

::Subtract the end seconds from the beginning second
SET /A runtime = end_secs - start_secs

ECHO Runtime:
ECHO %runtime% Seconds

::Ran in ~22 hours on 4/1/14