--distance to nearest road
--inv dist to nearest road
--inv dist to nearest road^2
--dist to nearest major road
--inv dist to nearest major road
--inv dist to nearest major road^2
--operation uses France IGN Route 500 road layer, OpenStreetMap France produces better model performance

--RECODE the roads layer to get nearest neighbour function to operate properly - zero if major, 1 if locale
	alter table mainland_route500_final add column vocation_code smallint;

	update mainland_route500_final 
	set vocation_code = '4'
	where vocation = 'Liaison locale';

--http://gis.stackexchange.com/questions/14456/finding-the-closest-geometry-in-postgis (modified)
create or replace function  nnid(nearto geometry, initialdistance real, distancemultiplier real, 
maxpower integer, nearthings text, nearthingsidfield text, nearthingsgeometryfield  text, roadtype text)
returns integer as $$
declare 
  sql text;
  result integer;
begin
  sql := ' select ' || quote_ident(nearthingsidfield) 
      || ' from '   || quote_ident(nearthings)
      || ' where '  || quote_ident(nearthings) || roadtype
      || ' and st_dwithin($1, ' 
      ||   quote_ident(nearthingsgeometryfield) || ', $2 * ($3 ^ $4))'
      || ' order by st_distance($1, ' || quote_ident(nearthingsgeometryfield) || ')'
      || ' limit 1';
  for i in 0..maxpower loop
     execute sql into result using nearto             -- $1
                                , initialdistance     -- $2
                                , distancemultiplier  -- $3
                                , i;                  -- $4
     if result is not null then return result; end if;
  end loop;
  return null;
end
$$ language 'plpgsql' stable;

do $$
declare 
	recpt text := 'national_no2_2008'; --air quality monitoring stations
	roads text := 'mainland_route500_final'; --road network
	sql text;


begin

	--find nearest neighbours first 
  --find all nearest roads
  --find only nearest major roads
	sql := '
	drop table if exists roaddists;
	create table roaddists as 
	with nn as (
		select distinct r.gid, r.geom,
		nnid(r.geom, 1000, 2, 100, '''|| roads ||''', ''gid'', ''geom'', ''.vocation_code >= 0'') as nn_all,
		nnid(r.geom, 1000, 2, 100, '''|| roads ||''', ''gid'', ''geom'', ''.vocation_code <= 3'') as nn_maj
		from '|| recpt ||' as r
	)
	select DAR.gid, DAR.distnear as distnear, (1 / DAR.distnear) as distinvnear1, (1 / (DAR.distnear * DAR.distnear)) as intinvdist, 
	DMR.distnear as majordistnear, (1 / DMR.distnear) as distinvmajornear1, (1 / (DMR.distnear * DMR.distnear)) as intmajorinvdist
	from
		(select nn.gid, st_distance(nn.geom, t.geom) as distnear
		from nn left join '|| roads ||' as t 
		on nn.nn_all = t.gid
		) as DAR
	left join
		(select nn.gid, st_distance(nn.geom, t.geom) as distnear
		from nn left join '|| roads ||' as t 
		on nn.nn_maj = t.gid
		) as DMR
	on DAR.gid = DMR.gid';
	
	execute sql;
end;
$$language plpgsql;
