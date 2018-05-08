#!/bin/bash

# Step 1
##### Speed 200
printf "\nStarting speed 200\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_200.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_200.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_200.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_200.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_200.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_200.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_200.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_200.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_200.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_200.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_200.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_200 -x geoid10 -f -o mbtiles/county_200.mbtiles 2>&1 | tee log/county_200.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_200.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_200 -x tract_id -f -o mbtiles/tract_z5_200.mbtiles 2>&1 | tee log/tract_z5_200.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_200.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_200 -x tract_id -f -o mbtiles/tract_z6_8_200.mbtiles 2>&1 | tee log/tract_z6_8_200.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_200.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_200 -x tract_id -f -o mbtiles/tract_z9_200.mbtiles 2>&1 | tee log/tract_z9_200.log
gzip -dc geojsons/big_tract_blocks_200.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_200 -x geoid10 -f -o mbtiles/block_z9_200.mbtiles 2>&1 | tee log/block_z9_200.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_200.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_200 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_200.mbtiles 2>&1 | tee log/block_z10_200.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_200.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_200 -f -o mbtiles/block_z11_14_200.mbtiles 2>&1 | tee log/block_z11_14_200.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_200 -o mbtiles/dec2016_7nov17_200.mbtiles -f mbtiles/county_200.mbtiles mbtiles/tract_z5_200.mbtiles mbtiles/tract_z6_8_200.mbtiles mbtiles/tract_z9_200.mbtiles mbtiles/block_z9_200.mbtiles mbtiles/block_z10_200.mbtiles mbtiles/block_z11_14_200.mbtiles


##### Speed 10

printf "\nStarting speed 10\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_10_1.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_10.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_10_1.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_10.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_10_1.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_10.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_10_1.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_10.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_10_1.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_10.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_10.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_10 -x geoid10 -f -o mbtiles/county_10.mbtiles 2>&1 | tee log/county_10.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_10.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_10 -x tract_id -f -o mbtiles/tract_z5_10.mbtiles 2>&1 | tee log/tract_z5_10.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_10.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_10 -x tract_id -f -o mbtiles/tract_z6_8_10.mbtiles 2>&1 | tee log/tract_z6_8_10.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_10.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_10 -x tract_id -f -o mbtiles/tract_z9_10.mbtiles 2>&1 | tee log/tract_z9_10.log
gzip -dc geojsons/big_tract_blocks_10.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_10 -x geoid10 -f -o mbtiles/block_z9_10.mbtiles 2>&1 | tee log/block_z9_10.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_10.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_10 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_10.mbtiles 2>&1 | tee log/block_z10_10.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_10.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_10 -f -o mbtiles/block_z11_14_10.mbtiles 2>&1 | tee log/block_z11_14_10.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_10 -o mbtiles/dec2016_7nov17_10.mbtiles -f mbtiles/county_10.mbtiles mbtiles/tract_z5_10.mbtiles mbtiles/tract_z6_8_10.mbtiles mbtiles/tract_z9_10.mbtiles mbtiles/block_z9_10.mbtiles mbtiles/block_z10_10.mbtiles mbtiles/block_z11_14_10.mbtiles


##### Speed 25

printf "\nStarting speed 25\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_25_3.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_25.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_25_3.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_25.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_25_3.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_25.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_25_3.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_25.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_25_3.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_25.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_25.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_25 -x geoid10 -f -o mbtiles/county_25.mbtiles 2>&1 | tee log/county_25.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_25.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_25 -x tract_id -f -o mbtiles/tract_z5_25.mbtiles 2>&1 | tee log/tract_z5_25.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_25.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_25 -x tract_id -f -o mbtiles/tract_z6_8_25.mbtiles 2>&1 | tee log/tract_z6_8_25.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_25.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_25 -x tract_id -f -o mbtiles/tract_z9_25.mbtiles 2>&1 | tee log/tract_z9_25.log
gzip -dc geojsons/big_tract_blocks_25.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_25 -x geoid10 -f -o mbtiles/block_z9_25.mbtiles 2>&1 | tee log/block_z9_25.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_25.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_25 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_25.mbtiles 2>&1 | tee log/block_z10_25.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_25.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_25 -f -o mbtiles/block_z11_14_25.mbtiles 2>&1 | tee log/block_z11_14_25.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_25 -o mbtiles/dec2016_7nov17_25.mbtiles -f mbtiles/county_25.mbtiles mbtiles/tract_z5_25.mbtiles mbtiles/tract_z6_8_25.mbtiles mbtiles/tract_z9_25.mbtiles mbtiles/block_z9_25.mbtiles mbtiles/block_z10_25.mbtiles mbtiles/block_z11_14_25.mbtiles


