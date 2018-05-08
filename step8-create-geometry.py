import psycopg2
import pandas as pd
import numpy as np
import geopandas as gp
import json
import time

# the strat variable is used to calculate the script running time
starting_time = time.clock()

# load parent_config.json needed params
with open('./parent_config.json') as f:
    conf = json.load(f)

input_csvs_path = conf['input_csvs_path']
input_speed_shapefiles_path = conf['input_speed_shapefiles_path']
output_csvs_path = conf['output_csvs_path']
temp_speed_geojsons_path = conf['temp_speed_geojsons_path']
temp_csvs_path = conf['temp_csvs_path']
temp_geog_geojsons_path = conf['temp_geog_geojsons_path']

con = psycopg2.connect(host='gisp-proc-wcb-pg-int.cfddrd5nduv6.us-west-2.rds.amazonaws.com', user='wcb_cray', password='wcb_cray', database='wcb_internal')
sql = "SELECT geoid10, aland10, geom FROM census2010.block_us"
starting_crs={'init':'epsg:4326'} # need to provide this manually since geopandas can't read crs of postgis (use Find_SRID to get this)
block_df = gp.read_postgis(sql,con, crs=starting_crs)

# Check crs
block_df.crs

# Main output geojson, only with columns of interest, sorted by geoid for use with tippecanoe
block_df[['geoid10','geom']].sort_values('geoid10',ascending=True).to_file(temp_speed_geojsons_path+'block_us.sort.geojson', driver='GeoJSON')
print(temp_speed_geojsons_path+'block_us.sort.geojson created')
# Second output: h2only_undev (and/or list of water-only blocks)
# block_df[['geoid10','aland10']].loc[block_df.aland10==0].sort_values('geoid10',ascending=True).to_csv('water_only_blocks.csv', index=False, float_format='%1.f')
df1 = block_df[['geoid10','aland10']].loc[block_df.aland10==0].sort_values('geoid10',ascending=True)
df2 = pd.read_csv(input_csvs_path+'us2016.csv', dtype={'block_fips':str})

df_out = pd.merge(df2, df1, how='left', left_on='block_fips', right_on='geoid10')
df_out['h2only_undev']=0
df_out['h2only_undev'].loc[df_out.aland10==0]=1
df_out['h2only_undev'].loc[(df_out.aland10!=0) & (df_out.hu2016==0) & (df_out.pop2016==0)]=2
 
df_out.to_csv(temp_csvs_path+'h2only_undev.csv', columns=['block_fips','h2only_undev'], index=False)
print(temp_csvs_path+'h2only_undev.csv created')


# Additional processing of block data for tracts below...

