# Python/Pandas script to create the provider table used on the NBM2 application's Provider Detail page
# Date: December 20, 2017

import pandas as pd
import string
import numpy as np
import time
import gc
import json


# the strat variable is used to calculate the script running time
starting_time = time.clock()

# load parent_config.json needed params
with open('./parent_config.json') as f:
    conf = json.load(f)

input_csvs_path = conf['input_csvs_path']
output_csvs_path = conf['output_csvs_path']


################### DEPENDENCIES ###################
# DATA:  RAW FORM 477, BLOCKMASTER
# SCRIPTS:  NONE 
####################################################

################### LOAD INPUT CSV FILES AND DEFINE OUTPUT ###################
#Load Form 477 data
df = pd.read_csv(input_csvs_path+"fbd_us_with_satellite_jun2016_v1.csv", usecols=['Census Block FIPS Code', 'Consumer', 'Holding Company Number', 'Technology Code', 'Max Advertised Downstream Speed (mbps)', 'Max Advertised Upstream Speed (mbps)'], dtype={"Census Block FIPS Code":'object'})
#Rename columns using the commented code below should any of the column names change
df=df.rename(columns = {'Census Block FIPS Code':'BlockCode','Consumer':'Consumer','Holding Company Number':'HocoNum','Technology Code':'TechCode','Max Advertised Downstream Speed (mbps)':'MaxAdDown','Max Advertised Upstream Speed (mbps)':'MaxAdUp'})

#Load Blockmaster data
blockmaster = pd.read_csv(input_csvs_path+'blockmaster_dec2016.csv', usecols=['geoid10','pop'], dtype={"geoid10":'object'}).rename(columns={'geoid10':'BlockCode'})

# Define Output file name
output_fn = output_csvs_path+'provider_table.csv'
###############################################################################

#Keep Form 477 records where consumer = 1 
df = df.loc[df.Consumer == 1, ['BlockCode', 'Consumer', 'HocoNum', 'TechCode', 'MaxAdDown', 'MaxAdUp']]
gc.collect()
df.drop(['Consumer'],axis=1,inplace=True)
#Merge Form 477 and Blockmaster table on BlockCode
merged_df = df.merge(blockmaster, on="BlockCode", how="left")
del df
del blockmaster
gc.collect()
print('data loaded and merged')

#### Aggregate on hoconum and transtech, finding max download speed and max upload speed
merged_df['max_download_speed']=merged_df[['BlockCode','HocoNum','TechCode','MaxAdDown']].groupby(['BlockCode','HocoNum','TechCode']).transform(np.amax)
merged_df.drop(['MaxAdDown'],axis=1,inplace=True)
gc.collect()
merged_df['max_upload_speed']=merged_df[['BlockCode','HocoNum','TechCode','MaxAdUp']].groupby(['BlockCode','HocoNum','TechCode']).transform(np.amax)
merged_df.drop(['MaxAdUp'],axis=1,inplace=True)
gc.collect()
merged_df.drop_duplicates(subset=['BlockCode','HocoNum','TechCode'],inplace=True)
gc.collect()

#Setting lists for download and upload speed tiers
u_column_list = ['u_1', 'u_2', 'u_3', 'u_4', 'u_5', 'u_6', 'u_7', 'u_8', 'u_9']
u_val_arr = np.array([0.2,1,3,10,25,100,250,500,1000])
d_column_list = ['d_1', 'd_2', 'd_3', 'd_4', 'd_5', 'd_6', 'd_7', 'd_8']
d_val_arr = np.array([0.2,4,10,25,100,250,500,1000]) 

####Calculate the population above the relevant download speeds for a given hoconum & transtech combination
#Prints download speed and population into matrices in order to vectorize comparision and summation
#Population is multiplied by the boolean (max_download_speed >= download_speed_threshold) then summed over all block FIPS
#for a given hoconum and transtech
def dspeeds_vectorized(dfgroup):
    pop_mat=np.array(dfgroup['pop'].repeat(len(d_val_arr))).reshape((len(dfgroup),len(d_val_arr)))
    speed_mat=np.array(dfgroup.max_download_speed.repeat(len(d_val_arr))).reshape((len(dfgroup),len(d_val_arr)))
    return pd.Series(list(np.sum(np.multiply(speed_mat>=d_val_arr,pop_mat),axis=0)),index=d_column_list)
