distinct_source:
LOAD
	distinct(source) as source
FROM [$(vpathQVD)utms.qvd] (qvd);

group_source:
LOAD
	source,
	'emkt' as source_group
Resident distinct_source
WHERE wildmatch(source,'*emkt*','*welcome*','*howit*','*baseat*');

Concatenate
LOAD
	source,
	'push' as source_group
Resident distinct_source
WHERE wildmatch(source,'*push*');

Concatenate
LOAD
	source,
	'other' as source_group
Resident distinct_source
WHERE NOT wildmatch(source,'*push*','*emkt*','*welcome*','*howit*','*base*');

drop table distinct_source;