# Third output: blocks and geometries for large tracts: Read in tract areas, then write out block data for tracts with area > 5e8
tract_area=pd.read_csv(input_csvs_path+'tract_area_m.csv',dtype={'tract_fips':str})
block_df[['geoid10','geom']].loc[block_df.tract_id.isin(tract_area['tract_fips'].loc[tract_area.area>5.e8])].sort_values('geoid10',ascending=True).to_file(temp_speed_geojsons_path+'bigtract_blocks_5e8_2010_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'bigtract_blocks_5e8_2010_4326.sort.geojson created')

# Fourth output: geometries for blocks with bounding box that requires < 11 (based on largeblocks.csv)
list_df=pd.read_csv(input_csvs_path+'largeblocks.csv', sep='|', quotechar="'", dtype={'block_fips':str})
list_df['min_zoom']=list_df[['x_zoom','y_zoom']].min(axis=1)

block_large_df=block_df.loc[block_df.geoid10.isin(list_df.block_fips)]
block_large_df=block_large_df.merge(list_df[['block_fips','min_zoom']], left_on='geoid10', right_on='block_fips', inplace=True)
block_large_df[['geoid10','min_zoom','geom']].sort_values('geoid10',ascending=True).to_file(temp_speed_geojsons_path+'xlarge_blocks.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'xlarge_blocks.geojson created')
# assign tract ID to block data frame
block_df['tract_id']=block_df.geoid10.str[:11]

# Dissolve by tract ID for blocks with aland10>0
tract_df=block_df[['tract_id','geom']].loc[block_df.aland10>0].dissolve(by='tract_id')

# Save this as a geojson so you don't have to dissolve again in the future
tract_df.sort_values('tract_id',ascending=True).to_file(temp_speed_geojsons_path+'tracts_2010_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'tracts_2010_4326.sort.geojson created')
# Move tract_id from index into field (can't seem to specify how to write index in geopandas; not like to_csv)
tract_df['tract_id']=tract_df.index
tract_df['area']=tract_df.to_crs({'init':'epsg:3857'}).geometry.area

# Write out list of tracts with area in square meters
tract_df[['tract_id','area']].sort_values('tract_id').to_csv(temp_csvs_path+'tract_area_m_2.csv', index=False)
print(temp_csvs_path+'tract_area_m_2.csv created')
tract_area=pd.read_csv(temp_csvs_path+'tract_area_m_2.csv',dtype={'tract_id':str})

# Write out tracts and geometry for not-large tracts (<=5.e8 square meters)
# Since tract_id is the index, it's already sorted
tract_df=tract_df.reset_index()
tract_df[['tract_id','geom']].loc[tract_df.tract_id.isin(tract_area['tract_id'].loc[tract_area.area<=5.e8])].to_file(temp_speed_geojsons_path+'notbig_tracts_5e8_2010_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'notbig_tracts_5e8_2010_4326.sort.geojson created')
# Save this as a geojson so you don't have to dissolve again in the future
tract_df.sort_values('tract_id',ascending=True).to_file(temp_speed_geojsons_path+'tracts_land_2010_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'tracts_land_2010_4326.sort.geojson created')
# Read in cartographic tracts for states, DC
carto_tract_df=gp.read_file(temp_geog_geojsons_path+'tract_2010.geojson')

# Read in cartographic tracts for PR
pr_df = gp.read_file(input_speed_shapefiles_path+'gz_2010_72_140_00_500k.shp')
pr_df['tract_id']=pr_df.GEO_ID.str[-11:]
pr_out=pr_df[['tract_id','geometry']]

# Create df with cartographic tracts + full tracts for AS (60), GU (66), MP (69) and VI (78)
carto_tract_df['tract_id']=carto_tract_df.geo_id.str[-11:]
carto_tract_out=carto_tract_df[['tract_id','geometry']]
carto_tract_out=carto_tract_out.append(tract_df.rename(columns={'geom':'geometry'})[['tract_id','geometry']].loc[tract_df.tract_id.str[:2].isin(['60','66','69','78'])], ignore_index=True)
carto_tract_out=carto_tract_out.append(pr_out, ignore_index=True)

# Write out final "cartographic tract" geojson
carto_tract_out.sort_values('tract_id',ascending=True).to_file(temp_speed_geojsons_path+'tract_2010_500k_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'tract_2010_500k_4326.sort.geojson created')
# read in shapefile
county_df=gp.read_file(input_speed_shapefiles_path+'gz_2010_us_050_00_500k.shp')
# some housekeeping
county_df.to_crs({'init':'epsg:4326'}, inplace=True)
county_df['geoid10']=county_df.GEO_ID.str[-5:]
# create df for counties for AS (60), GU (66), MP (69) and VI (78)
tract_df['county_id']=tract_df.tract_id.str[:5]
county_island_df=tract_df[['county_id','geom']].loc[tract_df.tract_id.str[:2].isin(['60','66','69','78'])].dissolve(by='county_id')
# append island counties to main county_df and write out geojson
county_island_df['geoid10']=county_island_df.index
county_out=county_df[['geoid10','geometry']]
county_out=county_out.append(county_island_df.rename(columns={'geom':'geometry'})[['geoid10','geometry']], ignore_index=True)
county_out.sort_values('geoid10',ascending=True).to_file(temp_speed_geojsons_path+'county_2010_500k_4326.sort.geojson',driver='GeoJSON')
print(temp_speed_geojsons_path+'county_2010_500k_4326.sort.geojson created')

fbd_df=pd.read_csv(input_csvs_path+'fbd_us_with_satellite_jun2016_v1.csv', dtype={'Census Block FIPS Code':str, 'Holding Company Number':str}, usecols=['Census Block FIPS Code', 'Consumer', 'Holding Company Number', 'Technology Code', 'Max Advertised Downstream Speed (mbps)', 'Max Advertised Upstream Speed (mbps)'])
prov_df=fbd_df[['Holding Company Number','Census Block FIPS Code']].loc[fbd_df.Consumer==1]
prov_df.columns=['hoconum','block_fips']

block_df['county_fips']=block_df.geoid10.str[:5]

big_df=block_df[['geoid10','geom','county_fips']].merge(prov_df, left_on='geoid10', right_on='block_fips')
prov_footprint_df=big_df[['hoconum','county_fips','geom']].dissolve(by=['hoconum','county_fips'])
prov_footprint_df.reset_index(inplace=True)
# Since the dissolve function treats hoconum as an index (before the reset_index), records are ordered by hoconum, which is important in styling the map

prov_footprint_large_df=prov_footprint_df.loc[prov_footprint_df.hoconum.isin(['300167','290111','130627','130077','130228','130317','130258'])]
prov_footprint_other_df=prov_footprint_df.loc[~prov_footprint_df.hoconum.isin(['300167','290111','130627','130077','130228','130317','130258'])]
prov_footprint_large_df.to_file(temp_speed_geojsons_path+'geojsons/prov_large_dec2016_7nov17.geojson', driver='GeoJSON')
print(temp_speed_geojsons_path+'geojsons/prov_large_dec2016_7nov17.geojson created')
prov_footprint_other_df.to_file(temp_speed_geojsons_path+'geojsons/prov_other_dec2016_7nov17.geojson', driver='GeoJSON')
print(temp_speed_geojsons_path+'geojsons/prov_other_dec2016_7nov17.geojson created')


##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step8_create_geometry.py took: '+str(round(running_time/60,2))+' minutes.')