import pandas as pd
import json
import time

# the strat variable is used to calculate the script running time
starting_time = time.clock()

# load configurations from config.json
with open('./parent_config.json') as f:
    conf = json.load(f)


input_csvs_path = conf['input_csvs_path']
temp_csvs_path = conf['temp_csvs_path']
output_csvs_path = conf['output_csvs_path']

input_block_numprov_null_csvs = conf['input_block_numprov_null_csvs']
input_block_numprov_zeros_csvs = conf['input_block_numprov_zeros_csvs']
cols_lists_blocks = conf['cols_lists_blocks']
cols_dtypes_int8_blocks = conf['cols_dtypes_int8_blocks']

# the accumulate_cols_list is for appending the columns subsets
accumulate_cols_list = []
# remove nulls and save with float
for cl_i, cl_v in enumerate(cols_lists_blocks):
    for clv_i,clv_v in enumerate(cl_v):
        block_df = pd.read_csv(temp_csvs_path+'block_numprov_withnull/'+input_block_numprov_null_csvs[cl_i],usecols=clv_v,dtype={'geoid10':'object'})
        block_df.fillna(0, inplace=True)
        accumulate_cols_list.append(block_df)
        
    block_df = pd.concat(accumulate_cols_list,axis=1)
    accumulate_cols_list = []
    block_df.to_csv(temp_csvs_path+'block_numprov_with0/'+input_block_numprov_zeros_csvs[cl_i],index=False)
    print(str(input_block_numprov_zeros_csvs[cl_i]) + ' 0s removed')

block_df = None
accumulate_cols_list = []
# reload to save with int8 to save space
for cl_i, cl_v in enumerate(cols_lists_blocks):
    for clv_i,clv_v in enumerate(cl_v):
        block_df = pd.read_csv(temp_csvs_path+'block_numprov_with0/'+input_block_numprov_zeros_csvs[cl_i],usecols=clv_v,dtype=cols_dtypes_int8_blocks[cl_i][clv_i])
        accumulate_cols_list.append(block_df)
        
    block_df = pd.concat(accumulate_cols_list,axis=1)
    accumulate_cols_list = []
    block_df.to_csv(temp_csvs_path+'block_numprov_with0/'+input_block_numprov_zeros_csvs[cl_i],index=False)
    print(str(input_block_numprov_zeros_csvs[cl_i]) + ' floats replaced with integers')


##############################################
# outputing the time it took the script to run
##############################################
running_time = time.clock() - starting_time
print('step4_preprocess_speeds.py took: '+str(round(running_time/60,2))+' minutes.')