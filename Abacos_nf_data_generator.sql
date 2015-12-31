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

LET pathSource = 'D:\QlikView\Dados\Dropbox\Qlikview\Abacos\*.txt';

for each file in FileList(pathSource);

generate_files_abacos:
LOAD [Cliente - Código interno],
     [Pedido - Número],
     [NF - Número],
     [NF - Série],
     Date( Date#([NF - Data emissão], 'DD/MM/YYYY'), 'MM/DD/YYYY') as [NF Data emissão],
     [NF - Data emissão],
     [NF - Data e hora de emissão],
     [Pedido - Código],
     [NF - Vlr. Mercadorias + Serviços],
     [NF - Vlr. Frete],
     [NF - Vlr. Nota],
     [Cliente - E-Mail],
     [Cliente - CNPJ/CFP]
FROM $(file) ;

next file;


abacos:
Load [Pedido - Número] as abacos_order_id,
	mid([Pedido - Número],3) as order_id,
	[NF - Vlr. Nota] as nf_total_value,
	[NF - Vlr. Mercadorias + Serviços] as nf_shopping_bag_value,
     [NF - Vlr. Frete] as nf_shipping_value,
		[NF Data emissão] as nf_date,
		 [NF - Número] as nf_number,
	if(mid(      [Cliente - CNPJ/CFP],1,3)<> '000', 'erro no cpf', num(mid(      [Cliente - CNPJ/CFP],4))) as nf_cpf,
         [Cliente - E-Mail] as abacos_email
Resident generate_files_abacos
where NOT [Pedido - Número] LIKE '*DI*';

//STORE ABACOS DATA WITHOUT PROJECTIONS
store abacos into [$(vpathQVD)abacos_nfs.qvd] (qvd);
