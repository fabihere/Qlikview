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

//order_items:
//LOAD
//	variant_id,
//	[Product ID Abacos],
//	campaign_id,
//	order_id,
//	[Order ID Abacos],
//	DATE(	[Order Date]) as order_date,
//	[Order Year-Month],
//	[Campaign Name],
//	[Campaign Starts],
//	[Campaign Ends],
//	[Order ID Abacos]&'|'&[Product ID Abacos],
//	[Order ID Abacos|Product ID Abacos]
//FROM [$(vpathQVD)campaign_product_list.qvd] (qvd);
//
//active_campaigns:
//load
//	MonthsStart(order_date),
//
///$tab campaigns
campaigns:
LOAD id as campaign_id,
    name,
	if(isnull(offer_starts_at),'Null',date(ConvertToLocalTime(offer_starts_at,'Brasilia',false()))) as offer_starts,
	if(isnull(offer_starts_at),'Null',num(year(ConvertToLocalTime(offer_starts_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(offer_starts_at,'Brasilia',false())),'00')) as offer_starts_year_month,
	if(isnull(offer_starts_at),'Null',	date(ConvertToLocalTime(offer_ends_at,'Brasilia',false()))) as offer_ends,
	if(isnull(offer_starts_at),'Null',	num(year(ConvertToLocalTime(offer_ends_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(offer_ends_at,'Brasilia',false())),'00')) as offer_ends_year_month
FROM [$(vpathQVD)campaigns.qvd] (qvd);

activecampaigns:
Load
	campaign_id,
	offer_starts_year_month as month_year
Resident campaigns;

Concatenate
Load
	campaign_id,
	offer_ends_year_month as month_year
Resident campaigns;

LEFT JOIN
LOAD
	campaign_id,
    product_id
FROM [$(vpathQVD)campaigns_products.qvd] (qvd);

skus:
LOAD
    id as product_id,
    id as productkey,
    parent_product_id,
    parent_product_id as skukey
FROM [$(vpathQVD)products.qvd] (qvd)
WHERE NOT isnull(parent_product_id);

CONCATENATE
LOAD
	id as product_id,
	id as productkey,
	id as skukey
FROM [$(vpathQVD)products.qvd] (qvd)
WHERE isnull(parent_product_id)
AND
NOT exists (skukey, id);

LEFT JOIN
load
	id as productkey,
	final_category
FROM [$(vpathQVD)category_table.qvd] (qvd);

calendar:
LOAD



//
//
//
//

///$tab Test
test1:
Load
	month_year as active_campaigns_month_year,
	count(DISTINCT(campaign_id)) as active_campaigns_count
Resident activecampaigns
Group by month_year;