##### Speed 100

printf "\nStarting speed 100\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_100_10.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_100.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_100_10.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_100.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_100_10.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_100.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_100_10.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_100.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_100_10.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_100.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_100.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_100 -x geoid10 -f -o mbtiles/county_100.mbtiles 2>&1 | tee log/county_100.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_100.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_100 -x tract_id -f -o mbtiles/tract_z5_100.mbtiles 2>&1 | tee log/tract_z5_100.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_100.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_100 -x tract_id -f -o mbtiles/tract_z6_8_100.mbtiles 2>&1 | tee log/tract_z6_8_100.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_100.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_100 -x tract_id -f -o mbtiles/tract_z9_100.mbtiles 2>&1 | tee log/tract_z9_100.log
gzip -dc geojsons/big_tract_blocks_100.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_100 -x geoid10 -f -o mbtiles/block_z9_100.mbtiles 2>&1 | tee log/block_z9_100.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_100.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_100 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_100.mbtiles 2>&1 | tee log/block_z10_100.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_100.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_100 -f -o mbtiles/block_z11_14_100.mbtiles 2>&1 | tee log/block_z11_14_100.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_100 -o mbtiles/dec2016_7nov17_100.mbtiles -f mbtiles/county_100.mbtiles mbtiles/tract_z5_100.mbtiles mbtiles/tract_z6_8_100.mbtiles mbtiles/tract_z9_100.mbtiles mbtiles/block_z9_100.mbtiles mbtiles/block_z10_100.mbtiles mbtiles/block_z11_14_100.mbtiles

##### Speed 250

printf "\nStarting speed 250\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_250_25.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_250.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_250_25.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_250.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_250_25.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_250.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_250_25.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_250.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_250_25.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_250.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_250.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_250 -x geoid10 -f -o mbtiles/county_250.mbtiles 2>&1 | tee log/county_250.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_250.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_250 -x tract_id -f -o mbtiles/tract_z5_250.mbtiles 2>&1 | tee log/tract_z5_250.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_250.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_250 -x tract_id -f -o mbtiles/tract_z6_8_250.mbtiles 2>&1 | tee log/tract_z6_8_250.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_250.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_250 -x tract_id -f -o mbtiles/tract_z9_250.mbtiles 2>&1 | tee log/tract_z9_250.log
gzip -dc geojsons/big_tract_blocks_250.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_250 -x geoid10 -f -o mbtiles/block_z9_250.mbtiles 2>&1 | tee log/block_z9_250.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_250.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_250 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_250.mbtiles 2>&1 | tee log/block_z10_250.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_250.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_250 -f -o mbtiles/block_z11_14_250.mbtiles 2>&1 | tee log/block_z11_14_250.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_250 -o mbtiles/dec2016_7nov17_250.mbtiles -f mbtiles/county_250.mbtiles mbtiles/tract_z5_250.mbtiles mbtiles/tract_z6_8_250.mbtiles mbtiles/tract_z9_250.mbtiles mbtiles/block_z9_250.mbtiles mbtiles/block_z10_250.mbtiles mbtiles/block_z11_14_250.mbtiles



##### Speed 4