def uspeeds_vectorized(dfgroup):
    pop_mat=np.array(dfgroup['pop'].repeat(len(u_val_arr))).reshape((len(dfgroup),len(u_val_arr)))
    speed_mat=np.array(dfgroup.max_upload_speed.repeat(len(u_val_arr))).reshape((len(dfgroup),len(u_val_arr)))
    return pd.Series(list(np.sum(np.multiply(speed_mat>=u_val_arr,pop_mat),axis=0)),index=u_column_list)

df_hocotrans=merged_df[['HocoNum','TechCode','pop','max_download_speed']].groupby(['HocoNum','TechCode']).apply(dspeeds_vectorized)
df_i=merged_df[['HocoNum','TechCode','pop','max_upload_speed']].groupby(['HocoNum','TechCode']).apply(uspeeds_vectorized)
df_hocotrans=df_hocotrans.merge(df_i,left_index=True,right_index=True)

###calculating the categoricals##############
def aggregate_tech_collection(techlist,code_string):
    ####Aggregating on hoconum for a category of techcodes
    df_i=merged_df.loc[merged_df.TechCode.isin(techlist)]
    df_i['max_download_speed']=df_i[['BlockCode','HocoNum','max_download_speed']].groupby(['BlockCode','HocoNum']).transform(np.amax)
    gc.collect()
    df_i['max_upload_speed']=df_i[['BlockCode','HocoNum','max_upload_speed']].groupby(['BlockCode','HocoNum']).transform(np.amax)
    gc.collect()
    df_i.drop_duplicates(subset=['BlockCode','HocoNum'],inplace=True)
    df_i.drop(['BlockCode','TechCode'],axis=1,inplace=True)
    gc.collect()

    #Calculate the population above a given download/upload speed for a given hoconum
    df_down=df_i[['HocoNum','pop','max_download_speed']].groupby(['HocoNum']).apply(dspeeds_vectorized)
    df_up=df_i[['HocoNum','pop','max_upload_speed']].groupby(['HocoNum']).apply(uspeeds_vectorized)
    df_i=df_down.merge(df_up,left_index=True,right_index=True)
    gc.collect()

    #Create a column with transtech = 'all'
    df_i['TechCode'] = code_string

    #Reset the index for the two dataframes 
    df_i = df_i.reset_index(drop=False)
    return df_i

#Calculating aggregates for three separate tech categories: adsl,cable,other
df_adsl=aggregate_tech_collection([10,11,12,13],'adsl')
gc.collect()
df_cable=aggregate_tech_collection([40,41,42,43],'cable')
gc.collect()
df_other=aggregate_tech_collection([0,20,30,90],'other')
gc.collect()


####Aggregating on hoconum
merged_df['max_download_speed']=merged_df[['BlockCode','HocoNum','max_download_speed']].groupby(['BlockCode','HocoNum']).transform(np.amax)
gc.collect()
merged_df['max_upload_speed']=merged_df[['BlockCode','HocoNum','max_upload_speed']].groupby(['BlockCode','HocoNum']).transform(np.amax)
gc.collect()
merged_df.drop_duplicates(subset=['BlockCode','HocoNum'],inplace=True)
merged_df.drop(['BlockCode','TechCode'],axis=1,inplace=True)
gc.collect()

#Calculate the population above a given download/upload speed for a given hoconum
df_hoco=merged_df[['HocoNum','pop','max_download_speed']].groupby(['HocoNum']).apply(dspeeds_vectorized)
df_i=merged_df[['HocoNum','pop','max_upload_speed']].groupby(['HocoNum']).apply(uspeeds_vectorized)
df_hoco=df_hoco.merge(df_i,left_index=True,right_index=True)

#Create a column with transtech = 'all'
df_hoco['TechCode'] = "all"

#Reset the index for the two dataframes 
df_hoco = df_hoco.reset_index(drop=False)
df_hocotrans = df_hocotrans.reset_index(drop=False)

#Merge the two dataframes 
Dataframes = [df_hoco,df_adsl,df_cable,df_other, df_hocotrans]
merged_df = pd.concat(Dataframes)
merged_df.reset_index(drop=True,inplace=True)
gc.collect()

#Rename column "transtech" to "tech"
merged_df=merged_df.rename(columns = {'TechCode':'tech','HocoNum':'hoconum'})

#Save the dataframe into out_tablename csv
merged_df[['hoconum','tech','d_1', 'd_2', 'd_3', 'd_4', 'd_5', 'd_6', 'd_7', 
                                            'd_8', 'u_1', 'u_2', 'u_3', 'u_4', 'u_5', 'u_6', 
                                            'u_7', 'u_8', 'u_9']].to_csv(output_fn,index=False)


##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step1_f477_to_provider_table.py took: '+str(round(running_time/60,2))+' minutes.')