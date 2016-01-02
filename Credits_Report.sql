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

Set vpathQVD='D:\QlikView\DataSource\';

ODBC CONNECT TO [MySQL Dinda BI] (XUserId is WFGMGRFNfCZSGXRMBTXA, XPassword is FfAXORFNELacGSFMSBMCDaUc);

credits:
LOAD id,
    `used_at`,
    value,
    `credit_type`,
    `user_id`,
    `created_at`,
    `updated_at`,
    `invited_id`,
    `order_id`,
    `cancelled_at`,
    `expires_at`,
    `origin_id`,
    `refund_id`;
SQL SELECT id,
    `used_at`,
    value,
    `credit_type`,
    `user_id`,
    `created_at`,
    `updated_at`,
    `invited_id`,
    `order_id`,
    `cancelled_at`,
    `expires_at`,
    `origin_id`,
    `refund_id`
FROM `dinda_prd`.credits
WHERE NOT isnull(used_at);

store credits into [$(vpathQVD)credits.qvd] (qvd);
drop table credits;

coupons:
LOAD id,
    code,
    value,
    `created_at`,
    `updated_at`,
    `user_constraint`,
    `order_constraint`,
    `channel_constraint`,
    enabled,
    `min_order_value`,
    `start_date`,
    `end_date`;
SQL SELECT id,
    code,
    value,
    `created_at`,
    `updated_at`,
    `user_constraint`,
    `order_constraint`,
    `channel_constraint`,
    enabled,
    `min_order_value`,
    `start_date`,
    `end_date`
FROM `dinda_prd`.coupons;

Store coupons into [$(vpathQVD)coupons.qvd] (qvd);
drop table coupons;

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



//connect to db

//ODBC CONNECT TO [MySQL Dinda BI] (XUserId is DIdQLRFNfCZSGXRMBTWA, XPassword is ZZVKPRFNELacGSFMSBMCDacC);


//set project file path

Set vpathQVD='D:\QlikView\DataSource\';
///$tab Pedidos
//creates orders.qvd

creditsload:
LOAD id,
	used_at,
    credit_type,
    invited_id,
    order_id,
    cancelled_at,
    origin_id
From  [$(vpathQVD)credits.qvd] (qvd);

credits:
LOAD id,
	date(ConvertToLocalTime(used_at,'Brasilia',false())) as [Date Used],
    monthname(ConvertToLocalTime(used_at,'Brasilia',false())) as [Month Year Used],
    5 as credit_value,
    credit_type,
    invited_id,
    order_id,
    cancelled_at,
    origin_id
Resident creditsload;

drop table creditsload;

orderstate:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);


orders:
Load
	 id as order_id,
    user_id,
    cached_total_value,
	date(    ConvertToLocalTime(created_at,'Brasilia',false())) as order_date,
	monthname(	ConvertToLocalTime(created_at,'Brasilia',false())) as order_year_month,
    applymap('consider',state,'error') as consider,
    coupon_id
FROM [$(vpathQVD)orders.qvd] (qvd);


left join
Load
 	 id as coupon_id,
 	 code,
    value,
    (value/100) as coupon_percent,
    user_constraint,
    order_constraint,
    channel_constraint,
    enabled,
    min_order_value,
    start_date,
    end_date
from [$(vpathQVD)coupons.qvd] (qvd);

let vCouponValue = 'cached_total_value*coupon_percent'


///$tab Coupons

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



//connect to db

//ODBC CONNECT TO [MySQL Dinda BI] (XUserId is DIdQLRFNfCZSGXRMBTWA, XPassword is ZZVKPRFNELacGSFMSBMCDacC);


//set project file path

Set vpathQVD='D:\QlikView\DataSource\';
///$tab Pedidos
//creates orders.qvd

creditsload:
LOAD id,
	used_at,
    credit_type,
    invited_id,
    order_id,
    cancelled_at,
    origin_id
From  [$(vpathQVD)credits.qvd] (qvd);

credits:
LOAD id,
	date(ConvertToLocalTime(used_at,'Brasilia',false())) as [Date Used],
    monthname(ConvertToLocalTime(used_at,'Brasilia',false())) as [Month Year Used],
    5 as credit_value,
    credit_type,
    invited_id,
    order_id,
    cancelled_at,
    origin_id
Resident creditsload;

drop table creditsload;

orderstate:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);


orders:
Load
	 id as order_id,
    user_id,
    cached_total_value,
	date(    ConvertToLocalTime(created_at,'Brasilia',false())) as order_date,
	monthname(	ConvertToLocalTime(created_at,'Brasilia',false())) as order_year_month,
    applymap('consider',state,'error') as consider,
    coupon_id
FROM [$(vpathQVD)orders.qvd] (qvd);


left join
Load
 	 id as coupon_id,
 	 code,
    value,
    (value/100) as coupon_percent,
    user_constraint,
    order_constraint,
    channel_constraint,
    enabled,
    min_order_value,
    start_date,
    end_date
from [$(vpathQVD)coupons.qvd] (qvd);

let vCouponValue = 'cached_total_value*coupon_percent'


///$tab Coupons
