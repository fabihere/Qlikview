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
set vpathBU='E:\Qlikview\Backup\';

orders:
LOAD id,
    `user_id`,
    `address_id`,
    `payment_method`,
    installments,
    status,
    `created_at`,
    `updated_at`,
    `credit_card_operator`,
    `paid_at`,
    `payment_status`,
    `shipping_price`,
    `shipping_period`,
    state,
    `shipping_company_code`,
    `shipping_company_name`,
    `total_shipping_time`,
    `utm_id`,
    `cached_final_value`,
    `cached_total_value`,
    `cached_credits`,
    `stock_state`,
    `cancellation_description`,
    `cached_value_before_reserve`,
    `cached_final_value_before_reserve`,
    `created_in_erp`,
    `transaction_id`,
    `masked_id`,
    `external_id`,
    origin,
    `coupon_id`,
    `delivered_at`,
    `boleto_expiration_date`,
    `interest_rate`,
    `interest_value`,
    `captured_interest_value`;
SQL SELECT id,
    `user_id`,
    `address_id`,
    `payment_method`,
    installments,
    status,
    `created_at`,
    `updated_at`,
    `credit_card_operator`,
    `paid_at`,
    `payment_status`,
    `shipping_price`,
    `shipping_period`,
    state,
    `shipping_company_code`,
    `shipping_company_name`,
    `total_shipping_time`,
    `utm_id`,
    `cached_final_value`,
    `cached_total_value`,
    `cached_credits`,
    `stock_state`,
    `cancellation_description`,
    `cached_value_before_reserve`,
    `cached_final_value_before_reserve`,
    `created_in_erp`,
    `transaction_id`,
    `masked_id`,
    `external_id`,
    origin,
    `coupon_id`,
    `delivered_at`,
    `boleto_expiration_date`,
    `interest_rate`,
    `interest_value`,
    `captured_interest_value`
FROM `dinda_prd`.orders;

store orders into [$(vpathQVD)orders.qvd] (qvd);
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
    `shipping_price`,
    `stockout_shipping_price`;
SQL SELECT id,
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
    `shipping_price`,
    `stockout_shipping_price`
FROM `dinda_prd`.`order_items`;

store order_items into [$(vpathQVD)order_items.qvd] (qvd);

drop table order_items;

campaigns_products:
LOAD id,
    `product_id`,
    `campaign_id`,
    stock,
    sold,
    active,
    `created_at`,
    `updated_at`,
    `cost_price`,
    icms;
SQL SELECT id,
    `product_id`,
    `campaign_id`,
    stock,
    sold,
    active,
    `created_at`,
    `updated_at`,
    `cost_price`,
    icms
FROM `dinda_prd`.`campaigns_products`;

Store campaigns_products into [$(vpathQVD)campaigns_products.qvd] (qvd);

drop table campaigns_products;

campaigns:
LOAD id,
    name,
    description,
    slug,
    `short_description`,
    `offer_starts_at`,
    `offer_ends_at`,
    `logo_from_s3`,
    `highlight_from_s3`,
    `mini_logo_from_s3`,
    banner,
    `brand_id`,
    `created_at`,
    `updated_at`,
    exclusive,
    kids,
    `supplier_time`,
    `warehouse_time`,
    `stock_out`,
    `inventory_id`,
    `inventory_type`,
    `ends_exclusive_at`,
    `fast_delivery`,
    `scheduled_home_highlight`,
    `home_highlight_description`;
SQL SELECT id,
    name,
    description,
    slug,
    `short_description`,
    `offer_starts_at`,
    `offer_ends_at`,
    `logo_from_s3`,
    `highlight_from_s3`,
    `mini_logo_from_s3`,
    banner,
    `brand_id`,
    `created_at`,
    `updated_at`,
    exclusive,
    kids,
    `supplier_time`,
    `warehouse_time`,
    `stock_out`,
    `inventory_id`,
    `inventory_type`,
    `ends_exclusive_at`,
    `fast_delivery`,
    `scheduled_home_highlight`,
    `home_highlight_description`
FROM `dinda_prd`.campaigns;

store campaigns into [$(vpathQVD)campaigns.qvd] (qvd);

drop table campaigns;

products:
LOAD id,
    name,
    description,
    `original_price`,
    `final_price`,
    slug,
    `brand_id`,
    `created_at`,
    `updated_at`,
    `main_picture_id`,
    quantity,
    priority,
    `parent_product_id`,
    `erp_code`,
    guarantee,
    active,
    `main_category_id`,
    `shipping_period`,
    stock,
    sold,
    `cached_quantity`,
    `current_campaign_id`,
    `category_id`,
    `vertical_id`,
    `gender_id`,
    `subcategory_id`,
    `age_id`,
    `size_id`,
    `supplier_size`;
SQL SELECT id,
    name,
    description,
    `original_price`,
    `final_price`,
    slug,
    `brand_id`,
    `created_at`,
    `updated_at`,
    `main_picture_id`,
    quantity,
    priority,
    `parent_product_id`,
    `erp_code`,
    guarantee,
    active,
    `main_category_id`,
    `shipping_period`,
    stock,
    sold,
    `cached_quantity`,
    `current_campaign_id`,
    `category_id`,
    `vertical_id`,
    `gender_id`,
    `subcategory_id`,
    `age_id`,
    `size_id`,
    `supplier_size`
