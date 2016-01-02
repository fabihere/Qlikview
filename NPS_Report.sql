SET ThousandSep=',';
SET DecimalSep='.';
SET MoneyThousandSep=',';
SET MoneyDecimalSep='.';
SET MoneyFormat='$#,##0.00;($#,##0.00)';
SET TimeFormat='h:mm:ss TT';
SET DateFormat='MM/DD/YYYY';
SET TimestampFormat='YYYY-MM-DD h:mm:ss[.fff] TT';
SET MonthNames='Jan;Feb;Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec';
SET DayNames='Mon;Tue;Wed;Thu;Fri;Sat;Sun';

npsresults:


LOAD EMAIL_ADDRESS_,
     date(floor(DATA_DA_RESPOSTA)) as DATA_DA_RESPOSTA,
     MonthName(     DATA_DA_RESPOSTA) as MES_ANO_DA_RESPOSTA,
     NOTA_NPS,
     if( NOTA_NPS >=9,'Promoters',if(NOTA_NPS<7,'Detractors','Passives')) as GRUPO_NPS,
     MOTIVO,
     SUGESTAO,
     RIID_,
     CREATED_DATE_,
     MODIFIED_DATE_,
     CAMPAIGN_NAME,
     CUSTOMER_ID_,
     ORDER_ID,
     if(today()-DATA_DA_RESPOSTA<=30,1,0) as LAST_30_DAYS
FROM
[D:\QlikView\Dados\Dropbox\NPS\Responsys Export\npsresults.csv]
(txt, utf8, embedded labels, delimiter is '|')
Where Match(NOTA_NPS,0,1,2,3,4,5,6,7,8,9,10)
and DATA_DA_RESPOSTA> '2015-01-31';
