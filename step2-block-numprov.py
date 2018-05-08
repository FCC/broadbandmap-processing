# Python/Pandas script to create the block_numprov exports by speed tier combination
# Date: December 20, 2017

import pandas as pd
import string
import numpy as np
import time
import gc
import glob
import os
import json

# the strat variable is used to calculate the script running time
starting_time = time.clock()

with open('./parent_config.json') as f:
    conf = json.load(f)

input_csvs_path = conf['input_csvs_path']
temp_csvs_path = conf['temp_csvs_path']
output_csvs_path = conf['output_csvs_path']

################### DEPENDENCIES ###################
# DATA:  RAW FORM 477, BLOCKMASTER
# SCRIPTS:  NONE 
####################################################

################### LOAD INPUT CSV FILES AND DEFINE OUTPUT ###################
#Load Form 477 data
df = pd.read_csv(input_csvs_path+"fbd_us_with_satellite_jun2016_v1.csv", usecols=['Census Block FIPS Code', 'Consumer', 'Holding Company Number', 'Technology Code', 'Max Advertised Downstream Speed (mbps)', 'Max Advertised Upstream Speed (mbps)'])
#Rename columns using the commented code below should any of the column names change
df=df.rename(columns = {'Census Block FIPS Code':'BlockCode','Consumer':'Consumer','Holding Company Number':'HocoNum','Technology Code':'TechCode','Max Advertised Downstream Speed (mbps)':'MaxAdDown','Max Advertised Upstream Speed (mbps)':'MaxAdUp'})

#Load Blockmaster data
blockmaster = pd.read_csv(input_csvs_path+'blockmaster_dec2016.csv', usecols=['geoid10','pop']).rename(columns={'geoid10':'BlockCode'})

#Set output directories for block_numprov files with 0s and with NULLs (used in Socrata)
out_dir = temp_csvs_path+'block_numprov_withnull/'
out_dir_tmp=temp_csvs_path+'block_numprov_with0/'
if not os.path.isdir(out_dir):
    os.mkdir(out_dir)
if not os.path.isdir(out_dir_tmp):
    os.mkdir(out_dir_tmp)
###############################################################################

#Keep Form 477 records where consumer = 1 
df = df.loc[df.Consumer == 1, ['BlockCode', 'Consumer', 'HocoNum', 'TechCode', 'MaxAdDown', 'MaxAdUp']]
gc.collect()
df.drop(['Consumer'],axis=1,inplace=True)

#Outer join to include blocks without any broadband access that aren't in the Form 477 data
df = df.merge(blockmaster, on="BlockCode", how="outer")
df.drop('pop',axis=1,inplace=True)
for col in ['HocoNum','TechCode','MaxAdDown','MaxAdUp']:
    df.loc[df[col].isnull(),col]=0
df['HocoNum']=df.HocoNum.astype(np.uint32)
df['TechCode']=df.TechCode.astype(np.uint8)
del blockmaster
gc.collect()

####Aggregating on the HocoNum and TechCod
# required to remove hoconum subsidiaries
df['max_download_speed']=df[['BlockCode','HocoNum','TechCode','MaxAdDown']].groupby(['BlockCode','HocoNum','TechCode']).transform(np.amax)
df.drop(['MaxAdDown'],axis=1,inplace=True)
gc.collect()
df['max_upload_speed']=df[['BlockCode','HocoNum','TechCode','MaxAdUp']].groupby(['BlockCode','HocoNum','TechCode']).transform(np.amax)
df.drop(['MaxAdUp'],axis=1,inplace=True)
gc.collect()
df.drop_duplicates(subset=['BlockCode','HocoNum','TechCode'],inplace=True)
gc.collect()

#Create index on block FIPS
df.set_index('BlockCode',inplace=True)

#Define technology codes for each technology type
tech_dict={}
tech_dict['a'] = [10,11,12,13]   # ADSL: ADSL2 (11), VDSL (12), other DSL (10)
tech_dict['c'] = [40,41,42,43]   # cable: DOCSIS 3.0 (42), DOCSIS 1, 1.1, 2.0 (41), other DOCSIS (40)
tech_dict['f'] = [50]            # FTTP
tech_dict['o'] = [0,90,20,30]    # Other: SDSL (20), Other copper (30), EPL (90), All other (0)
tech_dict['s'] = [60]            # Satellite
tech_dict['w'] = [70]            # fixed Wireless -- NOT MOBILE
techlist=np.array(['a','c','f','o','s','w'])

#Define speed combos that we want to iterate over
u_val_arr = np.array([0.2,1,1,3,10,25,100])
d_val_arr = np.array([0.2,4,10,25,100,250,1000])

