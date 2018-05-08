# Python/Pandas script to create the provider table used on the NBM2 application's Area Detail page
# Date: December 20, 2017

import pandas as pd
import numpy as np
import glob
import gc
import time
import os
import json

# the strat variable is used to calculate the script running time
starting_time = time.clock()

# load parent_config.json needed params
with open('./parent_config.json') as f:
    conf = json.load(f)

input_csvs_path = conf['input_csvs_path']
temp_csvs_path = conf['temp_csvs_path']
output_csvs_path = conf['output_csvs_path']

################### DEPENDENCIES ###################
# DATA:  BLOCKMASTER
# SCRIPTS:  block_numprov.py
####################################################

#Define output file name
output_fn=output_csvs_path+"area_table.csv"

#Location of block_numprov output files (with 0s instead of NULLs) required for processing
datadir=temp_csvs_path+"block_numprov_with0/"

#Unique geographies for which to do the aggregation
geo_ids=['nation_id','state_fips','county_fips','cbsa_code','cdist_id','tribal_id','cplace_id']
geo_type=['nation','state','county','cbsa','cd','tribal','place']
geo_dtype={}
for item in geo_ids:
    geo_dtype[item]=str

#Load Blockmaster data
blockmaster = pd.read_csv(input_csvs_path+'blockmaster_dec2016.csv',dtype=geo_dtype).rename(columns={'geoid10':'BlockCode'})
blockmaster.drop(['hu','aianhhcc','hh','stateabbr','h2only_undev'],axis=1,inplace=True)
blockmaster['nation_id']=0#add in an aggregate for the nation
blockmaster['nation_id']=blockmaster['nation_id'].astype(np.uint8)
groupcols=['id','nprovs','urban_rural','tribal_non']#add type and speed after the fact
keepcols=['tribal_non','urban_rural','pop']

#Get list of numprov files
pnum_list=glob.glob(datadir+"*")


#Create a list of different tech combos
techlist=np.array(['a','c','f','o','s','w'])
techcombo_dtype={}
for k in range(1,64):
    #Cast k to a binary value, which can be used as an index on techlist
    techlist_bool=np.array(list("{0:06b}".format(k)))=='1'
    techlist_i=techlist[techlist_bool]
    colname=''.join(list(techlist_i))
    techcombo_dtype[colname]=np.uint8


initflag_full=True
time1=time.time()
#Iterating through provider number files
for pnum_i in pnum_list:
    #Loading the number of provider files and parsing out dl speed
    nprovs=pd.read_csv(pnum_i,dtype=techcombo_dtype)
    speed_i=pnum_i.split('/')[-1].split('_')[2]
    if '.' in speed_i:
        speed_i=0.2
    else:
        speed_i=float(speed_i)
        
    #Preprocessing where number of providers equals 3
    for techcol in techcombo_dtype.keys():
        nprovs.loc[nprovs[techcol]>3,techcol]=3

    #Merging blockmaster with the block_numprov file
    blockmaster_i=blockmaster.merge(nprovs,on='BlockCode',how='left')
    del nprovs
    gc.collect()
    initflag=True
    #Iterating through the different geo types that we want to get sums for
    for col,gtype in zip(geo_ids,geo_type):
        #Dataframe is too large to pivot tech to long format; instead use a for loop
        for techcol in techcombo_dtype.keys():
            blockmaster_ii=blockmaster_i[[col]+keepcols+[techcol]].rename(columns={col:'id',techcol:'nprovs'})
            #Removing missing rows
            if col!='nation_id':
                blockmaster_ii=blockmaster_ii.loc[blockmaster_ii['id']!='']
            #Summing population for unique geo,tech,speed,urban/rural,tribal/non
            reduced_df=blockmaster_ii.groupby(groupcols).sum()
            reduced_df.reset_index(inplace=True,drop=False)
            
            #Pivoting the number of providers to wide format
            pivoted_df=reduced_df.pivot_table(index=['id','urban_rural','tribal_non'],columns='nprovs',values='pop')
            del reduced_df
            gc.collect()
            pivoted_df=pivoted_df.rename(columns={0:'has_0',1:'has_1',2:'has_2',3:'has_3plus'})
            pivoted_df.fillna(0.,inplace=True)
            for hascol in ['has_0','has_1','has_2','has_3plus']:
                if hascol not in pivoted_df.columns:
                    pivoted_df[hascol]=0
                pivoted_df[hascol]=pivoted_df[hascol].astype(np.uint32)

            pivoted_df['type']=gtype
            pivoted_df['tech']=techcol
            pivoted_df['speed']=speed_i
            pivoted_df.reset_index(inplace=True,drop=False)
            #Concatenating dataframes
            if initflag:
                df_return=pivoted_df.copy()
                initflag=False
            else:
                df_return=pd.concat([df_return,pivoted_df])
            del pivoted_df
            gc.collect()  
        print('done with '+col,time.time()-time1)
    #Concatenating dataframes
    if initflag_full:
        df_return_full=df_return.copy()
        initflag_full=False
    else:
        df_return_full=pd.concat([df_return_full,df_return])
    del df_return
    gc.collect()
    print('done with '+pnum_i,time.time()-time1)

#Cleaning up and writing to file
del blockmaster_i
gc.collect()
df_return_full.sort_values(['type','id','tech','speed','urban_rural','tribal_non'],inplace=True)
df_return_full[['type','id','tech','speed','urban_rural','tribal_non','has_0','has_1','has_2','has_3plus']].to_csv(output_fn,index=False)


#Cleaning up the aesthetics of the output file
with open(output_fn,'r') as fn:
    output_orig=fn.readlines()
#Removing zeros to the right of the decimal in the speed column
out_red=[i.replace('.0,',',') for i in output_orig]

#Writing to new file
out_str=output_fn
print(out_str)
os.remove(output_fn)
with open(out_str,'w') as fn:
    fn.writelines(out_red)
del output_orig
del out_red
gc.collect()


##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step3_area_table.py took: '+str(round(running_time/60,2))+' minutes.')
