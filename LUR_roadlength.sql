--road length of all roads in buffers (buffer distances vary from land use buffers - nature of pollutant behaviour)

do $$
declare
	recpt text := 'national_no2_2008'; --air quality monitoring stations
	roads text := 'mainland_route500_final'; --the ign route 500 vector dataset
	radii text[] = array['1000', '500', '300', '100', '50', '25']; --buffer distances
	i text;
	sql text;

--remake buffers to reflect the nature of the variable
begin

	drop table if exists road_buffers_i;

	--Make buffers
	sql := 'create table road_buffers_i as select ';
	foreach i in array radii
	loop 
		sql := sql || 'st_buffer(r.geom, ' || i || ') as b' || i || ', ';
	end loop;
	sql := sql || 'r.gid from ' || recpt || ' as r';
	execute sql;


	--do calcs
	foreach i in array radii
	loop
		raise notice '%', i; 
		execute 'create index new_buf_indx_' || i || ' on road_buffers_i' || ' using gist (b' || i || ')';

	sql := '
		drop table if exists roadlength' || i || ';
		create table roadlength' || i || ' as
		select every.gid, every.length, coalesce(major.length_major, 0) as major_length
		from 
			(select b.gid, sum(st_length(st_intersection(r.geom, b.b'|| i ||'))) as length
				from '|| roads ||' as r, road_buffers_i as b
				where st_intersects(r.geom, b.b'|| i ||')
				group by b.gid
			) as every
		left join
			(select b.gid, sum(st_length(st_intersection(r.geom, b.b'|| i ||'))) as length_major
				from '|| roads ||' as r, road_buffers_i as b
				where st_intersects(r.geom, b.b'|| i ||')
				and r.vocation <> ''Liaison locale''
				group by b.gid
			) as major
		on every.gid = major.gid';
	
		execute sql;

	end loop;

end;
$$language plpgsql;
