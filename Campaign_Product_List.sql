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

Set vpathFinanceiro='D:\QlikView\Dados\Dropbox\Product List\';

Set vpathQVD='D:\QlikView\DataSource\';
set vpathETL='D:\QlikView\DataETL\';
set vpathDropbox='D:\QlikView\Dados\Dropbox\Product List\';

let vShowCS = 0;
///$tab Load Filtered QVDs
products:
MAPPING
LOAD id as variant_id,
    erp_code
FROM [$(vpathQVD)products.qvd] (qvd);

order_items_1:
LOAD
	variant_id,
	text(ApplyMap('products',variant_id,'no id')) as [Product ID Abacos],
	campaign_id,
	order_id
FROM [$(vpathQVD)order_items.qvd] (qvd);

LEFT JOIN
LOAD
	id as order_id,
	text(external_id) as [Order ID Abacos],
	floor(date(ConvertToLocalTime(created_at,'Brasilia',false()))) as [Order Date],
	num(year(ConvertToLocalTime(created_at,'Brasilia',false())))&'-'&num(month(ConvertToLocalTime(created_at,'Brasilia',false())),'00') as [Order Year-Month]
FROM [$(vpathQVD)orders.qvd] (qvd);

LEFT JOIN
LOAD
	id as campaign_id,
    name as [Campaign Name],
	date(ConvertToLocalTime(    `offer_starts_at`,'Brasilia',false())) as [Campaign Starts],
	date(ConvertToLocalTime(    `offer_ends_at`,'Brasilia',false())) as [Campaign Ends]
FROM [$(vpathQVD)campaigns.qvd] (qvd);

order_items:
LOAD
	variant_id,
	[Product ID Abacos],
	campaign_id,
	order_id,
	[Order ID Abacos],
	[Order Date],
	[Order Year-Month],
	[Campaign Name],
	[Campaign Starts],
	[Campaign Ends],
	[Order ID Abacos]&'|'&[Product ID Abacos],
	[Order ID Abacos]&'|'&[Product ID Abacos] as [Order ID Abacos|Product ID Abacos]
RESIDENT order_items_1;
drop table order_items_1;

Store order_items into [$(vpathQVD)campaign_product_list.qvd] (qvd);


//Export:
export:
LOAD
	[Order ID Abacos],
	[Product ID Abacos],
	campaign_id as [Campaign ID],
	[Campaign Name],
	[Campaign Starts],
	[Campaign Ends]
Resident order_items
WHERE MonthName([Order Date]) = MonthName(today());

Store export into [$(vpathDropbox)Productlist_todate.csv] (txt);

drop table export;
///$tab orders
order_items1:
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
Resident order_items1
Group by order_id;

drop table order_items1;

shipped:
LOAD
	order_id,
	date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as shipping_date
from [$(vpathQVD)order_transition_logs.qvd] (qvd)
where to = 'shipping_successful';

orders:
Load
	id as order_id
FROM [$(vpathQVD)orders.qvd] (qvd)
WHERE NOT match(state, 'auth_failed','cancelled','capture_problems', 'fraud', 'risk_analysis_expired', 'risk_analysis_problems');

