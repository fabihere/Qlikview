///$tab Main
SET ThousandSep=',';
SET DecimalSep='.';
SET MoneyThousandSep=',';
SET MoneyDecimalSep='.';
SET MoneyFormat='$#,##0.00;($#,##0.00)';
SET TimeFormat='h:mm:ss TT';
SET DateFormat='M/D/YYYY';
SET TimestampFormat='M/D/YYYY h:mm:ss[.fff] TT';
SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec';
SET DayNames='Mon;Tue;Wed;Thu;Fri;Sat;Sun';


//Creates the main data cubes


set vpathQVD='D:\QlikView\DataSource\';
set vpathCube='D:\QlikView\DataCube\';






///$tab Maps
distinct_source:
LOAD
	distinct(source) as source
FROM [$(vpathQVD)utms.qvd] (qvd);

Concatenate:
LOAD
	'null' as source
FROM [$(vpathQVD)utms.qvd] (qvd)
WHERE isnull(source);

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
	'direct' as source_group
Resident distinct_source
WHERE wildmatch(source,'*direct*');

Concatenate
LOAD
	source,
	'unattributed' as source_group
Resident distinct_source
WHERE source = 'null';

Concatenate
LOAD
	source,
	'other' as source_group
Resident distinct_source
WHERE NOT wildmatch(source,'*emkt*','*welcome*','*howit*','*baseat*','*push*','*direct*','*null*')
;

drop table distinct_source;


utms:
LOAD id as utm_id,
    if(isnull(source),'null',source) as source,
     if(isnull(medium),'null',medium) as medium,
     if(isnull(campaign),'null',campaign) as campaign
FROM [$(vpathQVD)utms.qvd] (qvd);

LEFT JOIN
LOAD
	source,
	source_group
Resident group_source;

drop table group_source;

utm_group:
mapping
LOAD utm_id,
    source_group
Resident utms;

utm_source:
mapping
LOAD id as utm_id,
    source
FROM [$(vpathQVD)utms.qvd] (qvd);

utm_medium:
mapping
LOAD id as utm_id,
    medium
FROM [$(vpathQVD)utms.qvd] (qvd);

utm_campaign:
mapping
LOAD id as utm_id,
	campaign
FROM [$(vpathQVD)utms.qvd] (qvd);


origin:
mapping
LOAD * INLINE [
    origin, device
    1, Website
    2, iOS app
    3, Third Party
    4, Android app
    5, Mobile browser
];

email_subscription:
mapping
LOAD * INLINE [
    subscribed, email_subscription
    0, opt-out
    1, opt-in
];

consider:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);



///$tab Users Cube
//users:
//load  id as user_id,
//    email,
//    first_name,
//    last_name,
//    gender,
//    applymap('email_subscription',subscribed,'null') as email_subscription,
//	applymap('utm_source',utm_id,'no utm') as user_source,
//		applymap('utm_medium',utm_id,'no utm') as user_medium,
//			applymap('utm_campaign',utm_id,'no utm') as user_campaign,
//   				 applymap('origin',origin,'no utm') as user_origin,
//   				 	applymap('utm_group',utm_id,'no utm') as user_source_group,
//    				date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as register_date
//FROM [$(vpathQVD)users.qvd] (qvd);
//
//LEFT JOIN
//load id as user_id,
//	1 as user_app_count
//FROM [$(vpathQVD)users.qvd] (qvd)
//WHERE Match(origin,'2','4');
//
//LEFT JOIN
//load id as user_id,
//	1 as user_desktopbrowswer_count
//FROM [$(vpathQVD)users.qvd] (qvd)
//WHERE Match(origin,'1','3','5');
//
//store users into [$(vpathCube)userscube.qvd] (qvd);
///$tab Orders Cube
order_items:
LOAD
   	order_id,
   	quantity,
    final_price,
    cancelled_quantity,
    stockout_quantity,
    shipping_price,
    (quantity*final_price)+shipping_price+stockout_shipping_price as original_item_value,
			((quantity-cancelled_quantity-stockout_quantity)*final_price)+shipping_price as final_item_value,
			quantity-cancelled_quantity-stockout_quantity as final_item_quantity,
				cancelled_quantity+stockout_quantity as cancelledstockout_quantity
FROM [$(vpathQVD)order_items.qvd] (qvd);

orders1:
LOAD
	order_id,
	sum(original_item_value) as original_order_value,
	sum(quantity) as original_quantity,
	sum(cancelled_quantity) as cancelled_quantity,
	sum(stockout_quantity) as stockout_quantity,
	sum(cancelledstockout_quantity) as cancelledstockout_quantity,
	sum(final_item_quantity) as final_quantity,
	sum(final_item_value) as final_order_value
Resident order_items
Group by order_id;

orders:
Load
	id as order_id
FROM [$(vpathQVD)orders.qvd] (qvd)
WHERE match(state, 'captured', 'invoiced','delivered','shipping_successful');

LEFT JOIN
Load id as order_id,
    user_id,
    user_id&'|'&id as ftpkey,
	date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as order_date,
    state,
  	applymap('utm_source',utm_id,'no utm') as order_source,
		applymap('utm_medium',utm_id,'no utm') as order_medium,
			applymap('utm_campaign',utm_id,'no utm') as order_campaign,
   				 applymap('origin',origin,'no utm') as order_origin,
   				 	applymap('utm_group',utm_id,'no utm') as order_source_group
FROM [$(vpathQVD)orders.qvd] (qvd);

LEFT JOIN
Load order_id,
	original_order_value,
	original_quantity,
	cancelled_quantity,
	stockout_quantity,
	cancelledstockout_quantity,
	final_quantity,
	final_order_value,
    1 as order_count
Resident orders1;

temp:
LOAD
	order_id,
	if(isnull(Previous(user_id)),1,
		if(user_id=Previous(user_id) and order_date > previous(order_date), peek('RowNumber')+1,
			if(user_id <> Previous(user_id) and order_date > previous(order_date), 1))) as Rownumber,
			AutoNumber(order_id,user_id) as test
Resident orders;

Store orders into [$(vpathCube)orderscube.qvd] (qvd);

drop table order_items;
drop table orders1;







///$tab FTB Cube
//ftbs:
//load user_id,
//	min(order_id) as ftp,
//	date(min(order_date)) as ftp_order_date,
//	MonthName(date(min(order_date))) as ftp_cohort,
//	user_id&'|'&min(order_id) as ftpkey
//Resident orders
//WHERE match(state, 'invoiced','delivered','shipping_successful')
//Group by user_id;
//
//STORE ftbs into [$(vpathCube)ftbcube.qvd] (qvd);
//
//LEFT JOIN (users)
//LOAD
//	user_id,
//	ftp,
//	ftp_order_date,
//	ftp_cohort
//Resident ftbs;
//
//LEFT JOIN (orders)
//LOAD
//	ftpkey,
//	1 as ftb_count
//Resident ftbs;
//
//drop table ftbs;
///$tab Tests