printf "\nStarting speed 4\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_4_1.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_4.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_4_1.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_4.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_4_1.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_4.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_4_1.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_4.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_4_1.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_4.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_4.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_4 -x geoid10 -f -o mbtiles/county_4.mbtiles 2>&1 | tee log/county_4.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_4.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_4 -x tract_id -f -o mbtiles/tract_z5_4.mbtiles 2>&1 | tee log/tract_z5_4.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_4.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_4 -x tract_id -f -o mbtiles/tract_z6_8_4.mbtiles 2>&1 | tee log/tract_z6_8_4.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_4.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_4 -x tract_id -f -o mbtiles/tract_z9_4.mbtiles 2>&1 | tee log/tract_z9_4.log
gzip -dc geojsons/big_tract_blocks_4.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_4 -x geoid10 -f -o mbtiles/block_z9_4.mbtiles 2>&1 | tee log/block_z9_4.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_4.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_4 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_4.mbtiles 2>&1 | tee log/block_z10_4.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_4.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_4 -f -o mbtiles/block_z11_14_4.mbtiles 2>&1 | tee log/block_z11_14_4.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_4 -o mbtiles/dec2016_7nov17_4.mbtiles -f mbtiles/county_4.mbtiles mbtiles/tract_z5_4.mbtiles mbtiles/tract_z6_8_4.mbtiles mbtiles/tract_z9_4.mbtiles mbtiles/block_z9_4.mbtiles mbtiles/block_z10_4.mbtiles mbtiles/block_z11_14_4.mbtiles


##### Speed 1000

printf "\nStarting speed 1000\n"
printf "\nStarting join for county data (for zoom 0-4)\n"
time tippecanoe-json-tool -c csvs/county_numprov_sort_round_1000_100.csv geojsons/county_2010_500k_4326.sort.geojson | gzip > geojsons/counties_500k_1000.geojson.gz

printf "\nStarting join for tract data (for zoom 5-8)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_1000_100.csv geojsons/tract_2010_500k_4326.sort.geojson | gzip > geojsons/tracts_500k_1000.geojson.gz

printf "\nStarting join for small-tract data (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/tract_numprov_sort_round_1000_100.csv geojsons/notbig_tracts_5e8_2010_4326.sort.geojson | gzip > geojsons/tracts_1000.geojson.gz

printf "\nStarting join for block data in large tracts (for zoom 9)\n"
time tippecanoe-json-tool -c csvs/block_numprov_1000_100.csv geojsons/bigtract_blocks_5e8_2010_4326.sort.geojson | gzip > geojsons/big_tract_blocks_1000.geojson.gz

printf "\nStarting join for block data \n"
time tippecanoe-json-tool -c csvs/block_numprov_1000_100.csv geojsons/block_us.sort.geojson| gzip > geojsons/blocks_1000.geojson.gz

printf "\nStarting tiles for zoom 0-4 (counties)\n"
gzip -dc geojsons/counties_500k_1000.geojson.gz | time tippecanoe -P -Z 0 -z 4 --detect-shared-borders -l dec2016_7nov17_1000 -x geoid10 -f -o mbtiles/county_1000.mbtiles 2>&1 | tee log/county_1000.log
printf "\nStarting tiles for zoom 5 (tracts, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/tracts_500k_1000.geojson.gz | time tippecanoe -P -Z 5 -z 5 -S 8 --detect-shared-borders --coalesce --coalesce-smallest-as-needed -l dec2016_7nov17_1000 -x tract_id -f -o mbtiles/tract_z5_1000.mbtiles 2>&1 | tee log/tract_z5_1000.log
printf "\nStarting tiles for zoom 6-8 (tracts)\n"
gzip -dc geojsons/tracts_500k_1000.geojson.gz | time tippecanoe -P -Z 6 -z 8 --detect-shared-borders -l dec2016_7nov17_1000 -x tract_id -f -o mbtiles/tract_z6_8_1000.mbtiles 2>&1 | tee log/tract_z6_8_1000.log
printf "\nStarting tiles for zoom 9 (smaller tracts and blocks in big tracts)\n"
gzip -dc geojsons/tracts_1000.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_1000 -x tract_id -f -o mbtiles/tract_z9_1000.mbtiles 2>&1 | tee log/tract_z9_1000.log
gzip -dc geojsons/big_tract_blocks_1000.geojson.gz | time tippecanoe -P -Z 9 -z 9 --detect-shared-borders -l dec2016_7nov17_1000 -x geoid10 -f -o mbtiles/block_z9_1000.mbtiles 2>&1 | tee log/block_z9_1000.log
printf "\nStarting tiles for zoom 10 (blocks, with simplification and --coalesce and --coalesce-smallest-as-needed)\n"
gzip -dc geojsons/blocks_1000.geojson.gz | time tippecanoe -P -Z 10 -z 10 -S 8 	--detect-shared-borders -l dec2016_7nov17_1000 --coalesce --coalesce-smallest-as-needed -x geoid10 -f -o mbtiles/block_z10_1000.mbtiles 2>&1 | tee log/block_z10_1000.log
printf "\nStarting tiles for zoom 11+ (blocks, with higher detail at highest zoom via -d)\n"
gzip -dc geojsons/blocks_1000.geojson.gz | time tippecanoe -P -Z 11 -z 14 -d 14 	--detect-shared-borders -l dec2016_7nov17_1000 -f -o mbtiles/block_z11_14_1000.mbtiles 2>&1 | tee log/block_z11_14_1000.log

