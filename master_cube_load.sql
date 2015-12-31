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

//Pull raw data qvds from
set vpathQVD='D:\QlikView\DataSource\';

//Save master data cubes to
set vpathCube='D:\QlikView\DataCube\';






///$tab UTM Groups

//Finds all distinct utm sources to create a To-From table of all distinct source data into key utm groups
distinct_source:
LOAD
	distinct(source) as source
FROM [$(vpathQVD)utms.qvd] (qvd);

Concatenate:
LOAD
	'null' as source
FROM [$(vpathQVD)utms.qvd] (qvd)
WHERE isnull(source);

//Creates utm groups based on marketing: as of 2015-12, grouped emkt, push, direct, unattributed and groups all others (other paid channels)
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

//Creates full utm cube with utm source group defined above and exports cube
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

store utms into [$(vpathCube)utmscube.qvd] (qvd);

///$tab Maps
//Creates maps
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
    3, Website
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
//Creates and exports users cube
users:
load  id as user_id,
    email,
    first_name,
    last_name,
    gender,
    subscribed as is_opt_in,

    applymap('email_subscription',subscribed,'null') as email_subscription,
	applymap('utm_source',utm_id,'no utm') as user_source,
		applymap('utm_medium',utm_id,'no utm') as user_medium,
			applymap('utm_campaign',utm_id,'no utm') as user_campaign,
   				 applymap('origin',origin,'no utm') as user_origin,
   				 	applymap('utm_group',utm_id,'no utm') as user_source_group,
    				date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as register_date,
    				num(year(ConvertToLocalTime(created_at,'Brasilia',false()))) as register_year,
							num(year(ConvertToLocalTime(created_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00') as register_cohort,
								date(	floor(ConvertToLocalTime(most_recent_access,'Brasilia',false())),'MM/DD/YYYY') as last_web_access_date,
									num(year(ConvertToLocalTime(most_recent_access,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(most_recent_access,'Brasilia',false())),'00') as web_access_cohort
FROM [$(vpathQVD)users.qvd] (qvd);

LEFT JOIN
load
	id as user_id,
		  if ( origin = 2, 1, if ( origin = 4, 1, 0)) as registered_via_app,
			if ( origin = 4 , 1, 0) as registered_via_mobile_browser,
				if(origin = 1, 1, if (origin = 3, 1,0)) as registered_via_desktop,
					if(IsNull(most_recent_access),0,1) as accesed_via_web
FROM [$(vpathQVD)users.qvd] (qvd);

LEFT JOIN
load
	user_id,
	1 as accessed_via_app,
	date(	floor(ConvertToLocalTime(most_recent_access,'Brasilia',false())),'MM/DD/YYYY') as last_app_access_date,
									num(year(ConvertToLocalTime(most_recent_access,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(most_recent_access,'Brasilia',false())),'00') as app_access_cohort
FROM [$(vpathQVD)app_sessions.qvd] (qvd);

store users into [$(vpathCube)userscube.qvd] (qvd);
///$tab Orders Cube
//Creates new column total_stockout_quantity to include orders with TOTAL STOCKOUT into calculation
temp:
LOAD
	id as order_id
FROM [$(vpathQVD)orders.qvd] (qvd)
WHERE match(state, 'cancelled_stockout');

LEFT JOIN
LOAD
	order_id,
	order_id&'|'&id as order_item_key,
	quantity as stockout_quantity
FROM [$(vpathQVD)order_items.qvd] (qvd);

cancelled_stockout:
mapping
LOAD
	order_item_key,
	stockout_quantity
Resident temp;

drop table temp;

//Creates new column total_cancelled_quantity into calculation

temp1:
LOAD
	id as order_id
FROM [$(vpathQVD)orders.qvd] (qvd)
WHERE match(state, 'cancelled');

LEFT JOIN
LOAD
	order_id,
	order_id&'|'&id as order_item_key,
	quantity as cancelled_quantity
FROM [$(vpathQVD)order_items.qvd] (qvd);

cancelled:
mapping
LOAD
	order_item_key,
	cancelled_quantity
Resident temp1;

drop table temp1;

//Creates and exports order items cube with most recent order data

order_items:
LOAD
   	order_id,
   	id,
   	campaign_id,
   	variant_id as productkey,
   	quantity,
    final_price,
    original_price,
    cancelled_quantity,
    stockout_quantity,
    shipping_price,
    stockout_shipping_price,
	order_id&'|'&id as order_item_key
FROM [$(vpathQVD)order_items.qvd] (qvd);

order_items1:
LOAD
   	*,
	ApplyMap('cancelled_stockout',order_item_key,stockout_quantity) as all_stockout_quantity,
		ApplyMap('cancelled',order_item_key,cancelled_quantity) as all_cancelled_quantity
Resident order_items;

order_items2:
LOAD
	*,
	    (quantity*final_price)+shipping_price+stockout_shipping_price as original_item_value,
			((quantity-all_cancelled_quantity-all_stockout_quantity)*final_price)+shipping_price as final_item_value,
			quantity-all_cancelled_quantity-all_stockout_quantity as final_item_quantity,
				all_stockout_quantity+all_cancelled_quantity as unsold_quantity
Resident order_items1;

store order_items2 into [$(vpathCube)orderitemscube.qvd] (qvd);

drop table order_items;
drop table order_items1;


//Calculates most recent data by order

orders1:
LOAD
	order_id,
	count(id) as number_of_products,
	sum(original_item_value) as original_order_value,
	sum(quantity) as original_quantity,
	sum(all_cancelled_quantity) as final_cancelled_quantity,
	sum(all_stockout_quantity) as final_stockout_quantity,
	sum(unsold_quantity) as final_unsold_quantity,
	sum(final_item_quantity) as final_quantity,
	sum(final_item_value) as final_order_value
Resident order_items2
Group by order_id;

//Creates and exports authorized orders cube:
temp3:
Load
	id as order_id,
	state,
	ApplyMap('consider',state,'error')as consider
FROM [$(vpathQVD)orders.qvd] (qvd);

authorized_orders:
LOAD
	order_id,
	state
Resident temp3
WHERE consider = 'yes';

LEFT JOIN
Load id as order_id,
    user_id,
    user_id&'|'&id as ftpkey,
	date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as order_date,
	num(year(ConvertToLocalTime(created_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00') as order_cohort,
		num(year(ConvertToLocalTime(created_at,'Brasilia',false()))) as order_year,
  	applymap('utm_source',utm_id,'no utm') as order_source,
		applymap('utm_medium',utm_id,'no utm') as order_medium,
			applymap('utm_campaign',utm_id,'no utm') as order_campaign,
   				 applymap('origin',origin,'no utm') as order_origin,
   				 	applymap('utm_group',utm_id,'no utm') as order_source_group,
   				 	  if ( origin = 2, 1, if ( origin = 4, 1, 0)) as via_app,
							if ( origin = 4 , 1, 0) as via_mobile_browser,
									if(origin = 1, 1, if (origin = 3, 1,0)) as via_desktop,
										state,
										user_id&'|'&num(year(ConvertToLocalTime(created_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00') as user_order_key
FROM [$(vpathQVD)orders.qvd] (qvd);

LEFT JOIN
Load order_id,
	original_order_value,
	original_quantity,
	final_cancelled_quantity,
	final_stockout_quantity,
	final_unsold_quantity,
	final_quantity,
	final_order_value,
    1 as is_considered_order
Resident orders1;

LEFT JOIN
Load order_id,
	1 as is_billed_order
Resident temp3
Where match(state,'shipping_successful','delivered');

drop table temp3;

store authorized_orders into [$(vpathCube)authorizedorderscube.qvd] (qvd);

drop table orders1;





//temp4:
//LOAD
//	order_id,
//	if(isnull(Previous(user_id)),1,
//		if(user_id=Previous(user_id) and order_date > previous(order_date), peek('RowNumber')+1,
//			if(user_id <> Previous(user_id) and order_date > previous(order_date), 1))) as Rownumber,
//			AutoNumber(order_id,user_id) as test
//Resident authorized_orders;
//
//Store orders into [$(vpathCube)orderscube.qvd] (qvd);
//
//drop table order_items;
//drop table orders1;
//
//
//
//



///$tab FTB Cube
//Creates FTB chart, excluding unauthorized or cancelled orders

ftbs:
load user_id,
	min(order_id) as ftp_order_id,
	date(min(order_date)) as ftp_order_date,
	num(year(min(order_date)))&'-'&num(month(min(order_date)),'00') as ftb_cohort,
	user_id&'|'&min(order_id) as ftpkey,
	1 as ftb_count
Resident authorized_orders
Group by user_id;

STORE ftbs into [$(vpathCube)ftbcube.qvd] (qvd);

temp5:
LOAD
	user_id
Resident users;

LEFT JOIN
LOAD
	user_id,
	1 as ftb_count,
	ftb_cohort
Resident ftbs;

temp6:
LOAD
	user_id,
	ftb_count as is_buyer,
	ftb_cohort
Resident temp5
where ftb_count = 1;

Concatenate
LOAD
	user_id,
	0 as is_buyer,
	0 as ftb_cohort
Resident temp5
where ftb_count <> 1;

drop table temp5;

LEFT JOIN (users)
load
	user_id,
	is_buyer,
	ftb_cohort
Resident temp6;

drop table temp6;

LEFT JOIN (authorized_orders)
LOAD
	ftp_order_id as order_id,
	1 as is_ftb
Resident ftbs;

drop fields user_id, ftb_cohort from ftbs;

//drop table ftbs;


///$tab Buyers
temp7:
LOAD
	order_cohort,
	user_id,
	count(DISTINCT(order_id))
Resident authorized_orders
Group by order_cohort,user_id;

left join
load
	user_id,
	ftb_cohort
Resident users;

buyers:
LOAD
	user_id&'|'&order_cohort as user_order_key,
	if(order_cohort=ftb_cohort,1,0) as is_ftb_in_month,
	if(order_cohort=ftb_cohort,'FTBs','Repeat Buyers') as buyer_type
Resident temp7;

drop table temp7;



///$tab Product Dimensions Cube
tags:
LOAD
	id as    age_id,
	id as    size_id,
	id as    category_id,
	id as     vertical_id,
	id as gender_id,
	id as subcategory_id,
    type,
    label
FROM [$(vpathQVD)tags.qvd] (qvd);

agetag:
mapping
load
	age_id,
	label
Resident tags;

sizetag:
mapping
load
	size_id,
	label
Resident tags;

categorytag:
mapping
load
	category_id,
	label
Resident tags;

verticaltag:
mapping
load
	vertical_id,
	label
Resident tags;

gendertag:
mapping
load
	gender_id,
	label
Resident tags;

subcategorytag:
mapping
load
	subcategory_id,
	label
Resident tags;

drop table tags;

brands:
LOAD id as brand_id,
    name,
    slug
FROM [$(vpathQVD)brands.qvd] (qvd);

brandtag:
Mapping
LOAD brand_id,
    name as brand_name
Resident brands;

drop table brands;

products_dimension:
//load variant-level dimensions first then left join with sku-level dimensions
LOAD
    id as productkey,
    parent_product_id,
   parent_product_id as skukey,
    applymap('agetag',age_id,'none') as [Age Group],
	applymap('sizetag',    size_id,	'none') as Size,
	supplier_size as [Supplier Size],
	date(Floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as [Product Date],
	num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00')&'-'&num(year(ConvertToLocalTime(created_at,'Brasilia',false()))) as [Product Year-Month],
	date(Floor(ConvertToLocalTime(updated_at,'Brasilia',false())),'MM/DD/YYYY') as [Product Updated],

	// Adicionado por David Bernardi - 08/12/15
	name,
	original_price as product_original_price,
	final_price	   as product_final_price,
	erp_code,
	supplier_color
FROM [$(vpathQVD)products.qvd] (qvd)
WHERE NOT isnull(parent_product_id);

LEFT JOIN
LOAD
	id as skukey,
	brand_id,
	applymap('brandtag',brand_id,'none') as brand_name,
	applymap('categorytag',    category_id,'none') as Category,
	applymap('verticaltag',    vertical_id, 'none') as Segment,
	ApplyMap('gendertag',    gender_id,'none') as Gender,
	ApplyMap('subcategorytag',    subcategory_id,'none') as Subcategory
FROM [$(vpathQVD)products.qvd] (qvd);

CONCATENATE
LOAD
	id as productkey,
	id as skukey,
	applymap('agetag',age_id,'none') as [Age Group],
	applymap('sizetag',    size_id,	'none') as Size,
	supplier_size as [Supplier Size],
	brand_id,
	applymap('brandtag',brand_id,'none') as brand_name,
	applymap('categorytag',    category_id,'none') as Category,
	applymap('verticaltag',    vertical_id, 'none') as Segment,
	ApplyMap('gendertag',    gender_id,'none') as Gender,
	ApplyMap('subcategorytag',    subcategory_id,'none') as Subcategory,
	date(Floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as [Product Date],
	date(Floor(ConvertToLocalTime(updated_at,'Brasilia',false())),'MM/DD/YYYY') as [Product Updated],
	num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00')&'-'&num(year(ConvertToLocalTime(created_at,'Brasilia',false()))) as [Product Year-Month],
	name,
	original_price as product_original_price,
	final_price	   as product_final_price,
	erp_code,
	supplier_color
FROM [$(vpathQVD)products.qvd] (qvd)
WHERE isnull(parent_product_id)
AND
NOT exists (skukey, id);

store products_dimension into $(vpathCube)/product_dimensions_cube.qvd (qvd);

delivery:
Mapping
LOAD * INLINE [
    fast_delivery, delivery
    1, Entrega Rápida
    2, Entrega Normal
];

inventory:
Mapping
LOAD * INLINE [
    inventory_type, inventory
    FATURAMENTO DINDA, Estoque interno
    VIRTUAL DINDA, Consignação
];

campaigns:
LOAD id as campaign_id,
    name as [Campaign Name],
    name as [Campaign Brand],
    slug as campaign_slug,
    Year(ConvertToLocalTime(offer_starts_at,'Brasilia',false())) as [Campaign Start Year],
	MonthName(ConvertToLocalTime(offer_starts_at,'Brasilia',false())) as [Campaign Start Year Month],
	date(Floor(ConvertToLocalTime(offer_starts_at,'Brasilia',false())),'MM/DD') as [Campaign Starts],
	ConvertToLocalTime(offer_starts_at,'Brasilia',false()) as offer_starts_att,
    Year(ConvertToLocalTime(offer_ends_at,'Brasilia',false())) as [Campaign End Year],
	MonthName(ConvertToLocalTime(offer_ends_at,'Brasilia',false())) as [Campaign End Year Month],
	date(Floor(ConvertToLocalTime(offer_ends_at,'Brasilia',false())),'MM/DD') as [Campaign Ends],
	ConvertToLocalTime(offer_ends_at,'Brasilia',false()) as offer_ends_att,
    ApplyMap('inventory',inventory_type,'noinventorytype') as campaign_type,
	ApplyMap('delivery', fast_delivery, 'nodeliverytype') as delivery_type
FROM [$(vpathQVD)campaigns.qvd] (qvd);


LEFT JOIN
LOAD
    campaign_id,
    product_id as campaign_product_id,
    stock as initial_stock
//    campaign_id&'|'&product_id as campaignproductkey
FROM [$(vpathQVD)campaigns_products.qvd] (qvd);

//ENTREGA RÁPIDA A PARTIR DE JULHO 2014
