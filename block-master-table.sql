---------------------------------------------------------------------------
---------------------------------------------------------------------------
---- CREATES CENSUS BLOCK MASTER LOOKUP AND NAMES TABLES
---- DATE:  DECEMBER 7, 2017
---- AUTHOR:  NCI, INC 
---------------------------------------------------------------------------
---------------------------------------------------------------------------

---------------------------------------
---------- PRE-REQUISITES -------------
---------------------------------------
-- (1) LOAD THE FOLLOWING SHAPEFILES FROM CENSUS (INTO "NBM2" SCHEMA).  ** CREATE INDEXES ON "GEOM" COLUMN
-- >> CENSUS BLOCKS:  nbm2.nbm2_block2010
-- >> STATES:  nbm2.nbm2_state2016
-- >> COUNTIES:  nbm2.nbm2_county2016 URL: https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2016&layergroup=Counties+%28and+equivalent%29
-- >> CBSAs:  nbm2.nbm2_cbsa2016
-- >> CENSUS PLACES:  nbm2.nbm2_place2016
-- >> TRIBAL AREAS:  nbm2.nbm2_tribe2016
-- >> CONGRESSIONAL DISTRICTS:  nbm2_cd115_2016
-- (2) LOAD THE FOLLOWING REFERENCE DATA (INTO "NBM2" SCHEMA): POP/HU/HH DATA, BLOCKMASTER STATIC, COUNTY TO CBSA LOOKUP 
-- >> TABLE DEFINITIONS FOUND BELOW
-- (3) SEARCH THIS CODE FOR THE WORD "CHANGE" (WHICH WILL TELL YOU WHERE TO UPDATE THE TABLE AND COLUMN NAMES BASED ON WHAT WAS LOADED IN PRE-REQ #1 AND #2)

-- NOTES:
-- We’re only doing a Census block overlay for Congressional Districts, Census Places, and Tribal Areas (we don’t need to do the others because State FIPS = first 2 chararacters of block_fips; County FIPS = first 5 characters of block_fips; and counties map perfectly to CBSAs)
-- Although they’re not used in the Census Block overlay, we still need to load the shapefiles for all the geography types (including States, Counties and CBSAs) so that we can get the geography names for those geographies in the “nbm2.blockmaster2017_names” table

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
---- MAKE SURE LOADED SHAPEFILES HAVE INDEXES CREATED ON "GEOM" COLUMN
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--## Create indexes on Census Block table
CREATE INDEX ON nbm2.nbm2_block2010 (block_fips); commit; 
CREATE INDEX ON nbm2.nbm2_block2010 (county_fips); commit; 

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
---- LOAD REFERENCE CSV FILES REQUIRED FOR THE FINAL BLOCK MASTER TABLE
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- county_to_cbsa_lookup.csv comes from the most recent Excel at the following URL, with the header and footer rows removed, and saved as CSV: https://www.census.gov/geographies/reference-files/time-series/demo/metro-micro/delineation-files.html (Census > Metropolitan and Micropolitan > Geographies > Reference Files > Delineation Files)

------------------------------------------------------------------------------------------------------------------------------------------------
-------- LOAD POP/HU/HH DATA
-------- DESCRIPTION:  This CSV (from FCC) provides us with the population, housing units (HU), and households (HH) for each census block
-------- NOTE:  The table definition below may need to change if additional years are added
------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS nbm2.us_pop_hu_hh; commit; 
CREATE TABLE nbm2.us_pop_hu_hh
(
  stateabbr character(2),
  block_fips character(15),
  hu2010 numeric,
  hu2011 numeric,
  hu2012 numeric,
  hu2013 numeric,
  hu2014 numeric,
  hu2015 numeric,
  hu2016 numeric,
  pop2010 numeric,
  pop2011 numeric,
  pop2012 numeric,
  pop2013 numeric,
  pop2014 numeric,
  pop2015 numeric,
  pop2016 numeric,
  hh2010 numeric,
  hh2011 numeric,
  hh2012 numeric,
  hh2013 numeric,
  hh2014 numeric,
  hh2015 numeric,
  hh2016 numeric
); commit; 

\copy nbm2.us_pop_hu_hh from '/FOLDER LOCATION/us2016.csv' delimiter ',' csv header; commit;  /*CHANGE DIRECTORY PATH*/

create index on nbm2.us_pop_hu_hh (block_fips); commit; 

--------------------------------------------------------------------------------------------------------------------------------------
-------- LOAD "BLOCKMASTER STATIC" DATA
-------- DESCRIPTION:  This CSV provides us with the urban_rural (U/R) designation and tribal_nontribal (T/N) for each census block
--------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS nbm2.blockmaster_static; commit; 
create table nbm2.blockmaster_static
(
geoid10 character(15),
stateabbr character(2),
state_fips character(2),
urban_rural character(1),
tribal_non character(1)
); commit; 

\copy nbm2.blockmaster_static from '/FOLDER LOCATION/blockmaster_static.csv' delimiter ',' csv header; commit;  /*CHANGE DIRECTORY PATH*/

create index on nbm2.blockmaster_static (geoid10); commit; 

--------------------------------------------------------------------------------------------------------------------------------------
-------- LOAD "COUNTY TO CORE-BASED STATISTICAL AREA (CBSA) LOOKUP"
-------- DESCRIPTION:  CBSAs are made up of counties.  This CSV provides the counties which comprise each CBSA. 
-------- URL:  https://www.census.gov/geographies/reference-files/time-series/demo/metro-micro/delineation-files.html 
--------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS nbm2.county_to_cbsa_lookup; commit; 
create table nbm2.county_to_cbsa_lookup
(
cbsa_code varchar(5),
metropolitan_division_code varchar(100),
csa_code integer,
cbsa_title varchar(150),
metro_micro_statistical_area varchar(100),
metropolitan_division_title varchar(100),
csa_title varchar(150),
county_county_equivalent varchar(100),
state_name varchar(100),
fips_state_code	character(2),
fips_county_code varchar(3),
central_outlying_county varchar(50)
); commit;

\copy nbm2.county_to_cbsa_lookup from '/FOLDER LOCATION/county_to_cbsa_lookup.csv' delimiter ',' csv header encoding 'LATIN1'; commit;  /*CHANGE DIRECTORY PATH*/

-- ## Concatenate the State FIPS code and County FIPS code to form a 5 character county FIPS
alter table nbm2.county_to_cbsa_lookup add column county_fips character(5); commit; 
update nbm2.county_to_cbsa_lookup set county_fips = (fips_state_code || (case when length(fips_county_code) = 1 then ('00' || fips_county_code) when length(fips_county_code) = 2 then ('0' || fips_county_code) else fips_county_code end)); commit; 


create index on nbm2.county_to_cbsa_lookup (county_fips); commit; 


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
---- PERFORM A SPATIAL INTERSECTION TO ASSIGN CENSUS BLOCK TO A TRIBAL AREA, CENSUS PLACE, AND CONGRESSIONAL DISTRICT
---- ALSO, PERFORM OVERLAY FOR THE COUNTY GEOLGRAPHY (FOR CERTAIN STATES)
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
---- ######## CENSUS BLOCK ASSIGNMENT METHODOLOGY ########
---- ###### TRIBAL LAND AND CENSUS PLACE
---- ## AREA INTERSECTION METHODOLOGY:  (1) INTERSECT CENSUS BLOCKS WITH GEOGRAPHIES, (2) CALCULATE AREA OF INTERSECTION(S), (3) KEEP MAXIMUM INTERSECTED AREA FOR EACH BLOCK, (4) IF MAX INTERSECTED AREA > NON ITERSECTED AREA (i.e. AREA THAT DOES NOT INTERSECT ANY GEOGRAPHY) THEN ASSIGN, OTHERWISE NULL
---- ## EXAMPLE 1:  55% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE X, 45% DOES NOT INTERSECT ANY CENSUS PLACE.  RESULT:  ASSIGN CENUS BLOCK A TO CENSUS PLACE X
---- ## EXAMPLE 2:  25% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE X, 20% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE Y, 15% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE Z, 40% DOES NOT INTERSECT ANY CENSUS PLACE.  RESULT:  DO NOT ASSIGN CENSUS BLOCK A (BECAUSE 25% IS NOT GREATER THAN 40%)
---- ## EXAMPLE 3:  35% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE X, 25% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE Y, 10% OF CENSUS BLOCK A'S AREA INTERSECTS CENSUS PLACE Z, 30% DOES NOT INTERSECT ANY CENSUS PLACE.  RESULT:  ASSIGN CENSUS BLOCK A TO CENSUS PLACE X (BECAUSE 35% > 30%)

---- ###### COUNTY AND CONGRESSIONAL DISTRICT
---- ## SINCE EVERY CENSUS BLOCK MUST BELONG TO A COUNTY AND CONGRESSIONAL DISTRICT, FOR THOSE TO GEOGRAPHY TYPES WE SIMPLY ASSIGN BASED ON GREATEST AREA

-------------------------------------
-------- TRIBAL BLOCK OVERLAY
-------------------------------------
drop table if exists nbm2.tribal_block_overlay_stg; commit; 
create table nbm2.tribal_block_overlay_stg
(
block_fips varchar(15),
tribal_id varchar(5),
aianhhcc varchar(2),
area numeric,
geom geometry(multipolygon, 4326)
); commit; 

---------------------------------------------------------------------------------------------------------
-- Description:  Performs a spatial intersect of each Tribal geography with the census block geography 
---------------------------------------------------------------------------------------------------------
do $$
DECLARE
        s character varying;   
        arr_split_data  text[];
begin

select into arr_split_data regexp_split_to_array('01,02,04,05,06,08,09,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56,60,66,69,72,78',','); --## Loop through the census blocks in each state
foreach s in ARRAY arr_split_data loop
    for r in (select min(gid) from nbm2.nbm2_tribe2016)..(select max(gid) from nbm2.nbm2_tribe2016) loop  --## Loop through each Tribal geography (gid)
    
    insert into nbm2.tribal_block_overlay_stg
    select block_fips, geoid as tribal_id, classfp as aianhhcc,
    (case when st_within(a.geom, b.geom) then st_area(a.geom::geography) else NULL end) as area,  --## If a census block falls completely within a Tribal geography, calculate its entire area (in square meters), or else keep area blank
    (case when st_within(a.geom, b.geom) then a.geom else st_multi(st_buffer(st_intersection(a.geom, b.geom), 0.0)) end) as geom  --## If a census block falls completely within a Tribal geography, keep its entire geometry, otherwise keep the portion of the census block that falls inside the Tribal geography
    from nbm2.nbm2_block2010 a, nbm2.nbm2_tribe2016 b       /*CHANGE TABLE NAMES HERE*/
    where st_intersects(a.geom, b.geom) and substr(block_fips, 1, 2) = s and b.gid = r;  --## To take advantage of spatial index, only consider those census blocks that intersect a Tribal area

   end loop;
end loop;
end;
$$; commit; 

update nbm2.tribal_block_overlay_stg set area = st_area(geom::geography) where area IS NULL; commit; --## In cases where a portion of a census block fell inside a Tribal geography (which we left blank above), calculate its area (in square meters)

----------------------------------------------------------------------------------------------------------------------------------------
-- Description:  Uses the data from the spatial intersect above to assign blocks to a single Tribal area (based on area business rule)
----------------------------------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.tribal_block_overlay; commit; 
create table nbm2.tribal_block_overlay
(
block_fips varchar(15),
tribal_id varchar(5),
aianhhcc varchar(2),
area_pct numeric
); commit; 

insert into nbm2.tribal_block_overlay
select a.block_fips, a.tribal_id, a.aianhhcc, round((a.area/c.area)::numeric, 4) as area_pct
from 
( 
--## For each census block, rank the amount of area in the intersection (for example: If cblock A intersects 10,000 sq. meters and 15,000 sq. meters, of Tribal area A and B, respectively. Result:  Tribal Area B rank = 1 and Tribal Area A rank = 2) 
   select block_fips, tribal_id, aianhhcc, area, row_number() OVER (PARTITION BY block_fips order by area desc) as row_numb --## Consider only 
   from nbm2.tribal_block_overlay_stg 
   where area >= 1  --## Consider only intersections where at least 1 sq. meter of a census block intersected the Tribal area
) a
left join
(
--## For each census block, find total areathat falls within any Tribal area
   select block_fips, sum(area) as total_area_intersect
   from nbm2.tribal_block_overlay_stg  /*CHANGE TABLE NAME HERE*/
   group by block_fips
) b
on a.block_fips = b.block_fips
left join
(
--## Find the total area of each census block
   select block_fips, st_area(geom::geography) as area
   from nbm2.nbm2_block2010  /*CHANGE TABLE NAME HERE*/
) c
on a.block_fips = c.block_fips
where row_numb = 1 --## For each census block, keep the Tribal area where most of its area lies
and (a.area > (c.area - total_area_intersect)); commit;   --## Perform area check:  If census block's maximum area (rank = 1) is greater than area that does not fall inside any Tribal area, then assign to that Tribal area.  Otherwise do not assign.  


create index on nbm2.tribal_block_overlay (block_fips); commit; 


--------------------------------
-------- CENSUS PLACE OVERLAY
--------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- Description:  This part of the code performs a spatial intersect of each Census Place geography with the census block geography 
----------------------------------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.cplace_block_overlay_stg; commit; 
create table nbm2.cplace_block_overlay_stg
(
block_fips varchar(15),
cplace_id varchar(7),
area numeric,
geom geometry(multipolygon, 4326)
); commit; 


do $$
DECLARE
        s character varying;   
        arr_split_data  text[];
begin

select into arr_split_data regexp_split_to_array('01,02,04,05,06,08,09,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56,60,66,69,72,78',',');  --## Loop through the census blocks in each state
foreach s in ARRAY arr_split_data loop
    
    insert into nbm2.cplace_block_overlay_stg
    select block_fips, geoid as cplace_id,
    (case when st_within(a.geom, b.geom) then st_area(a.geom::geography) else NULL end) as area,  --## If a census block falls completely within a Census Place geography, calculate its entire area (in square meters), or else keep area blank
    (case when st_within(a.geom, b.geom) then a.geom else st_multi(st_buffer(st_intersection(a.geom, b.geom), 0.0)) end) as geom  --## If a census block falls completely within a Census Place geography, keep its entire geometry, otherwise keep the portion of the census block that falls inside the Census Place geography
    from nbm2.nbm2_block2010 a, nbm2.nbm2_place2016 b   /*CHANGE TABLE NAMES HERE*/
    where st_intersects(a.geom, b.geom) and substr(block_fips, 1, 2) = s and b.statefp = s;  --## To take advantage of spatial index, only consider those census blocks that intersect a Census Place area

end loop;
end;
$$; commit; 

update nbm2.cplace_block_overlay_stg set area = st_area(geom::geography) where area IS NULL; commit;  --## In cases where a portion of a census block fell inside a Census Place geography (which we left blank above), calculate its area (in square meters) 


----------------------------------------------------------------------------------------------------------------------------------------
-- Description:  Uses the data from the spatial intersect above to assign blocks to a single Census Place (based on area business rule)
----------------------------------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.cplace_block_overlay; commit; 
create table nbm2.cplace_block_overlay
(
block_fips varchar(15),
cplace_id varchar(7),
area_pct numeric
); commit; 

insert into nbm2.cplace_block_overlay
select a.block_fips, a.cplace_id, round((a.area/c.area)::numeric, 4) as area_pct
from 
( 
--## For each census block, rank the amount of area in the intersection (for example: If cblock A intersects 10,000 sq. meters and 15,000 sq. meters, of Census Place area A and B, respectively. Result:  Census Place Area B rank = 1 and Census Place Area A rank = 2) 
   select block_fips, cplace_id, area, row_number() OVER (PARTITION BY block_fips order by area desc) as row_numb --## Consider only 
   from nbm2.cplace_block_overlay_stg 
   where area >= 1  --## Consider only intersections where at least 1 sq. meter of a census block intersected the Census Place area
) a
left join
(
--## For each census block, find total areathat falls within any Census Place area
   select block_fips, sum(area) as total_area_intersect
   from nbm2.cplace_block_overlay_stg  /*CHANGE TABLE NAME HERE*/
   group by block_fips
) b
on a.block_fips = b.block_fips
left join
(
--## Find the total area of each census block
   select block_fips, st_area(geom::geography) as area
   from nbm2.nbm2_block2010  /*CHANGE TABLE NAME HERE*/
) c
on a.block_fips = c.block_fips
where row_numb = 1 --## For each census block, keep the Census Place area where most of its area lies
and (a.area > (c.area - total_area_intersect)); commit;   --## Perform area check:  If census block's maximum area (rank = 1) is greater than area that does not fall inside any Census Place area, then assign to that Census Place area.  Otherwise do not assign.  


create index on nbm2.cplace_block_overlay (block_fips); commit; 


-----------------------------------------
-------- CONGRESSIONAL DISTRICT OVERLAY
-----------------------------------------
--------------------------------------------------------------------------------------------------------------
-- Description:  Performs a spatial intersect of each Cong. District geography with the census block geography 
--------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.cdist_block_overlay_stg; commit; 
create table nbm2.cdist_block_overlay_stg
(
block_fips varchar(15),
cdist_id varchar(5),
area numeric,
geom geometry(multipolygon, 4326)
); commit; 


do $$
DECLARE
        s character varying;   
        arr_split_data  text[];
begin

select into arr_split_data regexp_split_to_array('01,02,04,05,06,08,09,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56,60,66,69,72,78',',');  --## Loop through the census blocks in each state
foreach s in ARRAY arr_split_data loop
    
    insert into nbm2.cdist_block_overlay_stg
    select block_fips, geoid as cdist_id,
    (case when st_within(a.geom, b.geom) then st_area(a.geom::geography) else NULL end) as area, --## If a census block falls completely within a Cong. District geography, calculate its entire area (in square meters), or else keep area blank
    (case when st_within(a.geom, b.geom) then a.geom else st_multi(st_buffer(st_intersection(a.geom, b.geom), 0.0)) end) as geom  --## If a census block falls completely within a Cong. District geography, keep its entire geometry, otherwise keep the portion of the census block that falls inside the Cong. District geography
    from nbm2.nbm2_block2010 a, nbm2.nbm2_cd115_2016 b   /*CHANGE TABLE NAMES HERE*/
    where st_intersects(a.geom, b.geom) and substr(block_fips, 1, 2) = s and b.statefp = s;  --## To take advantage of spatial index, only consider those census blocks that intersect a Cong. District area

end loop;
end;
$$; commit; 

update nbm2.cdist_block_overlay_stg set area = st_area(geom::geography) where area IS NULL; commit;  --## In cases where a portion of a census block fell inside a Cong. District geography (which we left blank above), calculate its area (in square meters)  


--------------------------------------------------------------------------------------------------------------------------------------------------------
-- Description:  Uses the data from the spatial intersect above to assign blocks to a single Congressional District area (based on area business rule)
--------------------------------------------------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.cdist_block_overlay; commit; 
create table nbm2.cdist_block_overlay
(
block_fips varchar(15),
cdist_id varchar(5),
area_pct numeric
); commit; 

insert into nbm2.cdist_block_overlay
select a.block_fips, cdist_id, round((a.area/b.area)::numeric, 4) as area_pct
from 
(
   select block_fips, cdist_id, area, row_number() OVER (PARTITION BY block_fips order by area desc) as row_numb
   from nbm2.cdist_block_overlay_stg 
   where area >= 1  --## Consider only intersections where at least 1 sq. meter of a census block intersected the Cong. District area
) a
left join
(
   select block_fips, st_area(geom::geography) as area
   from nbm2.nbm2_block2010   /*CHANGE TABLE NAME HERE*/
) b
on a.block_fips = b.block_fips
where row_numb = 1; --## For each census block, keep the Cong. District area where most of its area lies
commit; 


create index on nbm2.cdist_block_overlay (block_fips); commit; 
create index on nbm2.cdist_block_overlay (substr(block_fips, 1, 2)); commit; 


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Rule:  Every census block should be assigned to a Cong. District.  Some census blocks located in bodies of water do not intersect the Cong. Dist layer, so assign these based on distance (i.e. assign census block to closest Cong. Dist) 
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
do $$
DECLARE
        s character varying;   
        arr_split_data  text[];
begin

select into arr_split_data regexp_split_to_array('01,02,04,05,06,08,09,10,11,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56,60,66,69,72,78',',');  --## Loop through unassigned census blocks in each state
foreach s in ARRAY arr_split_data loop

insert into nbm2.cdist_block_overlay
select block_fips, cdist_id, 999 as area_pct --## Keep records where rank = 1 (which equals the shortest distance).  Set area_pct value = 999 so that we know which blocks were assigned based on this distance measure
from
(
--## For each unassigned census block, measure the distance to all Cong. Districts in the state and rank by distance
select x.block_fips, cdist_id, row_number() OVER (PARTITION BY block_fips order by st_distance(x.geom::geography, y.geom::geography)) as row_numb
from 
(
	--## Find census blocks that were not assigned a Congressional District (x subquery)
		select a.block_fips, substr(a.block_fips, 1, 2) as state_fips, geom
		from
		(
			select block_fips, geom
			from nbm2.nbm2_block2010
			where substr(block_fips, 1, 2) = s
		) a
		left join
		(
			select block_fips
			from nbm2.cdist_block_overlay
			where substr(block_fips, 1, 2) = s
		) b
		on a.block_fips = b.block_fips
		where b.block_fips is null
	) x
	left join
	(
	--## Extract Cong. District geometries 
		select statefp as state_fips, geoid as cdist_id, geom
		from nbm2.nbm2_cd115_2016
		where statefp = s
	) y
	on x.state_fips = y.state_fips
	order by x.block_fips, cdist_id
) z
where row_numb = 1; --## Keep records where rank (i.e. distance) is smallest

end loop;
end;
$$; commit; 




-------------------------------------
-------- COUNTY BLOCK OVERLAY
-------------------------------------
-- ## Form 477 data is collected using the census 2010 census block definitions.  Since some counties have changes since 2010, we must do a custom overlay for certain areas.
-- ## Step 1:  Go to the following website: https://www.census.gov/geo/reference/county-changes.html
-- ## Step 2:  Change the code below to include the county areas that have changed


--------------------------------------------------------------------------------------------------------------
-- Description:  Performs a spatial intersect of counties (in certain counties) with the census block geography 
--------------------------------------------------------------------------------------------------------------
drop table if exists nbm2.county_block_overlay_stg; commit; 
create table nbm2.county_block_overlay_stg
(
block_fips varchar(15),
county_fips varchar(5),
area numeric,
geom geometry(multipolygon, 4326)
); commit; 


    insert into nbm2.county_block_overlay_stg
    select block_fips, geoid as county_fips,
    (case when st_within(a.geom, b.geom) then st_area(a.geom::geography) else NULL end) as area, --## If a census block falls completely within a Countyt geography, calculate its entire area (in square meters), or else keep area blank
    (case when st_within(a.geom, b.geom) then a.geom else st_multi(st_buffer(st_intersection(a.geom, b.geom), 0.0)) end) as geom  --## If a census block falls completely within a County geography, keep its entire geometry, otherwise keep the portion of the census block that falls inside the Cong. District geography
    from nbm2.nbm2_block2010 a, nbm2.nbm2_county2016 b   /*CHANGE TABLE NAMES HERE*/
    where st_intersects(a.geom, b.geom) and substr(block_fips, 1, 5) in ('02195', '02105', '02198');  --## Perform spatial overlay in 3 Alaskan Counties

update nbm2.county_block_overlay_stg set area = st_area(geom::geography) where area IS NULL; commit;  --## In cases where a portion of a census block fell inside a County geography (which we left blank above), calculate its area (in square meters)  


------------------------------------------------------------------------------
-- Description:  Uses business rule to assign blocks to a single County area 
------------------------------------------------------------------------------
drop table if exists nbm2.county_block_overlay; commit; 
create table nbm2.county_block_overlay
(
block_fips varchar(15) primary key,
county_fips varchar(5),
area_pct numeric
); commit; 


--------------------------------------------------------------------------------------------------------------------------
-- Description:  For states where the county hasn't changed since 2016, insert the first 5 characters of the block_fips
--------------------------------------------------------------------------------------------------------------------------
insert into nbm2.county_block_overlay
select block_fips, 
(case when substr(block_fips, 1, 5) = '51515' then '51019' --## COUNTY FIPS 51515 FROM 2010 IS NOW 51019
when substr(block_fips, 1, 5) = '46113' then '46102'  --## COUNTY FIPS 46113 FROM 2010 IS NOW 46102
when substr(block_fips, 1, 5) = '02270' then '02158'  --## COUNTY FIPS 51515 FROM 2010 IS NOW 51019
else substr(block_fips, 1, 5) end) as county_fips,
1 as area_pct
from nbm2.nbm2_block2010
where substr(block_fips, 1, 5) not in ('02195', '02105', '02198'); /*CHANGE COUNTIES HERE*/  --##SET ASIDE COUNTIES IN ALASKA WHERE GEOGRAPHY CHANGED
commit; 


---------------------------------------------------------------------------------------------
-- Description:  For special case counties, assign blocks based on maximum intersected area 
---------------------------------------------------------------------------------------------
insert into nbm2.county_block_overlay
select a.block_fips, county_fips, round((a.area/b.area)::numeric, 4) as area_pct
from 
(
   select block_fips, county_fips, area, row_number() OVER (PARTITION BY block_fips order by area desc) as row_numb
   from nbm2.county_block_overlay_stg 
   where area >= 1  --## Consider only intersections where at least 1 sq. meter of a census block intersected the County area
) a
left join
(
   select block_fips, st_area(geom::geography) as area
   from nbm2.nbm2_block2010   /*CHANGE TABLE NAME HERE*/
) b
on a.block_fips = b.block_fips
where row_numb = 1; --## For each census block, keep the County area where most of its area lies
commit; 


create index on nbm2.county_block_overlay (block_fips); commit; 
create index on nbm2.county_block_overlay (county_fips); commit; 


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Rule:  Every census block should be assigned to a County.  Due to accuracy issues in geospatial layers, a handful of blocks may not overlap a county. So we assign these based on distance (i.e. assign census block to closest County) 
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
insert into nbm2.county_block_overlay
select block_fips, county_fips, 999 as area_pct --## Keep records where rank = 1 (which equals the shortest distance).  Set area_pct value = 999 so that we know which blocks were assigned based on this distance measure
from
(
--## For each unassigned census block, measure the distance to all County in the state and rank by distance
select x.block_fips, county_fips, row_number() OVER (PARTITION BY block_fips order by st_distance(x.geom::geography, y.geom::geography)) as row_numb
from 
(
	--## Find census blocks that were not assigned a County (x subquery)
		select a.block_fips, substr(a.block_fips, 1, 2) as state_fips, geom
		from
		(
			select block_fips, geom
			from nbm2.nbm2_block2010
			where substr(block_fips, 1, 5) in ('02195', '02105', '02198')
		) a
		left join
		(
			select block_fips
			from nbm2.county_block_overlay
			where substr(block_fips, 1, 5) in ('02195', '02105', '02198')
		) b
		on a.block_fips = b.block_fips
		where b.block_fips is null
	) x
	left join
	(
	--## Extract County geometries 
		select statefp as state_fips, geoid as county_fips, geom
		from nbm2.nbm2_county2016
		where substr(block_fips, 1, 5) in ('02195', '02105', '02198')
	) y
	on x.state_fips = y.state_fips
	order by x.block_fips, county_fips
) z
where row_numb = 1; --## Keep records where rank (i.e. distance) is smallest

end loop;
end;
$$; commit; 
 




---------------------------------------------------------------------------
---------------------------------------------------------------------------
---- CREATE FINAL BLOCK MASTER TABLE
---------------------------------------------------------------------------
---------------------------------------------------------------------------
DROP TABLE IF EXISTS nbm2.blockmaster_dec2016; commit; 
CREATE TABLE nbm2.blockmaster_dec2016
(
geoid10 character varying(15),
stateabbr character varying(2),
hu numeric, 
hh numeric,  
pop numeric,  
h2only_undev integer,
state_fips character varying(2),
urban_rural character varying(1),
county_fips character varying(5),
cbsa_code character(5),
tribal_non character(1),
tribal_id character varying(5),
aianhhcc character(2),
cplace_id character(7),
cdist_id character(4)
); commit; 


insert into nbm2.blockmaster_dec2016
select a.block_fips as geoid10, stateabbr, coalesce(hu, 0) as hu, coalesce(hh, 0) as hh, coalesce(pop, 0) as pop, /*CHANGE NAMES HERE*/
(case when aland10 = 0 then 1 when (coalesce(hu, 0) = 0 and coalesce(pop, 0) = 0 and aland10 > 0) then 2 else 0 end) as h2only_undev,
substr(a.block_fips, 1, 2) as state_fips, urban_rural, d.county_fips, cbsa_code, tribal_non, tribal_id, aianhhcc, cplace_id, cdist_id
from
( 
--## Get a list of all census blocks
	select block_fips, county_fips
	from nbm2.nbm2_block2010   /*CHANGE TABLE NAME HERE*/
) a
left join
(
--## Get the population, housing units, and households for each census block
	select block_fips, hu2016 as hu, hh2016 as hh, pop2016 as pop
	from nbm2.us_pop_hu_hh   /*CHANGE TABLE NAME HERE*/
) b
on a.block_fips = b.block_fips
left join
(
--## Get the state abbreviation, urban/rural, and tribal/non-tribal information for each block
	select geoid10 as block_fips, stateabbr, urban_rural, tribal_non
	from nbm2.blockmaster_static   
) c
on a.block_fips = c.block_fips
left join
(
--## Get the County assignment for each census block
	select block_fips, county_fips
	from nbm2.county_block_overlay
) d
on a.block_fips = d.block_fips
left join
(
--## Get the Census Place assignment for each census block
	select block_fips, cplace_id
	from nbm2.cplace_block_overlay
) e
on a.block_fips = e.block_fips
left join
(
--## Get the Tribal assignment for each census block
	select block_fips, tribal_id, aianhhcc
	from nbm2.tribal_block_overlay
) f
on a.block_fips = f.block_fips
left join
(
--## Get the Cong. District assignment for each census block
	select block_fips, cdist_id
	from nbm2.cdist_block_overlay
) g
on a.block_fips = g.block_fips
left join
(
--## Get the CBSA assignment for each county
	select county_fips, cbsa_code
	from nbm2.county_to_cbsa_lookup 
) h
on d.county_fips = h.county_fips
left join
(
--## Get the CBSA assignment for each county
	select block_fips, aland10 
    from nbm2.nbm2_block2010
) i
on a.block_fips = i.block_fips
order by a.block_fips; commit; 



-------------------------------------
-------------------------------------
----- CREATE GEOGRAPHY NAMES TABLE
-------------------------------------
-------------------------------------

drop table if exists nbm2.blockmaster_dec2016_names; commit; 
create table nbm2.blockmaster_dec2016_names
(
id varchar(13),
type varchar(6),
name varchar(74)
); commit; 

--## INSERT THE ID AND NAME FOR EACH TYPE OF GEOGRAPHY
-- STATE
insert into nbm2.blockmaster_dec2016_names
select geoid as id, 'state' as type, name 
from nbm2.nbm2_state2016; commit; 

-- COUNTY
insert into nbm2.blockmaster_dec2016_names
select geoid as id, 'county' as type, namelsad as name  
from nbm2.nbm2_county2016; commit; 

-- CBSA
insert into nbm2.blockmaster_dec2016_names
select geoid as id, 'cbsa' as type, name 
from nbm2.nbm2_cbsa2016; commit; 

-- Tribal
insert into nbm2.blockmaster_dec2016_names
select geoid as id, 'tribal' as type, namelsad as name 
from nbm2.nbm2_tribe2016; commit; 

-- Census Place
insert into nbm2.blockmaster_dec2016_names
select geoid as id, 'place' as type, name 
from nbm2.nbm2_place2016; commit; 

-- Congressional District
insert into nbm2.blockmaster_dec2016_names
select a.geoid as id, 'cd' as type, b.namelsad as name
from nbm2.nbm2_cd115_2016 a, nbm2.nbm2_cd115_2016_tigerline b, nbm2.nbm2_state2016 c  --## The join to Tigerline CDist table is required in order to extract the Cong. District name
where a.geoid = b.geoid and a.statefp = c.geoid; commit; 