printf "\nStarting combine into one mbtiles file\n"
tile-join -n dec2016_7nov17_1000 -o mbtiles/dec2016_7nov17_1000.mbtiles -f mbtiles/county_1000.mbtiles mbtiles/tract_z5_1000.mbtiles mbtiles/tract_z6_8_1000.mbtiles mbtiles/tract_z9_1000.mbtiles mbtiles/block_z9_1000.mbtiles mbtiles/block_z10_1000.mbtiles mbtiles/block_z11_14_1000.mbtiles

# Step 2
gzip -dc geojsons/xl_blocks_2010.geojson.gz | tippecanoe -P -Z 5 -z 9 -d 14 -x min_zoom --detect-shared-borders -l xl_blocks_2010 -f -o mbtiles/xl_blocks_2010.mbtiles 2>&1 | tee log/xl_blocks_2010.log

# Step 3
tippecanoe -P -Z 0 -z 7 -S 8 -x county_fips --preserve-input-order --coalesce --detect-shared-borders -l dec2016_7nov17_prov_lg -f -o mbtiles/dec2016_7nov17_prov_lg_z0_7.mbtiles geojsons/dec2016_7nov17_prov_lg.geojson 2>&1 | tee log/prov_large_z7.log
tippecanoe -P -Z 8 -z 12 -x county_fips --preserve-input-order --coalesce -d 14 --detect-shared-borders -l dec2016_7nov17_prov_lg -f -o mbtiles/dec2016_7nov17_prov_lg_z8_12.mbtiles geojsons/dec2016_7nov17_prov_lg.geojson 2>&1 | tee log/prov_large.log
tile-join -n large_prov -o mbtiles/dec2016_7nov17_prov_lg.mbtiles -f mbtiles/dec2016_7nov17_prov_lg_z0_7.mbtiles mbtiles/dec2016_7nov17_prov_lg_z8_12.mbtiles

tippecanoe -P -Z 0 -z 8 -S 8 -x county_fips --preserve-input-order --coalesce --detect-shared-borders -l dec2016_7nov17_prov_other -f -o mbtiles/dec2016_7nov17_prov_other_z0_8.mbtiles geojsons/dec2016_7nov17_prov_other.geojson 2>&1 | tee log/prov_other_z7.log
tippecanoe -P -Z 9 -z 12 -x county_fips --preserve-input-order --coalesce -d 14 --detect-shared-borders -l dec2016_7nov17_prov_other -f -o mbtiles/dec2016_7nov17_prov_other_z9_12.mbtiles geojsons/dec2016_7nov17_prov_other.geojson 2>&1 | tee log/prov_other.log
tile-join -n other_prov -o mbtiles/dec2016_7nov17_prov_other.mbtiles -f mbtiles/dec2016_7nov17_prov_other_z0_8.mbtiles mbtiles/dec2016_7nov17_prov_other_z9_12.mbtiles