FROM `dinda_prd`.products;

store products into [$(vpathQVD)products.qvd] (qvd);

drop table products;

brands:
LOAD id,
    name,
    slug,
    `created_at`,
    `updated_at`,
    featured,
    `erp_code`,
    active,
    `importing_from_erp`,
    `stock_out`,
    `supplier_time`,
    `warehouse_time`,
    kids,
    exclusive;
SQL SELECT id,
    name,
    slug,
    `created_at`,
    `updated_at`,
    featured,
    `erp_code`,
    active,
    `importing_from_erp`,
    `stock_out`,
    `supplier_time`,
    `warehouse_time`,
    kids,
    exclusive
FROM `dinda_prd`.brands;

store brands into [$(vpathQVD)brands.qvd] (qvd);

drop table brands;

tags:
LOAD id,
    type,
    label,
    `created_at`,
    `updated_at`,
    slug,
    enabled;
SQL SELECT id,
    type,
    label,
    `created_at`,
    `updated_at`,
    slug,
    enabled
FROM `dinda_prd`.tags;

store tags into [$(vpathQVD)tags.qvd] (qvd);

drop table tags;

users:
LOAD id,
    email,
    `sign_in_count`,
    `current_sign_in_at`,
    `last_sign_in_at`,
    `confirmed_at`,
    `unconfirmed_email`,
    `created_at`,
    `updated_at`,
    `first_name`,
    `last_name`,
    gender,
    subscribed,
    cpf,
    phone,
    birthdate,
    `main_address_id`,
    approved,
    `utm_id`,
    `deactivated_at`,
    origin,
    `vip_since`,
    `most_recent_access`;
SQL SELECT id,
    email,
    `sign_in_count`,
    `current_sign_in_at`,
    `last_sign_in_at`,
    `confirmed_at`,
    `unconfirmed_email`,
    `created_at`,
    `updated_at`,
    `first_name`,
    `last_name`,
    gender,
    subscribed,
    cpf,
    phone,
    birthdate,
    `main_address_id`,
    approved,
    `utm_id`,
    `deactivated_at`,
    origin,
    `vip_since`,
    `most_recent_access`
FROM `dinda_prd`.users;

store users into [$(vpathQVD)users.qvd] (qvd);

drop table users;

utms:
LOAD id,
    source,
    campaign,
    medium,
    term,
    content,
    `created_at`,
    `updated_at`,
    gclid;
SQL SELECT id,
    source,
    campaign,
    medium,
    term,
    content,
    `created_at`,
    `updated_at`,
    gclid
FROM `dinda_prd`.utms;

store utms into [$(vpathQVD)utms.qvd] (qvd);

drop table utms;

annotations:
LOAD id,
    `target_type`,
    `target_id`,
    subject,
    data;
SQL SELECT id,
    `target_type`,
    `target_id`,
    subject,
    data
FROM `dinda_prd`.annotations;


store annotations into [$(vpathQVD)annotations.qvd] (qvd);

drop table annotations;

categories:
LOAD id,
    name,
    `created_at`,
    `updated_at`,
    slug,
    `parent_category`;
SQL SELECT id,
    name,
    `created_at`,
    `updated_at`,
    slug,
    `parent_category`
FROM `dinda_prd`.categories;

store categories into [$(vpathQVD)categories.qvd] (qvd);

drop table categories;

risk_analysis_results:
LOAD id,
    `order_id`,
    blacklist,
    `successful_past_order_rule`,
    `maximum_order_value_rule`,
    `maximum_of_purchase_on_period_rule`,
    `risk_analysis`;
SQL SELECT id,
    `order_id`,
    blacklist,
    `successful_past_order_rule`,
    `maximum_order_value_rule`,
    `maximum_of_purchase_on_period_rule`,
    `risk_analysis`
FROM `dinda_prd`.`risk_analysis_results`;

store risk_analysis_results into [$(vpathQVD)risk_analysis_results.qvd] (qvd);

drop table risk_analysis_results;

order_transition_logs:
LOAD id,
    `from`,
    `to`,
    `order_id`,
    `created_at`;
SQL SELECT id,
    `from`,
    `to`,
    `order_id`,
    `created_at`
FROM `dinda_prd`.`order_transition_logs`;

store order_transition_logs into [$(vpathQVD)order_transition_logs.qvd] (qvd);

drop table order_transition_logs;

tracking_infos:
LOAD id,
    `tax_invoice_number`,
    `erp_order_internal_number`,
    `erp_object_number`,
    `shipping_company_name`,
    `order_id`,
    `created_at`,
    `updated_at`;
SQL SELECT id,
    `tax_invoice_number`,
    `erp_order_internal_number`,
    `erp_object_number`,
    `shipping_company_name`,
    `order_id`,
    `created_at`,
    `updated_at`
FROM `dinda_prd`.`tracking_infos`;


store tracking_infos into [$(vpathQVD)tracking_infos.qvd] (qvd);

drop table tracking_infos;
