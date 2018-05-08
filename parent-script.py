import os
import time


os.system('python ./step1_f477_to_provider_table.py')

os.system('python ./step2_block_numprov.py')

os.system('python ./step3_area_table.py')

os.system('python ./step4_preprocess_speeds.py')

os.system('python ./step5_tract_from_block_speeds.py')

os.system('python ./step6_county_from_block_speeds.py')

os.system('python ./step7_geog_mbtiles_gpandas.py')

os.system('python ./step8_create_geometry.py')

os.system('python ./step9_create_speed_mbtiles.py')

os.system('python ./step10_uploads_speeds.py')
