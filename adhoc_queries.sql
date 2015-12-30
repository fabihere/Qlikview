//orders filter

SELECT month(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))) as 'month',
count(id), sum(cached_total_value), sum(shipping_price)
FROM
	orders
WHERE
	state not in
		(
		'auth_failed',
		'cancelled',
		'capture_problems',
		'fraud',
		'risk_analysis_expired',
		'risk_analysis_problems'
		)
and
	origin = 1
and
 date(CONVERT_TZ(created_at, 'UTC', 'America/Sao_Paulo')) between '2015-08-01' and '2015-08-31'
group by month(date(CONVERT_TZ(created_at, 'UTC', 'America/Sao_Paulo')))

//daily sales
select
	date(convert_tz(o.created_at,'UTC','America/Sao_Paulo')) as order_date,
		count(distinct(o.id)),
			sum(cached_total_value) as placed_basket_value,
				sum(shipping_price) as placed_shipping,
					sum(cached_total_value+shipping_price) as placed_order_value,
						sum(captured_shipping_price)
	if(origin=1, 'website',
		if(origin=2, 'iOS',
			if(origin=3, 'third party',
				if(origin=4, 'Android',
			'website mobile')))) as origin
from orders o
where
	date(convert_tz(o.created_at,'UTC','America/Sao_Paulo')) between '2015-10-13' and '2015-10-19'
and
origin in (1,  5)
and
	state not in
		(
		'auth_failed',
		'pending'
		)
group by date(convert_tz(o.created_at,'UTC','America/Sao_Paulo'))
-- where u.source in ('android', 'ios');

//monthly registers

select
year(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))) as 'year',
month(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))) as 'month',
count(id) as 'total users',
origin
from users
group by
	origin,
	month(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))),
	year(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo')))
order by 		year(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))),
month(date(CONVERT_TZ(created_at, 'UTC','America/Sao_Paulo'))), origin

//final order items

SELECT
user_id,
date(CONVERT_TZ(orders.created_at, 'UTC','America/Sao_Paulo')) as 'order_date',
	orders.id as 'order_id',
		state,
		campaign_id,
		variant_id as 'sku',
				name,
					final_price,
								quantity-(cancelled_quantity+stockout_quantity) as 'final_quantity',
										final_price*( quantity-(cancelled_quantity+stockout_quantity) ) as 'basket_value',
											order_items.shipping_price as 'item_shipping_price',
											(final_price*( quantity-(cancelled_quantity+stockout_quantity) ))+order_items.shipping_price as 'final_value'
FROM
	orders, order_items
WHERE
	orders.id = order_items.order_id
and
	state not in
		(
		'auth_failed',
		'cancelled',
		'cancelled_stockout',
		'capture_problems',
		'fraud',
		'risk_analysis_expired',
		'risk_analysis_problems'
		)
and
 date(CONVERT_TZ(orders.created_at, 'UTC', 'America/Sao_Paulo')) between '2015-08-01' and '2015-10-31'
and
quantity-(cancelled_quantity+stockout_quantity) > 0
order by orders.id

//orders by utm

select
	masked_id,
	date(convert_tz(o.created_at,'UTC','America/Sao_Paulo')) as order_date,
	sum(cached_total_value) as placed_basket_value,
	sum(shipping_price) as placed_shipping,
	sum(cached_total_value+shipping_price) as placed_order_value,
	state,
	if(origin=1, 'website',
		if(origin=2, 'iOS',
			if(origin=3, 'third party',
				if(origin=4, 'Android',
			'website mobile')))) as origin,
		utm_id,
		source,
			campaign,
				medium,
					term,
						gclid
from orders o
left join utms u on o.utm_id = u.id
where
 state not in
		(
		'auth_failed',
		'cancelled',
		'capture_problems',
		'fraud',
		'risk_analysis_expired',
		'risk_analysis_problems'
		)
and origin not in ('2','4')
and
date(convert_tz(o.created_at,'UTC','America/Sao_Paulo')) between '2015-01-01' and '2015-11-17'
group by masked_id
order by date(convert_tz(o.created_at,'UTC','America/Sao_Paulo'))
-- where u.source in ('android', 'ios')

//monthly orders

select month(date(CONVERT_TZ(order_items.created_at, 'UTC', 'America/Sao_Paulo'))),
count(distinct(order_items.product_id))
from order_items, orders
WHERE
	order_items.order_id = orders.id
and
	orders.state not in
		(
		'auth_failed',
		'cancelled',
		'capture_problems',
		'fraud',
		'risk_analysis_expired',
		'risk_analysis_problems'
		)
and date(CONVERT_TZ(order_items.created_at, 'UTC', 'America/Sao_Paulo')) >= '2015-01-01'
group by month(date(CONVERT_TZ(order_items.created_at, 'UTC', 'America/Sao_Paulo')))

//users with utms

select
	date(convert_tz(users.created_at,'UTC','America/Sao_Paulo')) as 'date',
	users.id as 'user ID',
	source,
	medium
FROM
	users
LEFT JOIN utms
ON users.utm_id = utms.id
WHERE
	date(convert_tz(users.created_at,'UTC','America/Sao_Paulo')) between '2015-10-01' and '2015-10-31'
