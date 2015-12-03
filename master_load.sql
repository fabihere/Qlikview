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
