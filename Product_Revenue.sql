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



ODBC CONNECT TO [MySQL Dinda BI] (XUserId is NHFHFRFNfCZSGXRMBTfB, XPassword is BCHcERFNELacGSFMSBMCDaUH);



Set vpathQVD='D:\QlikView\DataSource\';
Set vpathDoc='D:\QlikView\ETL Files\Dashboard_Comercial\';
///$tab Load QVDs
orders:
LOAD id,
    `created_at`,
    `updated_at`,
    `shipping_price`,
    state,
    `cached_final_value`,
    `cached_total_value`,
    `cached_credits`

FROM [$(vpathQVD)orders.qvd] (qvd);

STORE orders into [$(vpathDoc)orders.qvd] (qvd);

drop table orders;

order_items:
LOAD id,
    `product_id`,
    name,
    quantity,
    `final_price`,
    `created_at`,
    `updated_at`,
    `order_id`,
    `variant_id`,
    `original_price`,
    `cancelled_quantity`,
    `campaign_id`,
    `stockout_quantity`,
    `shipping_price`

FROM [$(vpathQVD)order_items.qvd] (qvd);

STORE order_items into [$(vpathDoc)order_items.qvd] (qvd);

drop table order_items;

campaigns_products:
LOAD id,
    `product_id`,
    `campaign_id`,
    stock

FROM [$(vpathQVD)campaigns_products.qvd] (qvd);

STORE campaigns_products into [$(vpathDoc)campaigns_products.qvd] (qvd);

drop table campaigns_products;

products:
LOAD id,
    `brand_id`,
	`created_at`,
    `parent_product_id`,
    `main_category_id`,
    `category_id`,
    `vertical_id`,
    `gender_id`,
    `subcategory_id`,
    `age_id`,
    `size_id`,
    `supplier_size`

FROM [$(vpathQVD)products.qvd] (qvd);
STORE products into [$(vpathDoc)products.qvd] (qvd);

drop table products;

campaigns:
LOAD id,
    name,
    slug,
    `offer_starts_at`,
    `offer_ends_at`,
    `brand_id`,
    exclusive,
    kids,
    `inventory_type`,
    `fast_delivery`
FROM [$(vpathQVD)campaigns.qvd] (qvd);

STORE campaigns into [$(vpathDoc)campaigns.qvd] (qvd);

drop table campaigns;

brands:
LOAD id,
    name,
    slug

FROM [$(vpathQVD)brands.qvd] (qvd);

STORE brands into [$(vpathDoc)brands.qvd] (qvd);

drop table brands;

tags:
LOAD id,
    type,
    label
FROM [$(vpathQVD)tags.qvd] (qvd);

STORE tags into [$(vpathDoc)tags.qvd] (qvd);

drop table tags;
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

Let vGrossQuant = 'sum([Order Quantity])';
Let vCancelledQuant = 'sum([Cancelled Quantity])';
Let vStockoutQuant = 'sum([Stockout Quantity])';
Let vLiquidQuant = '$(vGrossQuant)-($(vCancelledQuant)+$(vStockoutQuant))';
Let vFinalPrice = 'final_price';
Let vOriginalPrice = '[Original Price]';
Let vTotalValue = '($(vLiquidQuant))*$(vPrice)';
Let vDiscount = '(($(vFinalPrice)/$(vOriginalPrice))-1)';
Let vInitialStock = 'sum([Initial Stock])';
///$tab Teste
////products_load:
//LOAD *
//FROM [$(vpathQVD)brands.qvd] (qvd);
//
//
//
//exit Script;
///$tab Load Filtered QVDs
orders_load:
LOAD *
FROM [$(vpathQVD)orders.qvd] (qvd);

order_items_load:
LOAD *
FROM [$(vpathQVD)order_items.qvd] (qvd);

campaigns_products_load:
LOAD *
FROM [$(vpathQVD)campaigns_products.qvd] (qvd);

campaigns_load:
LOAD *
FROM [$(vpathQVD)campaigns.qvd] (qvd);

products_load:
LOAD *
FROM [$(vpathQVD)products.qvd] (qvd);

brands_load:
LOAD *
FROM [$(vpathQVD)brands.qvd] (qvd);

tags_load:
LOAD *
FROM [$(vpathQVD)tags.qvd] (qvd);
///$tab Filter Order Items
//filter out failed states from orders

consider:
Mapping
LOAD state,
     consider
FROM
D:\QlikView\Dados\Dropbox\Qlikview\orderstate.xlsx
(ooxml, embedded labels, table is Sheet1);

getorderstate:
LOAD id as order_id,
    state,
    ApplyMap('consider',state,'error') as consider
Resident orders_load;

drop table orders_load;

orderfilter:
LOAD order_id,
	state
Resident getorderstate
where consider <> 'no';

left join
LOAD order_id,
	id,
    product_id,
    name,
    quantity,
    final_price,
    created_at,
    updated_at,
    variant_id,
    original_price,
    cancelled_quantity,
    campaign_id,
    stockout_quantity,
    shipping_price
Resident order_items_load;

drop table getorderstate;
drop table order_items_load;


//created order items table with only relevant ("considered") orders:

