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



set vpathQVD='D:\QlikView\DataSource\';
set vpathETL='D:\QlikView\DataETL\';






///$tab Orders
users:
load  id as user_id,
    email,
    first_name,
    last_name,
    gender,
    utm_id as users.utmid,
    origin as users.origin,
    date(	ConvertToLocalTime(created_at,'Brasilia',false()),'MM/DD/YYYY') as register_date
FROM [$(vpathQVD)users.qvd] (qvd);

ordersqvd:
Load id,
    user_id,
	created_at,
    updated_at,
    shipping_price,
    state,
    utm_id,
    cached_final_value,
    cached_total_value,
    cached_credits,
    origin,
    coupon_id
FROM [$(vpathQVD)orders.qvd] (qvd);


consider:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);

orders:
Load id as order_id,
    user_id,
	date(	ConvertToLocalTime(created_at,'Brasilia',false()),'MM/DD/YYYY') as created_at_br,
	MonthName(date(	ConvertToLocalTime(created_at,'Brasilia',false()),'MM/DD/YYYY')) as [Order Month Year],
    date(	ConvertToLocalTime(updated_at,'Brasilia',false()),'MM/DD/YYYY') as updated_at_br,
    state as orders_state,
    ApplyMap('consider',state,'error') as consider,
    utm_id as orders_utmid,
    cached_total_value as orders_basketvalue,
    shipping_price as orders_shippingvalue,
    cached_total_value + shipping_price as orders_salesvalue,
    cached_credits as orders_creditvalue,
    cached_final_value as orders_finalvalue,
    if ( origin = 1, 'Website', if ( origin = 2, 'iOS App', if( origin = 3, 'Third Party', 'Android App'))) as orders_origin,
    user_id&'|'&id as ftpkey,
    coupon_id
Resident ordersqvd;

left join
load  user_id,
    email,
    register_date
Resident users;
drop table users;

drop table ordersqvd;
store orders into [$(vpathETL)orderstreated.qvd] (qvd);

// drop table orderstates;

FirstTimeBuyers:
load user_id as [User ID],
	min(order_id) as first_order_id,
	date(min(created_at_br)) as first_order_date,
	MonthName(date(min(created_at_br))) as [First Order Month Year],
	user_id&'|'&min(order_id) as ftpkey
Resident orders
Where	consider = 'yes'
Group by user_id;

STORE FirstTimeBuyers into [$(vpathETL)ftbs.qvd] (qvd);

//drop table FirstTimeBuyers;
//drop table Orders;








///$tab Tests


//FirstTimeBuyers:
//load users.id as [User ID],
//	date(min(orders.date.br)) as first.order.date,
//	MonthName(date(min(orders.date.br))) as [First Order Month Year],
//	users.id&'|'&date(date(min(orders.date.br)),'MMDDYYYY|hhmmss') as ftpkey
//Resident Orders
//Where	consider = 'yes' and
//date(min(orders.date.br)) =
//Group by users.id&'|'&date(date(min(orders.date.br)),'MMDDYYYY|hhmmss');

//store FirstTimeBuyers into [$(vpath)\ftbs.qvd] (qvd);



ODBC CONNECT TO [MySQL Dinda BI] (XUserId is PXFBJRFNfCZSGXRMBbPA, XPassword is fOdGIRFNELacGSFMSBMCDaEN);








///$tab Orders
ftbs:
load ftpkey,
	[User ID],
	first_order_id as [First Order],
	first_order_date as [First Order Date],
	MonthName(first_order_date) as [FTB Month Year],
	MonthName(first_order_date) as [FTB Cohort],
	1 as [FTB Count]
FROM [$(vpathETL)ftbs.qvd] (qvd);

LEFT join
Load
	id as [User ID],
	date(    ConvertToLocalTime(created_at,'Brasilia',false())) as register_date,
	MonthName(    ConvertToLocalTime(created_at,'Brasilia',false())) as register_cohort
From [$(vpathQVD)users.qvd] (qvd) ;

left join
LOAD id as [User ID],
    email as vipemail,
    utm_id,
    origin,
    1 as vipcount,
	date(    ConvertToLocalTime(vip_since,'Brasilia',false())) as vipdate,
		MonthName(    ConvertToLocalTime(vip_since,'Brasilia',false())) as vipcohort,
			QuarterName(    ConvertToLocalTime(vip_since,'Brasilia',false())) as vipquarter;
SQL SELECT id,
    email,
    `utm_id`,
    origin,
    `vip_since`
FROM `dinda_prd`.users
WHERE NOT isnull(vip_since);

orders:
Load
	order_id,
	user_id,
	created_at_br,
	[Order Month Year],
	updated_at_br,
	orders_state,
	orders_utmid,
    orders_basketvalue,
    orders_shippingvalue,
	orders_salesvalue,
    orders_creditvalue,
    orders_finalvalue,
    orders_origin,
    consider,
    ftpkey,
    email
from [$(vpathETL)orderstreated.qvd] (qvd);

LEFT JOIN
LOAD user_id,
     email,
     vip_since as vip_date,
     MonthName(date(vip_since)) as vip_cohort,
     1 as eternalvip
FROM
[D:\QlikView\Dados\Dropbox\Qlikview\File Sources\vip_eterno.xlsx]
(ooxml, embedded labels, table is Sheet1);

LEFT JOIN
LOAD [User ID] as user_id,
		MonthName(first_order_date) as ftb_cohort
FROM [$(vpathETL)ftbs.qvd] (qvd);



















///$tab vips




//vips:
//LOAD Email
//FROM
//[D:\QlikView\Dados\Dropbox\Qlikview\File Sources\0515_vipeterno.xlsx]
//(ooxml, embedded labels, table is [0515_vipeterno]);
//
//Concatenate
//LOAD Email
//FROM
//[D:\QlikView\Dados\Dropbox\Qlikview\File Sources\0610_vipeterno.xlsx]
//(ooxml, embedded labels, table is [0610_vipeterno])
//WHERE NOT EXISTS (Email);
///$tab users
users:
load
	id as [User ID],
	email as first_register_email,
	date(ConvertToLocalTime(created_at,'Brasilia',false())) as first_register_date,
	first_name,
	last_name,
	phone,
	origin as first_register_origin,
	vip_since,
	main_address_id
FROM [$(vpathQVD)users.qvd] (qvd);

left join
LOAD id as main_address_id,
    neighborhood,
    city,
    state;
SQL SELECT id,
    neighborhood,
    city,
    state
FROM `dinda_prd`.addresses;

///$tab rfm
rfm:
LOAD
     ID as user_id,
     [Data Registro],
     [Data Primeira Compra],
     Pontuação,
     VIP,
     Recência,
     Freqüência,
     Receita
FROM
[D:\QlikView\Dados\Dropbox\Qlikview\File Sources\RFM-2015-11.csv]
(txt, utf8, embedded labels, delimiter is ',', msq);