LEFT JOIN
Load id as order_id,
	id as admin_order_id,
	date(	floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as order_date_1,
    state,
    external_id as abacos_id,
    shipping_period,
    total_shipping_time,
    date(ConvertToLocalTime(created_at,'Brasilia',false())+total_shipping_time,'MM/DD/YYYY') as communicated_delivery_date,
    date(ConvertToLocalTime(delivered_at)) as delivered_at,
    if(isnull	(delivered_at)and state = 'shipping_successful','no delivery data',if(isnull	(delivered_at),'not delivered',date(ConvertToLocalTime(delivered_at)))) as actual_delivery_date
//   	if(isnull	(delivered_at)and state = 'shipping_successful',date(ConvertToLocalTime(created_at,'Brasilia',false())+shipping_period,'MM/DD/YYYY'),
//   		if(isnull	(delivered_at),'not delivered',date(ConvertToLocalTime(delivered_at)))) as full_delivery_data
FROM [$(vpathQVD)orders.qvd] (qvd);

LEFT JOIN
Load
	order_id,
	shipping_date
Resident shipped;


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

drop field order_id from orders;

drop table orders1;

orders2:
LOAD
	*,
	if(match(state, 'shipping_successful','delivered'),date(shipping_date+shipping_period,'MM/DD/YYYY'),'not delivered') as estimated_delivery_date
Resident orders;

drop table orders;

orders3:
LOAD
	*,
	if(actual_delivery_date='no delivery data' and not isnull(shipping_date),estimated_delivery_date,
		if(actual_delivery_date='no delivery data' and isnull(shipping_date),communicated_delivery_date,
			if(actual_delivery_date='not delivered','not delivered',actual_delivery_date))) as full_delivery_data
Resident orders2;

drop table orders2;

drop table shipped;
//
//on_time:
//LOAD
//	abacos_id,
//	if(full_delivery_data = 'not delivered','not delivered',if(actual_delivery_date<=communicated_delivery_date,'delivered on time','delivered with delay')as on_time_status
//Resident orders3;


//
//temp:
//LOAD
//	order_id,
//	if(isnull(Previous(user_id)),1,
//		if(user_id=Previous(user_id) and order_date > previous(order_date), peek('RowNumber')+1,
//			if(user_id <> Previous(user_id) and order_date > previous(order_date), 1))) as Rownumber,
//			AutoNumber(order_id,user_id) as test
//Resident orders;
//
//Store orders into [$(vpathCube)orderscube.qvd] (qvd);
///$tab CLEARSALE
risk_analysis_load:
LOAD id,
    order_id,
//    blacklist,
//    if(blacklist=0,'Blacklisted','Not Blacklisted') as blacklist_result,
    successful_past_order_rule,
	if(successful_past_order_rule=0,'Clearsale','Whitelist') as successful_past_order_rule_result,
    maximum_order_value_rule,
    if(maximum_order_value_rule=0,'Clearsale','Whitelist') as maximum_order_value_rule_result,
    maximum_of_purchase_on_period_rule,
    if(maximum_of_purchase_on_period_rule=0,'Clearsale','Whitelist') as maximum_of_purchase_on_period_rule_result
//    risk_analysis,
//    if(risk_analysis=0,'Failed',if(risk_analysis=1,'Approved','Null')) as risk_analysis_result
FROM [$(vpathQVD)risk_analysis_results.qvd] (qvd);

//REMOVE BLACKLIST INFO - NOT NEEDED

//LOAD
//	order_id,
//	'Blacklist Rule' as rule,
//	blacklist_result as rule_applies,
//	risk_analysis_result as clearsale_result
//Resident risk_analysis_load
//Where NOT isnull(blacklist);

FTPs:
Mapping
load
	first_order_id as id,
	'yes' as FTP
FROM [$(vpathETL)ftbs.qvd] (qvd);


risk_analysis_table:
LOAD
	order_id,
	'Rule 1' as Rule,
	successful_past_order_rule_result as rule_applies
Resident risk_analysis_load
Where NOT isnull(successful_past_order_rule);

LOAD
	order_id,
	'Rule 2' as Rule,
	maximum_order_value_rule_result as rule_applies
Resident risk_analysis_load
Where NOT isnull(maximum_order_value_rule);

LOAD
	order_id,
	'Rule 3' as Rule,
	maximum_of_purchase_on_period_rule_result as rule_applies
Resident risk_analysis_load
Where NOT isnull(maximum_of_purchase_on_period_rule);

LEFT JOIN
LOAD
	id as order_id,
	ApplyMap('FTPs',id,'no') as FTP,
	date(floor(ConvertToLocalTime(created_at,'Brasilia',false())),'MM/DD/YYYY') as order_date,
	date(monthstart(ConvertToLocalTime(created_at,'Brasilia',false())),'YYYY-MM') as order_cohort,
    external_id
FROM [$(vpathQVD)orders.qvd] (qvd)
WHERE exists(order_id, id);

drop table risk_analysis_load;

//drop field
//
//LOAD
//	order_id,
//	FTP
//Resident temp;
//
//Drop table temp;

clearsale:
Mapping
LOAD
	order_id,
	FirstValue(rule_applies) as Clearsale
Resident risk_analysis_table
WHERE rule_applies = 'Clearsale'
Group by order_id;

LEFT JOIN (risk_analysis_table)
LOAD
	order_id,
	ApplyMap('clearsale',order_id,'Whitelist') as final_list,
	1 as risk_analysis_data
Resident risk_analysis_table;


rule_description:
LOAD * INLINE [
    Rule, English, Description
    Rule 1, Successful past order rule, Pedido não tem histórico do cliente com o mesmo cartão de crédito nos últimos 45 dias*
    Rule 2, Maximum order value rule, Pedido tem um valor maior que R$700
    Rule 3, Maximum of purchase in period rule, Pedido deu um valor acumulado maior que R$2K no período de 7 dias para o mesmo cliente
];





///$tab Export
//maxMonth:
//LOAD date(max([Order Date])) as maxdate
//Resident order_items;
//
//let maxMonth = date(peek('maxdate',-1,'maxMonth'));
//
////export:
////LOAD
////	[Order ID Abacos],
////	[Product ID Abacos],
////	[Campaign Name],
////	[Campaign Starts],
////	[Campaign Ends]
////RESIDENT order_items
////Where MonthName([Order Date]) >= MonthName($(maxMonth));
////
////store export into [$(vpathFinanceiro)productslist-$(maxMonth).csv] (txt, delimiter is ',');
////
////drop table export;
////
//////drop table maxMonth;

///$tab TROUBLESHOOTING
//troubleshoot:
//LOAD
//     Camp,
//     [Produto - Marca],
//     [Item - Valor nota],
//     text([Pedido - Nro])&'|'&text([Sku filho]) as [Order ID Abacos|Product ID Abacos],
//     1 as troubleshoot
//FROM
//[D:\QlikView\Dados\Dropbox\Product List\Combinação pedido e produto não encontrado em sku.xlsx]
//(ooxml, embedded labels, table is Query1);
//
