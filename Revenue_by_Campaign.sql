///$tab Main
SET ThousandSep=',';
SET DecimalSep='.';
SET MoneyThousandSep=',';
SET MoneyDecimalSep='.';
SET MoneyFormat='$#,##0.00;($#,##0.00)';
SET TimeFormat='h:mm:ss TT';
SET DateFormat='MM/DD/YYYY';
SET TimestampFormat='MM/DD/YYYY h:mm:ss[.fff] TT';
SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec';
SET DayNames='Mon;Tue;Wed;Thu;Fri;Sat;Sun';

ODBC CONNECT TO [MySQL Dinda BI] (XUserId is VPCJLRFNfCZSGXRMBDXA, XPassword is PScPDRFNELacGSFMSBMCDaIB);

Set vpathQVD='D:\QlikView\DataSource\';
set vpathETL='D:\QlikView\DataETL\';

Let vGrossQuant = '(quantity)';
Let vCancelledStockoutQuant = '(cancelled_quantity)+(stockout_quantity)';
Let vLiquidQuant = '$(vGrossQuant)-($(vCancelledStockoutQuant))';

Let vBasketValue = '($(vLiquidQuant))*final_price';
Let vSalesValue = '($(vBasketValue))+shipping_price';
///$tab Filter orders
consider:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);

campaigns:
Mapping
LOAD id as campaign_id,
	name as [Campaign Name]
FROM [$(vpathQVD)campaigns.qvd] (qvd);

getorderstate:
LOAD id as order_id,
    state,
    ApplyMap('consider',state,'error') as consider
FROM [$(vpathQVD)orders.qvd] (qvd);

orders_items:
LOAD order_id,
	state
Resident getorderstate
where consider <> 'no';

LEFT JOIN
LOAD id as order_id,
    user_id,
    shipping_price as order_shipping_price,
    cached_final_value,
    cached_total_value,
    cached_credits,
    coupon_id
FROM [$(vpathQVD)orders.qvd] (qvd);

LEFT JOIN
LOAD
    order_id,
    product_id,
	quantity,
    final_price,
    shipping_price,
    campaign_id,
    variant_id,
	ApplyMap('campaigns',    campaign_id) as campaign_name,
    cancelled_quantity,
    stockout_quantity,
    	date(floor(ConvertToLocalTime(    created_at,'Brasilia',false()))) as [Order Date],
		num(year(ConvertToLocalTime(    created_at,'Brasilia',false())),'00')&'-'&
		num(month(ConvertToLocalTime(    created_at,'Brasilia',false())),'00') as [Order Year-Month],
		date(ConvertToLocalTime(    updated_at,'Brasilia',false())) as [Updated Date]
FROM [$(vpathQVD)order_items.qvd] (qvd);


drop table getorderstate;







///$tab Campaigns
campaigns:
LOAD id as campaign_id,
	//name as campaign_name,
    Year(ConvertToLocalTime(offer_starts_at,'Brasilia',false())) as [Campaign Start Year],
    num(month(ConvertToLocalTime(offer_starts_at,'Brasilia',false())),'00')&'-'&num(year(ConvertToLocalTime(offer_starts_at,'Brasilia',false()))) as [Campaign Starts Year Month],
	date(Floor(ConvertToLocalTime(offer_starts_at,'Brasilia',false()))) as [Campaign Starts],
    Year(ConvertToLocalTime(offer_ends_at,'Brasilia',false())) as [Campaign End Year],
    num(month(ConvertToLocalTime(offer_ends_at,'Brasilia',false())),'00')&'-'&num(year(ConvertToLocalTime(offer_ends_at,'Brasilia',false()))) as [Campaign Ends Year Month],
	date(Floor(ConvertToLocalTime(offer_ends_at,'Brasilia',false()))) as [Campaign Ends]
FROM [$(vpathQVD)campaigns.qvd] (qvd);

ftbs:
load
	[User ID],
	first_order_id as order_id,
	first_order_id as [First Order],
	first_order_date as [First Order Date],
	MonthName(first_order_date) as [FTB Month Year],
	MonthName(first_order_date) as [FTB Cohort],
	1 as [FTB Count]

from [$(vpathETL)ftbs.qvd] (qvd);

vips:
LOAD id as user_id,
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