#Iterating over the speed combos
for i in range(len(u_val_arr)-1,-1,-1):
    up_speed=u_val_arr[i]
    down_speed=d_val_arr[i]
    print(up_speed,down_speed)
    if up_speed>=1.:
        write_str=out_dir_tmp+'block_numprov_'+str(int(down_speed))+"_"+str(int(up_speed))+".csv"
    else:
        write_str=out_dir_tmp+'block_numprov_200.csv'
    time1=time.time()

    #Create a dataframe with the full set of fips_blocks to be merged later
    df_return=df[['HocoNum']].groupby(df.index).count()
    
    #Iterating through all possible combinations of technology codes
    for k in range(1,64):
        #cast k to a binary value, which can be used as an index on techlist
        techlist_bool=np.array(list("{0:06b}".format(k)))=='1'
        techlist_i=techlist[techlist_bool]
        colname=''.join(list(techlist_i))
        techcodes_i=[]
        for item in techlist_i:
            techcodes_i+=tech_dict[item]
        techcodes_i=np.array(techcodes_i)
        
        #Reducing the problem to only those rows which meet the required upload/download speeds and techcodes
        df['criteria_bool']=(df.max_download_speed>=down_speed) & (df.max_upload_speed>=up_speed) & (df.TechCode.isin(techcodes_i))
        df_i=df[['HocoNum']].loc[df.criteria_bool]
        df_i=df_i.groupby(df_i.index).nunique()
        df_i=df_i.rename(columns={'HocoNum':colname})

        #Merging in with the full set of results
        df_return=df_return.merge(df_i,how='left',left_index=True,right_index=True)
        del df_i
        gc.collect()
        df_return.loc[df_return[colname].isnull(),colname]=0.
        df_return[colname]=df_return[colname].astype(np.uint8)

    #Cleaning up and writing to temporary file
    df_return.drop('HocoNum',axis=1,inplace=True)
    df_return.reset_index(inplace=True,drop=False)
    blockmaster = pd.read_csv(input_csvs_path+'blockmaster_dec2016.csv', usecols=['geoid10','h2only_undev'],dtype={'h2only_undev':np.uint8}).rename(columns={'geoid10':'BlockCode'})
    df_return=blockmaster.merge(df_return,on='BlockCode',how='right')
    del blockmaster
    df_return.to_csv(write_str,index=False)
    #del df_i
    del df_return
    gc.collect()
    print("Speed combo:",i,time.time()-time1)
del df
gc.collect()

    
################### FILE POST-PROCESSING ###################
#Collecting the files for which to replace zeros
files=glob.glob(out_dir_tmp+'*')
files_out=[i.replace(out_dir_tmp,out_dir) for i in files]

##Make some aesthetic changes to the dataframe
#Create a list of different tech combos
techlist=np.array(['a','c','f','o','s','w'])
techcombo_dtype={}
for k in range(1,64):
    #Cast k to a binary value, which can be used as an index on techlist
    techlist_bool=np.array(list("{0:06b}".format(k)))=='1'
    techlist_i=techlist[techlist_bool]
    colname=''.join(list(techlist_i))
    techcombo_dtype[colname]=np.uint8
#Iterate through files
for k,fn_i in enumerate(files):
    nprovs=pd.read_csv(fn_i,dtype=techcombo_dtype)
    speed_i=fn_i.split('/')[-1].split('.')[0].split('_')
    speed_i='_'.join(speed_i[2:])
    
    #Reordering the columns
    collist=list(nprovs.columns[1:])
    collist.sort()
    collist_new=[]
    for i in range(6,0,-1):
        collist_new+=[item for item in collist if len(item)==i]
    collist_new=['BlockCode','h2only_undev']+collist_new
    nprovs=nprovs[collist_new]
    gc.collect()
    
    #Adding the speeds to the column names
    rename_dict={}
    rename_dict['BlockCode']='geoid10'
    collist=list(nprovs.columns[2:])
    for item in collist:
        rename_dict[item]=item+'_'+speed_i
    nprovs=nprovs.rename(columns=rename_dict)
    gc.collect()
    
    #Adding in leading zero
    nprovs.sort_values('geoid10',inplace=True)
    nprovs['geoid10']=nprovs.geoid10.astype(str)
    nprovs['geoid10'] = nprovs['geoid10'].apply(lambda x: x.zfill(15))
    nprovs.to_csv(files_out[k],index=False)

#Iterating over the files
for fn_i in files_out:
    with open(fn_i,'r') as fn:
        output_orig=fn.readlines()
    #String replacement to remove zeros (must done twice, because adjacent ones won't be removed the first time)
    out_red=[i.replace(',0,',',,').replace(',0\n',',\n') for i in output_orig]
    out_red=[i.replace(',0,',',,').replace(',0\n',',\n') for i in out_red]

    #Writing result to new file
    out_str=fn_i
    os.remove(fn_i)
    print(out_str)
    with open(out_str,'w') as fn:
        fn.writelines(out_red)
    del output_orig
    del out_red
    gc.collect()

##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step2_block_numprov.py took: '+str(round(running_time/60,2))+' minutes.')