filtered_order_items:
LOAD
     id as order_items_id,
    product_id,
    name as order_items_name,
    quantity,
    final_price,
    ConvertToLocalTime(created_at,'Brasilia',false()) as order_items_created_att,
	date(Floor(    ConvertToLocalTime(created_at,'Brasilia',false()))) as [Order Date],
	MonthName(    ConvertToLocalTime(created_at,'Brasilia',false())) as [Order Month Year],
	Year(    ConvertToLocalTime(created_at,'Brasilia',false())) as [Order Year],
    ConvertToLocalTime(updated_at,'Brasilia',false())as order_items_updated_att,
    order_id,
    variant_id,
    variant_id as productkey,
    original_price,
    cancelled_quantity,
    campaign_id,
    stockout_quantity,
    shipping_price as order_items_shipping_price,
    campaign_id&'|'&variant_id as campaignproductkey
Resident orderfilter;

drop table orderfilter;

order_items:
LOAD
	order_items_id,
    product_id as [Product ID],
    order_items_name as [Product Name],
    quantity,
    quantity as [Order Quantity],
    final_price,
    final_price as [Final Price],
	order_items_created_att,
	Day(order_items_created_att) as [Order Day],
	Month(order_items_created_att) as [Order Month],
	date(	[Order Date],'MM/DD') as [Date],
	date([Order Date],'YYYY-MM') as [Year-Month],
	[Order Date],
	num(month([Order Date]),'00')&'-'&num(year([Order Date])) as [Order Year-Month],
	[Order Year],
	order_items_updated_att,
    order_id as [Order ID],
    variant_id as Variant,
    productkey,
    original_price as [Original Price],
    cancelled_quantity,
    cancelled_quantity as [Cancelled Quantity],
    campaign_id,
    stockout_quantity,
    stockout_quantity as [Stockout Quantity],
    order_items_shipping_price as [Shipping],
	campaignproductkey
Resident filtered_order_items;

drop table filtered_order_items;





///$tab Load Stock from Campaigns Products
//pull stock data from campaigns_products table:

campaigns_products:
LOAD
    stock as [Initial Stock],
    campaign_id&'|'&product_id as campaignproductkey
Resident campaigns_products_load;

drop table campaigns_products_load;
///$tab Load Tags
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
Resident tags_load;
drop table tags_load;

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
Resident brands_load;
drop table brands_load;

brandtag:
Mapping
LOAD brand_id,
    name as brand_name
Resident brands;

drop table brands;
///$tab Product and SKU Details
products_dimension:
//load variant-level dimensions first then left join with sku-level dimensions
LOAD
    id,
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
RESIDENT products_load
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
RESIDENT products_load;

CONCATENATE
LOAD
	id,
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

	// Adicionado por David Bernardi - 08/12/15
	name,
	original_price as product_original_price,
	final_price	   as product_final_price,
	erp_code,
	supplier_color
RESIDENT products_load
WHERE isnull(parent_product_id)
AND
NOT exists (skukey, id);

drop table products_load;


// Adicionado por David Bernardi - qvd vai ser utilizado na app Dashboard Campanhas.
store products_dimension into $(vpathQVD)/products_dimension.qvd (qvd);

///$tab Campaign Name
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

Resident campaigns_load;

drop table campaigns_load;

//ENTREGA RÁPIDA A PARTIR DE JULHO 2014

///$tab Reference - other versions
//skus_load:
//LOAD
//    id,
//    id as variantkey,
//    `parent_product_id` as skukey
//
//FROM [$(vpathQVD)products.qvd] (qvd)
//WHERE NOT isnull(parent_product_id);
//
//LEFT JOIN
//LOAD
//	id as skukey,
//	category_id,
//	brand_id,
//	gender_id
//FROM [$(vpathQVD)products.qvd] (qvd);
//
//Concatenate
//
//LOAD
//	id,
//	id as variantkey,
//	id as skukey,
//	category_id,
//	brand_id,
//	gender_id
//FROM [$(vpathQVD)products.qvd] (qvd)
//WHERE isnull(parent_product_id)
//AND
//NOT exists (skukey, id);

//products_dimension:
//LOAD
//	id,
//	brand_id,
//	applymap('brandtag',brand_id,'none') as brand_name,
//	id as variantkey,
//    parent_product_id,
//    applymap('agetag',age_id,'none') as [Age Group],
//	applymap('sizetag',    size_id,	'none') as Size,
//	supplier_size as [Supplier Size]
//Resident products_load
//WHERE not isnull(parent_product_id);
//
//skus_filter:
//Load
//	if(isnull(parent_product_id),id,parent_product_id) as skukey,
//	if(isnull(parent_product_id),1,0) as test,
//	category_id,
//	vertical_id,
//	gender_id,
//	subcategory_id
//Resident products_load;
//
//drop table products_load;
//
//skus:
//Load
//	skukey,
//	applymap('categorytag',    category_id,'none') as category,
//	applymap('verticaltag',    vertical_id, 'none') as vertical,
//	ApplyMap('gendertag',    gender_id,'none') as gender,
//	ApplyMap('subcategorytag',    subcategory_id,'none') as subcategory
//Resident skus_filter
//Where test = 1;
//
//drop table skus_filter;
//
//skus_dimension:
//Load
//	skukey,
//	category as Category,
//	vertical as Segment,
//	gender as Gender,
//	subcategory as Subcategory
//
//Resident skus;
//
//
//
