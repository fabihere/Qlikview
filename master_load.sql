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
    `created_at`,
    `updated_at`,
    `credit_card_operator`,
    `shipping_price`,
    state,
    `shipping_company_code`,
    `shipping_company_name`,
    `utm_id`,
    `cached_final_value`,
    `cached_total_value`,
    `cached_credits`,
    `cancellation_description`,
    `cached_value_before_reserve`,
    `cached_final_value_before_reserve`,
    origin,
    `captured_shipping_price`,
    `coupon_id`,
    `masked_id`,
    `external_id`;
SQL SELECT id,
    `user_id`,
    `address_id`,
    `payment_method`,
    installments,
    `created_at`,
    `updated_at`,
    `credit_card_operator`,
    `shipping_price`,
    state,
    `shipping_company_code`,
    `shipping_company_name`,
    `utm_id`,
    `cached_final_value`,
    `cached_total_value`,
    `cached_credits`,
    `cancellation_description`,
    `cached_value_before_reserve`,
    `cached_final_value_before_reserve`,
    origin,
    `captured_shipping_price`,
    `coupon_id`,
    `masked_id`,
    `external_id`
FROM `dinda_prd`.orders;

store orders into [$(vpathQVD)orders.qvd] (qvd);
drop table orders;
