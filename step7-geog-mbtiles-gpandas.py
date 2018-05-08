############################
#Created by Ahmad Aburizaiza
############################
import os
import json
import time
import pandas as pd
import geopandas as gpd

# the strat variable is used to calculate the script running time
starting_time = time.clock()

# helper functions
def concat_list(minx,miny,maxx,maxy):
    l = []
    l.append(minx)
    l.append(miny)
    l.append(maxx)
    l.append(maxy)
    l = str(l)
    return l

# get the parameters from tippe_config.json file
with open('parent_config.json') as f:
    conf = json.load(f)

# define the parameters from tippe_conf json object
temp_geog_geojsons_path = conf['temp_geog_geojsons_path']
output_mbtiles_path = conf['output_mbtiles_path']
input_geog_shapefiles_path = conf['input_geog_shapefiles_path']
input_geog_geojsons_path = conf['input_geog_geojsons_path']
zoom_params = conf['zoom_params']
host = conf['postgres']['host']
schema = conf['postgres']['schema']
dbname = conf['postgres']['dbname']
user  = conf['postgres']['user']
password = conf['postgres']['password']
port = conf['postgres']['port']

PG = 'dbname='+dbname+' user='+user+' password='+password+' host='+host+' port='+port

# Step 1: upload census shapefiles into postgres

# Step 2: create bboxes in in the shapefiles and export to geojsons
for filename in os.listdir(input_geog_shapefiles_path):
    if filename.endswith('.shp'):
        # load a geopandas dataframe
        shp_df = gpd.read_file(input_geog_shapefiles_path+filename)
        # create a dataframe of minx, miny, maxx, and maxy values based on the geometry column 
        bounds_df = shp_df['geometry'].bounds
        # create a new column to populate lists of [minx,miny,maxx,maxy]
        # the first assignment of '' is to ensure that the column is of data type 'object'
        bounds_df['bbox_arr'] = ''
        bounds_df['bbox_arr'] = bounds_df.apply(lambda row: concat_list(row['minx'],row['miny'],row['maxx'],row['maxy']),axis=1)
        # concatenate the attribute columns in shp_df and the bounds dataframes into one dataframe
        new_df = pd.concat([shp_df, bounds_df], axis=1)
        # sort the new dataframe by geoid
        new_df.sort_values('GEOID', inplace=True)
        # update Alaska, Aleutian west county, and Alaska congressional district
        # Alaska State
        if 'state' in filename:
            idx = new_df[new_df['GEOID'] == '02'].index
            new_df.set_value(idx, 'bbox_arr', '[-188.148909,51.214183,-128.77847,71.365162]')
        # Aleutian West County
        if 'county' in filename:
            idx = new_df[new_df['GEOID'] == '02016'].index
            new_df.set_value(idx, 'bbox_arr', '[-187.75585,51.214183,-165.77847,57.249626]')
        # Alaska Congressional District
        if 'cd115' in filename:
            idx = new_df[new_df['GEOID'] == '0200'].index
            new_df.set_value(idx, 'bbox_arr', '[-188.148909,51.214183,-128.77847,71.365162]')
        # Drop unneeded columns
        unneeded_cols = []
        for col in new_df.columns:
            if col not in ['GEOID','NAME','name','bbox_arr','geometry']:
                unneeded_cols.append(col)
        new_df.drop(unneeded_cols,axis=1,inplace=True)
        # export results to geojson
        try: 
            os.remove(temp_geog_geojsons_path+filename[0:-4]+'.geojson')
        except OSError:
            pass
        new_df.to_file(temp_geog_geojsons_path+filename[0:-4]+'.geojson', driver="GeoJSON")
        print(filename[0:-4]+'.geojson created')

# the blocks cannot be stored in .shp format because > 2 GB "19 GB" nor in geopandas df
# the following will read the blocks as geojson under input_geog_geojsons_path
try: 
    os.remove(temp_geog_geojsons_path+'block_2010.geojson')
except OSError:
    pass

sql_stmt = "SELECT block_fips, geom, string_to_array(replace(replace(replace(Cast(box2d(geom) as varchar), ' ', ','), 'BOX(', ''), ')', ''),',')::numeric(10,7)[] as bbox_arr from nbm2.block_2010 order by block_fips"     
ogr2ogr_cmd = 'ogr2ogr -f "GeoJSON" '+temp_geog_geojsons_path+'block_2010.geojson -nln block_2010.geojson PG:"'+PG+'" -sql "'+sql_stmt+'"'
os.system(ogr2ogr_cmd)
print('block_2010.geojson created')

    
# Step 3: loop through the geojsons files in the geojsons path to create mbtiles

for filename in os.listdir(temp_geog_geojsons_path):
    if filename.endswith('.geojson'):
        tippe_command = 'tippecanoe -o '+output_mbtiles_path+filename[0:-8]+'.mbtiles '+temp_geog_geojsons_path+filename+' --force --coalesce-smallest-as-needed --drop-densest-as-needed --minimum-zoom='+zoom_params[filename[0:-8]][0]+' --maximum-zoom='+zoom_params[filename[0:-8]][1]
        os.system(tippe_command)
        print(filename[0:-8]+'.mbtiles created')


##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step7_geog_mbtiles_gpandas.py took: '+str(round(running_time/60,2))+' minutes.')