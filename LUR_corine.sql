--alter the spatial ref table to include the esri srid for rgf 1993 lambert 93 - France--  only needs to be done once
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 102110, 'ESRI', 102110, '+proj=lcc +lat_1=44 +lat_2=49 +lat_0=46.5 +lon_0=3 +x_0=700000 +y_0=6600000 +ellps=GRS80 +units=m +no_defs ', 'PROJCS["RGF_1993_Lambert_93",GEOGCS["GCS_RGF_1993",DATUM["RGF_1993",SPHEROID["GRS_1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Lambert_Conformal_Conic_2SP"],PARAMETER["False_Easting",700000],PARAMETER["False_Northing",6600000],PARAMETER["Central_Meridian",3],PARAMETER["Standard_Parallel_1",44],PARAMETER["Standard_Parallel_2",49],PARAMETER["Latitude_Of_Origin",46.5],UNIT["Meter",1],AUTHORITY["EPSG","102110"]]');

--vacuum analyze is required on the tables to ensure the GiST index works correctly: http://postgis.net/docs/manual-1.3/ch03.html#id434676--

--select out no2 from AIRBASE air pollution db for France 2008 (example year)---
drop table if exists national_no2_2008;
create table national_no2_2008 as
select * from no2_test_stations
where year = '2008-01-01';  --NB all days for each year have this ID

--begin processing--
do $$
declare 
	recpt text := 'national_no2_2008'; --air quality monitoring stations (point location as geom)
	corine text := 'fr_corine_1'; --this is the vector file for land use polygons
	radii text[] = array['10000', '5000', '3000', '1000', '500', '400', '300', '200', '100']; --agreed upon buffer sizes
	i text;
	sql text;
  
begin

	drop table if exists buffers;

	--Make buffers
	sql := 'create table buffers as select ';
	foreach i in array radii
	loop 
		sql := sql || 'st_buffer(r.geom, ' || i || ') as b' || i || ', ';
	end loop;
	sql := sql || 'r.gid from ' || recpt || ' as r';
	execute sql;


	--do intersections
	foreach i in array radii
	loop
		raise notice '%', i; 
		execute 'create index buf_indx_' || i || ' on buffers' || ' using gist (b' || i || ')';
		
	----creates a table of area values for each specified land use, for each defined buffer
  ----xen_code is a bespoke id created for land use groups for a specific project
		sql := '
		drop table if exists corine' || i || '; 
		create table corine' || i || ' as
		with intsct as (
				select b.gid, c.xen_code, sum(st_area(st_intersection(c.geom, b.b'|| i ||'))) as area
				from '|| corine ||' as c, buffers as b
				where st_intersects(c.geom, b.b'|| i ||')
				group by b.gid, c.xen_code
		)

		select contUrb.gid, contUrb.ContUrbFabric, disContUrb.DiscontinuousUrban, IND.Industry,
		ROAD.IndorTransport, UGR.Urbgreen, AG.Agriculture,
		TREE.Forest, OTH.OtherNatural, WAT.AllWater
		from
			(select b.gid, coalesce(intsct.area, 0) as ContUrbFabric
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''1''
			group by b.gid, intsct.area
			) as contUrb
		left join 
			(select b.gid, coalesce(intsct.area, 0) as DiscontinuousUrban
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''2''
			group by b.gid, intsct.area
			) as disContUrb
		on contUrb.gid = disContUrb.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as Industry
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''3''
			group by b.gid, intsct.area
			) as IND
		on contUrb.gid = IND.gid
		left join 
			(select b.gid, coalesce(intsct.area, 0) as IndorTransport
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''4''
			group by b.gid, intsct.area
			) as ROAD
		on contUrb.gid = ROAD.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as Urbgreen
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''5''
			group by b.gid, intsct.area
			) as UGR
		on contUrb.gid = UGR.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as Agriculture
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''6''
			group by b.gid, intsct.area
			) as AG
		on contUrb.gid = AG.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as Forest
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''7''
			group by b.gid, intsct.area
			) as TREE
		on contUrb.gid = TREE.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as OtherNatural
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''8''
			group by b.gid, intsct.area
			) as OTH
		on contUrb.gid = OTH.gid
		left join
			(select b.gid, coalesce(intsct.area, 0) as AllWater
			from buffers as b left join intsct
			on b.gid = intsct.gid
			and intsct.xen_code = ''9''
			group by b.gid, intsct.area
			) as WAT
		on contUrb.gid = WAT.gid';
		

		execute sql;

	end loop;

end;
$$language plpgsql;
