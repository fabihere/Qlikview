///$tab Default
SET ThousandSep='.';
SET DecimalSep=',';
SET MoneyThousandSep='.';
SET MoneyDecimalSep=',';
SET MoneyFormat='R$ #.##0,00;-R$ #.##0,00';
SET TimeFormat='hh:mm:ss';
SET DateFormat='DD/MM/YYYY';
SET TimestampFormat='DD/MM/YYYY hh:mm:ss[.fff]';
SET MonthNames='jan;fev;mar;abr;mai;jun;jul;ago;set;out;nov;dez';
SET DayNames='seg;ter;qua;qui;sex;sáb;dom';

set qvdDir = D:\QlikView\Dados\QVD\Admin\;
set dump_export_dir = D:\QlikView\Dados\Dropbox\Order Cardinal\;

//ODBC CONNECT TO [Base site] (XUserId is HdOJKZdNPDdUM);

///$tab MySQL queries - nova
 //conexão ao banco
ODBC CONNECT TO dindabimy (XUserId is QcAYDRFNfCZSGXRMBLeB, XPassword is cRSTARFNELacGSFMSBMCDaEU);

 //PRODUTOS IMAGENS
	products:
	sql select
		id,
		erp_code,
		main_category_id,
		main_picture
	from `dinda_prd`.products;

	produtosImagens:
	load id as produtoCodigoPai,
		 firstvalue(main_picture) as produtoImagem
	resident products
	where not isnull(main_picture)
	group by id;

	store produtosImagens into $(qvdDir)produtosImagens.qvd (qvd);
	drop table produtosImagens;



//ITENS
	order_items:
	load
		id as itemId,
		order_id as 'ID Pedido',
		product_id,
		name as 'Nome Produto',
		variant_id,
		quantity as 'Quantidade',
		original_price as 'Preço Unitário',
		quantity * original_price as [Preço Total],
		final_price,
		campaign_id
	;
	sql select
		id,
		order_id,
		product_id,
		name,
		variant_id,
		quantity,
		original_price,
		final_price,
		campaign_id
	from `dinda_prd`.order_items;

	left join (order_items)
	load id as product_id,
		 erp_code as [Código ERP produto],
		 main_category_id
	resident products;

	left join (order_items)
	load id as variant_id,
		 erp_code as [Código ERP Variante]
	resident products;

	drop table products;

	left join (order_items)
	sql select
		id as main_category_id,
		name as Categoria
	from `dinda_prd`.categories;

	drop fields
		product_id,
		variant_id,
		main_category_id
	from order_items;

	store order_items into $(qvdDir)admin_itens.qvd (qvd);
	drop table order_items;

//UTMS
	utms:
	sql select
		id as utm_id,
		if(isnull(source), '', source) as 'UTM Source',
		if(isnull(campaign), '', campaign) as 'UTM Campaign',
		if(isnull(medium), '', medium) as 'UTM Medium',
		if(isnull(term), '', term) as 'UTM Term',
		if(isnull(content), '', content) as 'UTM Content',
		if(isnull(gclid), '', gclid) as 'UTM GCLID'
	from `dinda_prd`.utms;

//CLIENTES
	users:
	sql select
		id as 'ID',
		email as 'E-mail',
		created_at as 'Data de Cadastro',
		utm_id,
		if(subscribed = '1', 'Sim', 'Não') as 'OPT IN',
		gender as Sexo,
		birthdate
	from `dinda_prd`.users;

	left join (users)
	load * resident utms;

	drop field utm_id from users;

	addresses:
	sql select
		user_id as ID,
		state as Estado,
		city
	from `dinda_prd`.addresses;

	addresses_new:
	NoConcatenate
	load ID,
		 firstvalue(Estado) as Estado,
		 firstvalue(city) as city
	resident addresses
	group by ID
	order by ID desc; //últimos serão os atualizados mais recentemente

	drop table addresses;

	left join (users)
	load * resident addresses_new;

	drop table addresses_new;

	store users into $(qvdDir)admin_clientes.qvd (qvd);

//PEDIDOS
	orders:
	load
		id as 'ID privado',
		masked_id as 'ID público',
		created_at as 'Data de Criação',
		user_id as 'Cliente ID',
		status,
		payment_status,
		cached_final_value as 'Valor Pedido',
		cached_total_value as 'Valor Itens',
		shipping_price as 'Valor Frete',
		utm_id,
		installments as Parcelas,
		state as 'Estado Pedido',
		credit_card_operator,
		payment_method;
	sql select
		id,
		masked_id,
		created_at,
		user_id,
		status,
		payment_status,
		cached_final_value,
		cached_total_value,
		shipping_price,
		utm_id,
		installments,
		state,
		credit_card_operator,
		payment_method
	from `dinda_prd`.orders;

	left join (orders)
	load
		ID as [Cliente ID],
		[E-mail]
	resident users;

	drop table users;

	order_status:
	load
		status_type,
		status_id,
		firstvalue(status_name) as status_name
	FROM [D:\QlikView\Dados\Outros\Order_status.txt] (txt, utf8, embedded labels, delimiter is ',', msq)
	group by
		status_type,
		status_id;

	left join (orders)
	load
		status_id as status,
		status_name as [Status ERP]
	resident order_status
	where status_type = 'status';

	left join (orders)
	load
		status_id as payment_status,
		status_name as [Status Pagamento]
	resident order_status
	where status_type = 'payment_status';

	drop table order_status;

	left join (orders)
	load * resident utms;

	drop table utms;

	drop fields
		status,
		payment_status,
		utm_id
	from orders;

//trata status para bater com planilha externa
	left join (orders)
	load
		[ID privado],
		trim(lower([Estado Pedido])) as pedidoStatus2_tratado,
		trim(lower([Status ERP])) as pedidoStatus_tratado,
		trim(lower([Status Pagamento])) as pedidoStatusPagamento_tratado
	resident orders;

// Carrega status de pedidos que deverão ser mantidos
	pedidoStatus2:
	LOAD trim(lower([Estado Pedido])) as pedidoStatus2_tratado,
		 if(lower(trim([Status para Análise])) = 'incluir', 1) as incluir
	FROM
	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
	(ooxml, embedded labels, table is TabelaOrderStatus);

// Carrega status que deverão ser excluídos caso "pedidoStatus2" seja NULL
	pedidoStatus_excluir:
	LOAD distinct
		trim(lower([Status ERP - Excluir])) as pedidoStatus_tratado
	FROM
	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
	(ooxml, embedded labels, table is TabelaOrderStatus);

	pedidoStatusPagamento_excluir:
	LOAD distinct
		trim(lower([Status Pagamento - Excluir])) as pedidoStatusPagamento_tratado
	FROM
	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
	(ooxml, embedded labels, table is TabelaOrderStatus);

// Verifica quais pedidos devem ser incluídos de acordo com seus status
	left join (orders)
	load * resident pedidoStatus2;

	left join (orders)
	load *, 1 as excluir_1 resident pedidoStatus_excluir;

	left join (orders)
	load *, 1 as excluir_2 resident pedidoStatusPagamento_excluir;

	drop tables pedidoStatus2,
				pedidoStatus_excluir,
				pedidoStatusPagamento_excluir;

	left join (orders)
	load [ID privado],

		 if(pedidoStatus2_tratado <> '-',
		 	if(incluir = 1, 'Sim', 'Não'),
		 	if(excluir_1 = 1 or excluir_2 = 1, 'Não', 'Sim')
		 ) as [Estado Pedido - Incluir],

		 if(excluir_1 = 1 or excluir_2 = 1, 'Não', 'Sim') as [Status ERP e Pagamento - Incluir]
	resident orders;

	drop fields incluir,
				excluir_1,
				excluir_2,
				pedidoStatus2_tratado,
				pedidoStatus_tratado,
				pedidoStatusPagamento_tratado
	from orders;


	store orders into $(qvdDir)admin_pedidos.qvd (qvd);
	drop table orders;


//CAMPANHAS
	campaigns:
	load
		id,
		date(floor(created_at)) as created_at,
		name,
		slug,
		replace(subfield(slug, '--', 1), '-', ' ') as treated_slug,
		date(floor(offer_starts_at)) as offer_starts_at,
		date(floor(offer_ends_at)) as offer_ends_at,
		highlight,
		banner,
		brand_id
	;
	sql select
		id,
		created_at,
		name,
		slug,
		offer_starts_at,
		offer_ends_at,
		highlight,
		banner,
		brand_id
	FROM `dinda_prd`.`campaigns`
	/*WHERE slug NOT LIKE '%super-sale%'*/
	order by id
	;

	left join (campaigns)
	sql select
		id as brand_id,
		name as brand_name
	from `dinda_prd`.`brands`;

	//store campaigns into [D:\QlikView\Dados\Dropbox\Campanhas Dinda\Campanhas Admin Dump.csv] (txt);
	store campaigns into $(qvdDir)campaigns_dump.qvd (qvd);

	campanhas:
	load id as campanhaId,
		 name as campanhaNome,
		 treated_slug as campanhaSlugTratado,
		 floor(offer_starts_at) as campanhaDataInicio,
		 floor(offer_ends_at) as campanhaDataFinal,
		 highlight as campanhaImagemHighlight,
		 banner as campanhaImagemBanner,
		 name & ' - ' & capitalize(date(offer_starts_at, 'MMM-YY')) as campanhaNomeRotulo,
		 name & ' ' & capitalize(date(offer_starts_at, 'MM.YY')) as campanhaNomeRotulo2,
		 brand_name as campanhaBrandName
	resident campaigns;

	drop table campaigns;

	store campanhas into $(qvdDir)campanhas.qvd (qvd);
	drop table campanhas;

///$tab Campanhas - New
// //conexão ao banco
ODBC CONNECT TO dindabimy (XUserId is QcAYDRFNfCZSGXRMBLeB, XPassword is cRSTARFNELacGSFMSBMCDaEU);


// Pega os brand_id novos
BrandIDNovos_TMP:
SQL SELECT distinct
    `campaign_id`,
    `product_id`
FROM `dinda_prd`.`campaigns_products`;

LEFT JOIN
SQL SELECT distinct
	id 			as `product_id`,
    `brand_id` 	as brand_id_product
FROM `dinda_prd`.products;


BrandIDNovos:
LOAD distinct
	campaign_id,
	brand_id_product
RESIDENT BrandIDNovos_TMP;
DROP TABLE BrandIDNovos_TMP;



// Carrega a tabela de campanhas e cruza para pegar os brand_id novos (que nao existem na tabela de campaigns)
campaigns_TMP:
load
	id	as campaign_id,
	date(floor(created_at)) as created_at,
	name,
	slug,
	replace(subfield(slug, '--', 1), '-', ' ') as treated_slug,
	date(floor(offer_starts_at)) as offer_starts_at,
	date(floor(offer_ends_at)) as offer_ends_at,
	highlight,
	banner,
	brand_id
;
sql select
	id,
	created_at,
	name,
	slug,
	offer_starts_at,
	offer_ends_at,
	highlight,
	banner,
	brand_id
FROM `dinda_prd`.`campaigns`
/*WHERE slug NOT LIKE '%super-sale%'*/
order by id;


left join (campaigns_TMP)
LOAD distinct
	campaign_id,
	brand_id_product
RESIDENT BrandIDNovos;
DROP TABLE BrandIDNovos;



// Trata os dados
campanhas:
LOAD
	 campaign_id as campanhaId,
	 name as campanhaNome,
	 treated_slug as campanhaSlugTratado,
	 floor(offer_starts_at) as campanhaDataInicio,
	 floor(offer_ends_at) as campanhaDataFinal,
	 highlight as campanhaImagemHighlight,
	 banner as campanhaImagemBanner,
	 name & ' - ' & capitalize(date(offer_starts_at, 'MMM-YY')) as campanhaNomeRotulo,
	 name & ' ' & capitalize(date(offer_starts_at, 'MM.YY')) as campanhaNomeRotulo2,
	 if( not IsNull(brand_id),brand_id,brand_id_product) 	as campanhaBrand_id
RESIDENT campaigns_TMP;
DROP TABLE campaigns_TMP;


left join (campanhas)
sql select
	id 		as campanhaBrand_id,
	name 	as campanhaBrandName
from `dinda_prd`.`brands`;



store campanhas into $(qvdDir)campanhas_NEW.qvd (qvd);
drop table campanhas;
///$tab MySQL queries
////PRODUTOS IMAGENS
//	products:
//	sql select
//		id,
//		erp_code,
//		main_category_id,
//		main_picture
//	from products;
//
//	produtosImagens:
//	load erp_code as produtoCodigoPai,
//		 firstvalue(main_picture) as produtoImagem
//	resident products
//	where not isnull(main_picture)
//	group by erp_code;
//
//	store produtosImagens into [$(qvdDir)produtosImagens.qvd] (qvd);
//	drop table produtosImagens;
//
////ITENS
//	order_items:
//	load
//		id as itemId,
//		order_id as 'ID Pedido',
//		product_id,
//		name as 'Nome Produto',
//		variant_id,
//		quantity as 'Quantidade',
//		original_price as 'Preço Unitário',
//		quantity * original_price as [Preço Total],
//		final_price,
//		campaign_id
//	;
//	sql select
//		id,
//		order_id,
//		product_id,
//		name,
//		variant_id,
//		quantity,
//		original_price,
//		final_price,
//		campaign_id
//	from order_items;
//
//	left join (order_items)
//	load id as product_id,
//		 erp_code as [Código ERP produto],
//		 main_category_id
//	resident products;
//
//	left join (order_items)
//	load id as variant_id,
//		 erp_code as [Código ERP Variante]
//	resident products;
//
//	drop table products;
//
//	left join (order_items)
//	sql select
//		id as main_category_id,
//		name as Categoria
//	from categories;
//
//	drop fields
//		product_id,
//		variant_id,
//		main_category_id
//	from order_items;
//
//	store order_items into $(qvdDir)admin_itens.qvd (qvd);
//	drop table order_items;
//
////UTMS
//	utms:
//	sql select
//		id as utm_id,
//		if(isnull(source), '', source) as 'UTM Source',
//		if(isnull(campaign), '', campaign) as 'UTM Campaign',
//		if(isnull(medium), '', medium) as 'UTM Medium',
//		if(isnull(term), '', term) as 'UTM Term',
//		if(isnull(content), '', content) as 'UTM Content',
//		if(isnull(gclid), '', gclid) as 'UTM GCLID'
//	from utms;
//
////CLIENTES
//	users:
//	sql select
//		id as 'ID',
//		email as 'E-mail',
//		created_at as 'Data de Cadastro',
//		utm_id,
//		if(subscribed = '1', 'Sim', 'Não') as 'OPT IN',
//		gender as Sexo,
//		birthdate
//	from users;
//
//	left join (users)
//	load * resident utms;
//
//	drop field utm_id from users;
//
//	addresses:
//	sql select
//		user_id as ID,
//		state as Estado,
//		city
//	from addresses;
//
//	addresses_new:
//	NoConcatenate
//	load ID,
//		 firstvalue(Estado) as Estado,
//		 firstvalue(city) as city
//	resident addresses
//	group by ID
//	order by ID desc; //últimos serão os atualizados mais recentemente
//
//	drop table addresses;
//
//	left join (users)
//	load * resident addresses_new;
//
//	drop table addresses_new;
//
//	store users into $(qvdDir)admin_clientes.qvd (qvd);
//
////PEDIDOS
//	orders:
//	load
//		id as 'ID privado',
//		masked_id as 'ID público',
//		created_at as 'Data de Criação',
//		user_id as 'Cliente ID',
//		status,
//		payment_status,
//		cached_final_value as 'Valor Pedido',
//		cached_total_value as 'Valor Itens',
//		shipping_price as 'Valor Frete',
//		utm_id,
//		installments as Parcelas,
//		state as 'Estado Pedido',
//		credit_card_operator,
//		payment_method;
//	sql select
//		id,
//		masked_id,
//		created_at,
//		user_id,
//		status,
//		payment_status,
//		cached_final_value,
//		cached_total_value,
//		shipping_price,
//		utm_id,
//		installments,
//		state,
//		credit_card_operator,
//		payment_method
//	from orders;
//
//	left join (orders)
//	load
//		ID as [Cliente ID],
//		[E-mail]
//	resident users;
//
//	drop table users;
//
//	order_status:
//	load
//		status_type,
//		status_id,
//		firstvalue(status_name) as status_name
//	FROM [D:\QlikView\Dados\Outros\Order_status.txt] (txt, utf8, embedded labels, delimiter is ',', msq)
//	group by
//		status_type,
//		status_id;
//
//	left join (orders)
//	load
//		status_id as status,
//		status_name as [Status ERP]
//	resident order_status
//	where status_type = 'status';
//
//	left join (orders)
//	load
//		status_id as payment_status,
//		status_name as [Status Pagamento]
//	resident order_status
//	where status_type = 'payment_status';
//
//	drop table order_status;
//
//	left join (orders)
//	load * resident utms;
//
//	drop table utms;
//
//	drop fields
//		status,
//		payment_status,
//		utm_id
//	from orders;
//
////trata status para bater com planilha externa
//	left join (orders)
//	load
//		[ID privado],
//		trim(lower([Estado Pedido])) as pedidoStatus2_tratado,
//		trim(lower([Status ERP])) as pedidoStatus_tratado,
//		trim(lower([Status Pagamento])) as pedidoStatusPagamento_tratado
//	resident orders;
//
//// Carrega status de pedidos que deverão ser mantidos
//	pedidoStatus2:
//	LOAD trim(lower([Estado Pedido])) as pedidoStatus2_tratado,
//		 if(lower(trim([Status para Análise])) = 'incluir', 1) as incluir
//	FROM
//	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
//	(ooxml, embedded labels, table is TabelaOrderStatus);
//
//// Carrega status que deverão ser excluídos caso "pedidoStatus2" seja NULL
//	pedidoStatus_excluir:
//	LOAD distinct
//		trim(lower([Status ERP - Excluir])) as pedidoStatus_tratado
//	FROM
//	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
//	(ooxml, embedded labels, table is TabelaOrderStatus);
//
//	pedidoStatusPagamento_excluir:
//	LOAD distinct
//		trim(lower([Status Pagamento - Excluir])) as pedidoStatusPagamento_tratado
//	FROM
//	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
//	(ooxml, embedded labels, table is TabelaOrderStatus);
//
//// Verifica quais pedidos devem ser incluídos de acordo com seus status
//	left join (orders)
//	load * resident pedidoStatus2;
//
//	left join (orders)
//	load *, 1 as excluir_1 resident pedidoStatus_excluir;
//
//	left join (orders)
//	load *, 1 as excluir_2 resident pedidoStatusPagamento_excluir;
//
//	drop tables pedidoStatus2,
//				pedidoStatus_excluir,
//				pedidoStatusPagamento_excluir;
//
//	left join (orders)
//	load [ID privado],
//
//		 if(pedidoStatus2_tratado <> '-',
//		 	if(incluir = 1, 'Sim', 'Não'),
//		 	if(excluir_1 = 1 or excluir_2 = 1, 'Não', 'Sim')
//		 ) as [Estado Pedido - Incluir],
//
//		 if(excluir_1 = 1 or excluir_2 = 1, 'Não', 'Sim') as [Status ERP e Pagamento - Incluir]
//	resident orders;
//
//	drop fields incluir,
//				excluir_1,
//				excluir_2,
//				pedidoStatus2_tratado,
//				pedidoStatus_tratado,
//				pedidoStatusPagamento_tratado
//	from orders;
//
//
//	store orders into $(qvdDir)admin_pedidos.qvd (qvd);
//	drop table orders;
//
//
////CAMPANHAS
//	campaigns:
//	load
//		id,
//		date(floor(created_at)) as created_at,
//		name,
//		slug,
//		replace(subfield(slug, '--', 1), '-', ' ') as treated_slug,
//		date(floor(offer_starts_at)) as offer_starts_at,
//		date(floor(offer_ends_at)) as offer_ends_at,
//		highlight,
//		banner,
//		brand_id
//	;
//	sql select
//		id,
//		created_at,
//		name,
//		slug,
//		offer_starts_at,
//		offer_ends_at,
//		highlight,
//		banner,
//		brand_id
//	FROM `campaigns`
//	/*WHERE slug NOT LIKE '%super-sale%'*/
//	order by id
//	;
//
//	left join (campaigns)
//	sql select
//		id as brand_id,
//		name as brand_name
//	from `brands`;
//
//	//store campaigns into [D:\QlikView\Dados\Dropbox\Campanhas Dinda\Campanhas Admin Dump.csv] (txt);
//	store campaigns into $(qvdDir)campaigns_dump.qvd (qvd);
//
//	campanhas:
//	load id as campanhaId,
//		 name as campanhaNome,
//		 treated_slug as campanhaSlugTratado,
//		 floor(offer_starts_at) as campanhaDataInicio,
//		 floor(offer_ends_at) as campanhaDataFinal,
//		 highlight as campanhaImagemHighlight,
//		 banner as campanhaImagemBanner,
//		 name & ' - ' & capitalize(date(offer_starts_at, 'MMM-YY')) as campanhaNomeRotulo,
//		 name & ' ' & capitalize(date(offer_starts_at, 'MM.YY')) as campanhaNomeRotulo2,
//		 brand_name as campanhaBrandName
//	resident campaigns;
//
//	drop table campaigns;
//
//	store campanhas into [$(qvdDir)campanhas.qvd] (qvd);
//	drop table campanhas;
///$tab Export dump
set dump_export_dir = D:\QlikView\Dados\Dropbox\Order Cardinal\;

orders:
LOAD [ID privado],
     [ID público],
     [Data de Criação],
     [Cliente ID],
     [E-mail],
     [Status ERP],
     [Status Pagamento],
     [Valor Pedido],
     [Valor Itens],
     [Valor Frete],
     [UTM Source],
     [UTM Campaign],
     [UTM Medium],
     [UTM Term],
     [UTM Content],
     [UTM GCLID],
     Parcelas,
     [Estado Pedido],
     payment_method as Pagamento,
     credit_card_operator as Bandeira
FROM $(qvdDir)admin_pedidos.qvd (qvd);

store orders into $(dump_export_dir)orders.csv (txt);
drop table orders;

order_items:
LOAD
	[ID Pedido],
	[Código ERP produto],
	[Nome Produto],
	[Código ERP Variante],
	Categoria,
	Quantidade,
	[Preço Unitário],
	[Preço Total],
	campaign_id as [Campanha ID],
	final_price as [Preço de Venda],
	itemId as [Item ID]
FROM $(qvdDir)admin_itens.qvd (qvd);

left join (order_items)
LOAD campanhaId as [Campanha ID],
     campanhaNome as [Campanha]
FROM $(qvdDir)campanhas.qvd (qvd);

store order_items into $(dump_export_dir)order_items.csv (txt);
drop table order_items;

users:
LOAD
	[E-mail],
	ID,
	[Data de Cadastro],
	[UTM Source],
	[UTM Campaign],
	[UTM Medium],
	[UTM Term],
	[UTM Content],
	[UTM GCLID],
	[OPT IN],
	Sexo,
	Estado,
	birthdate as [Data de Nascimento],
	city as Cidade
FROM $(qvdDir)admin_clientes.qvd (qvd);

store users into $(dump_export_dir)users.csv (txt);
drop table users;

///$tab Pedidos
SET ThousandSep=',';
SET DecimalSep='.';

//redução receita
	reducao:
	LOAD Dinda
	FROM
	[D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos - New.xlsx]
	(ooxml, embedded labels, table is [Redução receita Admin]);

	let reducaoDinda = peek('Dinda', 0, 'reducao');
	let reducaoDinda = num(PurgeChar('$(reducaoDinda)', '%') / if(right('$(reducaoDinda)', 1) = '%', 100, 1));

	drop table reducao;

//Dinda
	pedidos:
	LOAD [ID privado] as pedidoId,
		 'Dinda_' & [ID privado] as pedidoIdUnico,
	     [ID público] as pedidoIdExt,
	     floor([Data de Criação]) as pedidoData,
	     monthname([Data de Criação]) as pedidoDataMes,
	     year([Data de Criação]) as pedidoDataAno,
	     'Dinda_' & [Cliente ID] as clienteIdUnico,
	     if(not isnull([Status ERP]), trim([Status ERP]), '-') as pedidoStatus,
	     if(not isnull([Status Pagamento]), trim([Status Pagamento]), '-') as pedidoStatusPagamento,
	     //[Valor Pedido] as pedidoReceitaBruta,
	     numsum([Valor Itens], [Valor Frete]) * (1 - $(reducaoDinda)) as pedidoReceitaBruta,
	     [Valor Frete] as pedidoCustoFrete_admin,
	     [UTM Source] as pedidoUtmSource_Admin,
	     [UTM Campaign] as pedidoUtmCampaign_Admin,
	     [UTM Medium] as pedidoUtmMedium_Admin,
	     [UTM Term] as pedidoUtmTerm,
	     [UTM Content] as pedidoUtmContent,
	     [UTM GCLID] as pedidoUtmGclid,
	     'Dinda' as pedidoBU,
	     'Cartão de Crédito' as pedidoPagamentoForma,
	     Parcelas as pedidoPagamentoParcelas,
	     if(trim(lower([Status Pagamento])) = 'capturado', 1, 0) as pedidoPagamentoConfirmado,
	     if(not isnull([Estado Pedido]), lower(trim([Estado Pedido])), '-') as pedidoStatus2,
	     credit_card_operator as pedidoOperadora
	from $(qvdDir)admin_pedidos.qvd (qvd)
	where (
		lower(trim([Status ERP])) = 'aguardando pagamento'
		or lower(trim([Status ERP])) = 'capturado'
		or lower(trim([Status ERP])) = 'despachado'
		or lower(trim([Status ERP])) = 'pagamento confirmado'
		or lower(trim([Status ERP])) = 'faturado'
	) and
		lower(trim([Status Pagamento])) <> 'autorização falhou'
	;

store pedidos into $(qvdDir)temp_pedidos.qvd (qvd);
drop table pedidos;

SET ThousandSep='.';
SET DecimalSep=',';
///$tab Clientes
clientes:
LOAD [E-mail] as clienteEmail,
	 'Dinda_' & ID as clienteIdUnico,
	 ID as clienteId,
     floor([Data de Cadastro]) as clienteDataRegistro_Original,
     [UTM Source] as source_1,
     [UTM Campaign] as campaign_1,
     [UTM Medium] as medium_1,
     [UTM Term] as clienteUtmTerm,
     [UTM Content] as clienteUtmContent,
     [UTM GCLID] as clienteUtmGclid,
     [OPT IN] as clienteNewsletter,
     'Dinda' as clienteBU,
     Sexo as clienteSexo,
     Estado as clienteEstado
FROM $(qvdDir)admin_clientes.qvd (qvd);

events:
LOAD @1 as date,
     @2 as source,
     @3 as medium,
     @4 as campaign,
     @5 as eventAction,
     @6 as uniqueEvents
FROM
[D:\QlikView\Dados\GA\Dinda\eventAction\*.csv]
(txt, codepage is 1252, no labels, delimiter is ',', msq);

left join (clientes)
load 'Dinda_' & eventAction as clienteIdUnico,
	 firstvalue(source) as source_2,
	 firstvalue(medium) as medium_2,
	 firstvalue(campaign) as campaign_2
resident events
group by eventAction;

drop table events;

left join (clientes)
load clienteIdUnico,
	 if(source_1 <> '', source_1, if(not isnull(source_2), source_2, 'n/a')) as clienteUtmSource,
	 if(source_1 <> '', medium_1, if(not isnull(medium_2), medium_2, 'n/a')) as clienteUtmMedium,
	 if(source_1 <> '', campaign_1, if(not isnull(campaign_2), campaign_2, 'n/a')) as clienteUtmCampaign
resident clientes;

drop fields source_1, medium_1, campaign_1, source_2, medium_2, campaign_2;

store clientes into $(qvdDir)temp_clientes.qvd (qvd);
drop table clientes;
///$tab GA Pedidos
//SET ThousandSep=',';
//SET DecimalSep='.';
//
//GA:
//LOAD date#(@1, 'YYYYMMDD') as date,
//     @2 as source,
//     @3 as medium,
//     @4 as campaign,
//     @5 as pedidoIdExt,
//     @8 as transactionRevenue,
//     'Dinda' as pedidoBU
//FROM
//[D:\QlikView\Dados\GA\Dinda\Transacoes\*.csv]
//(txt, codepage is 1252, no labels, delimiter is ',', msq);
//
//store GA into $(qvdDir)temp_GA.qvd (qvd);
//drop table GA;
//
//SET ThousandSep='.';
//SET DecimalSep=',';
///$tab Pedidos ajustes
pedidos:
load * from $(qvdDir)temp_pedidos.qvd (qvd);

//estimativa de conversão
	pedidosFull:
	load pedidoData as data,
		 sum(pedidoReceitaBruta) as total,
		 today() - pedidoData as dist,
		 pedidoBU as BU
	from $(qvdDir)temp_pedidos.qvd (qvd)
	where today() - pedidoData <= 120 and pedidoBU = 'Dinda'
	group by pedidoData, pedidoBU;

	left join (pedidosFull)
	load pedidoData as data,
		 sum(pedidoReceitaBruta) as pago,
		 pedidoBU as BU
	resident pedidos
	where today() - pedidoData <= 120 and pedidoBU = 'Dinda'
	group by pedidoData, pedidoBU;

	if (FileSize('$(qvdDir)estimativaConversao.qvd') > 0) then
		conversao:
		load * from $(qvdDir)estimativaConversao.qvd (qvd)
		where data <> today();
	end if;

	conversao:
	load BU,
		 today() as data,
		 1 - sum(if(dist >= 1 and dist <= 30, pago)) / sum(if(dist >= 1 and dist <= 30, total)) as taxaCancelamento_1a30,
		 1 - sum(if(dist >= 91 and dist <= 120, pago)) / sum(if(dist >= 91 and dist <= 120, total)) as taxaCancelamento_91a120,

		 (1 - sum(if(dist >= 91 and dist <= 120, pago)) / sum(if(dist >= 91 and dist <= 120, total)))
		 - (1 - sum(if(dist >= 1 and dist <= 30, pago)) / sum(if(dist >= 1 and dist <= 30, total)))
		 as dif,
		 sum(total) as sum
	resident pedidosFull
	group by BU;

	drop table pedidosFull;

	store conversao into $(qvdDir)estimativaConversao.qvd (qvd);

	conversaoReversed:
	NoConcatenate
	load * resident conversao
	order by data desc;

	drop table conversao;

	let varReceitaDinda = '';
	let row = 0;

	do while varReceitaDinda = '';
		let var = peek('dif', $(row), 'conversaoReversed');
		if (var > 2/100 or isnull(var)) then //se taxa inferior a 2%, utilizar a última superior a tal - se null é porque terminou a tabela
			let varReceitaDinda = num('$(var)');
		else
			let row = $(row) + 1;
		end if;
	loop;

	drop table conversaoReversed;

	if (isnull(varReceitaDinda)) then //se não há taxa encontrada, utilizar 2%
		let varReceitaDinda = 2/100;
		let varReceita_Inferior_a_2% = 'true';
	else
		let varReceita_Inferior_a_2% = 'false';
	end if;

	trace varReceitaDinda = $(varReceitaDinda);

	left join (pedidos)
	load distinct
		pedidoData,
		pedidoBU,
		if(pedidoBU = 'Dinda',
			1 - rangemax(0, (120 - (today() - pedidoData)) * num('$(varReceitaDinda)') / 120), //1 - diminuição para a data. Se for superior a 120 dias, 1 - 0
			1
		) as pedidoEstimativaConversao
	resident pedidos;

	left join (pedidos)
	load pedidoIdUnico,
		 pedidoReceitaBruta * pedidoEstimativaConversao as pedidoReceitaBrutaEsperada
	resident pedidos;

//Cardinal; first-time purchase and first-time paid purchase
	left join (pedidos)
	load pedidoIdUnico,
		 rowno() as rowNo
	resident pedidos
	order by clienteIdUnico, pedidoData, pedidoIdExt;

	left join (pedidos)
	load pedidoIdUnico,
		 rowno() as rowNo_pago
	resident pedidos
	where pedidoPagamentoConfirmado = 1
	order by clienteIdUnico, pedidoData, pedidoIdExt;

	left join (pedidos)
	load clienteIdUnico,
		 min(rowNo) as minRowno,
		 min(rowNo_pago) as minRowno_pago
	resident pedidos
	group by clienteIdUnico;

	left join (pedidos)
	load pedidoIdUnico,
		 rowNo - minRowno + 1 as pedidoCardinal,
		 rowNo_pago - minRowno_pago + 1 as pedidoCardinalPago,
		 if(rowNo = minRowno, 1, 0) as pedidoIsFtp,
		 if(rowNo_pago = minRowno_pago, 1, 0) as pedidoIsFtpPago,
		 if(rowNo = minRowno, 1, 0) * pedidoEstimativaConversao as pedidoIsFtpEstimado
	resident pedidos;

	drop fields minRowno, rowNo, minRowno_pago, rowNo_pago;

	clientes:
	load * from $(qvdDir)temp_clientes.qvd (qvd);

	left join (clientes)
	load clienteIdUnico,
		 pedidoData as clienteDataFtp
	resident pedidos
	where pedidoIsFtp = 1;

	left join (clientes)
	load clienteIdUnico,
		 pedidoData as clienteDataFtpPago
	resident pedidos
	where pedidoIsFtpPago = 1;

	left join (clientes)
	load clienteIdUnico,
		 count(distinct pedidoIdUnico) as clientePedidos_temp
	resident pedidos
	group by clienteIdUnico;

	//ajusta pedidos = null para pedidos = 0 e atribui min(data registro original, data pedidos) à data registro
	clientes_notnull:
	load *,
		 if(not isnull(clientePedidos_temp), clientePedidos_temp, 0) as clientePedidos,
		 rangemin(clienteDataFtp, clienteDataRegistro_Original) as clienteDataRegistro
	resident clientes;

	drop table clientes;
	drop field clientePedidos_temp;

	rename table clientes_notnull to clientes;

	left join (clientes)
	load distinct clienteDataRegistro,
				  floor(monthname(clienteDataRegistro)) as clienteDataRegistroMes,
				  year(clienteDataRegistro) as clienteDataRegistroAno
	resident clientes;

	left join (pedidos)
	load clienteIdUnico,
		 clienteDataFtp,
		 clienteDataFtpPago
	resident clientes
	where not isnull(clienteDataFtp);

	left join (pedidos)
	load pedidoIdUnico,
		 (
			year(pedidoData) * 12
			+ month(pedidoData)
			- year(clienteDataFtp) * 12
			- month(clienteDataFtp)
		 ) as pedidoDistanciaFtp,
		 (
			year(pedidoData) * 12
			+ month(pedidoData)
			- year(clienteDataFtpPago) * 12
			- month(clienteDataFtpPago)
		 ) as pedidoDistanciaFtpPago
	resident pedidos;

	drop fields clienteDataFtp, clienteDataFtpPago from pedidos;

//google analytics (sobrescreve origem do Admin)
	GA:
	load * from $(qvdDir)temp_GA.qvd (qvd);

	left join (pedidos)
	load pedidoIdExt,
		 date as pedidoData,
		 pedidoBU,
		 firstvalue(source) as pedidoUtmSource_GA,
		 firstvalue(medium) as pedidoUtmMedium_GA,
		 firstvalue(campaign) as pedidoUtmCampaign_GA,
		 firstvalue(transactionRevenue) as pedidoReceitaGA
	resident GA
	group by pedidoIdExt, pedidoBU, date;

	drop table GA;

	left join (pedidos)
	load pedidoIdUnico,
		 if(not isnull(pedidoUtmSource_GA), pedidoUtmSource_GA, pedidoUtmSource_Admin) as pedidoUtmSource,
		 if(not isnull(pedidoUtmMedium_GA), pedidoUtmMedium_GA, pedidoUtmMedium_Admin) as pedidoUtmMedium,
		 if(not isnull(pedidoUtmCampaign_GA), pedidoUtmCampaign_GA, pedidoUtmCampaign_Admin) as pedidoUtmCampaign
	resident pedidos;

	drop fields pedidoUtmSource_GA, pedidoUtmMedium_GA, pedidoUtmCampaign_GA, pedidoUtmSource_Admin, pedidoUtmMedium_Admin, pedidoUtmCampaign_Admin;

//ajuste custo de frete
	ajusteCustoFrete:
	LOAD Mês as pedidoDataMes,
		 'Dinda' as pedidoBU,
	     Ajuste as ajusteCustoFrete
	FROM
	[D:\QlikView\Dados\Dados temp para novo Dashboard\External data.xlsx]
	(ooxml, embedded labels, table is [Dinda - Ajuste custo frete]);

	left join (pedidos)
	load * resident ajusteCustoFrete;

	drop table ajusteCustoFrete;

	left join (pedidos)
	load pedidoIdUnico,
		 pedidoCustoFrete_admin * if(not isnull(ajusteCustoFrete), ajusteCustoFrete, 1) as pedidoCustoFrete
	resident pedidos;

	drop fields pedidoCustoFrete_admin, ajusteCustoFrete;

store pedidos into $(qvdDir)temp2_pedidos.qvd (qvd);
store clientes into $(qvdDir)temp2_clientes.qvd (qvd);

drop tables pedidos, clientes;
///$tab Itens
SET ThousandSep=',';
SET DecimalSep='.';

pedidos:
load * from $(qvdDir)temp2_pedidos.qvd (qvd);

//Dinda itens
	itens:
	load distinct
		pedidoIdUnico,
		pedidoDataMes
	resident pedidos;

	left join (itens)
	LOAD itemId,
		 'Dinda_' & [ID Pedido] as pedidoIdUnico,
	     [Código ERP produto] as produtoSku,
	     [Nome Produto] as produtoNome,
	     [Código ERP Variante] as produtoIdExt,
	     Categoria as produtoCategoria,
	     null() as produtoSubCategoria,
	     Quantidade as itemQuantidade,
	     [Preço Unitário] as itemValorUnitario,
	     [Preço Total] as itemValorTotal,
	     'Dinda' as pedidoBU
	from $(qvdDir)admin_itens.qvd (qvd);

	rename table dindaItens to itens;

//obtém produto Id Abacos
	left join (itens)
	load produtoIdExt,
		 produtoIdAbacos
	from $(qvdDir)abacos_produtos.qvd (qvd);

//custo de produtos
	estoque:
	load * from $(qvdDir)abacos_estoque.qvd (qvd);

	left join (itens)
	LOAD pedidoDataMes,
	     produtoIdAbacos,
	     pedidoBU,
	     itemCustoBrutoUnitario
	resident estoque;

	drop table estoque;

//CUSTO BRUTO DE PRODUTOS e IMPOSTO SOBRE CUSTOS DE PRODUTOS - por pedido
//cálculo feito pelo custo de estoque no Ábacos, que é atribuído a cada item do pedido no Admin
//após término do mês, valores por pedidos serão armazenados e fixados

	//encontrar penúltimo mês (serão alterados mês anterior e mês atual, para manter o histórico dos meses anteriores)
		max:
		load max(pedidoDataMes) as pedidoDataMes_max
		resident pedidos;

		let pedidoDataMes_penultimo = floor(monthstart(peek('pedidoDataMes_max', 0, 'max'), -1));
		drop table max;

	//historico
		set pedidosCustos_arquivo = D:\QlikView\Dados\QVD\Históricos\pedidosCustos.qvd;

		historico:
		load pedidoIdUnico,
		     pedidoCustoBrutoDeProdutos
		from $(pedidosCustos_arquivo) (qvd);

		left join (pedidos)
		load pedidoIdUnico,
		     firstvalue(pedidoCustoBrutoDeProdutos) as pedidoCustoBrutoDeProdutos_historico
		resident historico
		group by pedidoIdUnico;

	//calculado - apenas mês atual (incompleto) e mês anterior (completo)
		left join (pedidos)
		load pedidoIdUnico,
			 sum(itemCustoBrutoUnitario * itemQuantidade) as pedidoCustoBrutoDeProdutos_calculado
		resident itens
		where pedidoDataMes >= $(pedidoDataMes_penultimo)
		group by pedidoIdUnico;

		drop fields itemCustoBrutoUnitario, pedidoDataMes from itens;

	//final
		left join (pedidos)
		load pedidoIdUnico,
			 if(not isnull(pedidoCustoBrutoDeProdutos_historico), pedidoCustoBrutoDeProdutos_historico, pedidoCustoBrutoDeProdutos_calculado) as pedidoCustoBrutoDeProdutos
		resident pedidos;

		drop fields pedidoCustoBrutoDeProdutos_historico, pedidoCustoBrutoDeProdutos_calculado;

	//store new - apenas do mês anterior caso ainda não exista
		new:
		load pedidoIdUnico,
			 pedidoDataMes,
			 pedidoCustoBrutoDeProdutos
		resident pedidos
		where pedidoDataMes = $(pedidoDataMes_penultimo);

		store pedidos into $(qvdDir)temp3_pedidos.qvd (qvd);
		drop table pedidos;

		outer join (historico)
		load pedidoIdUnico,
			 pedidoCustoBrutoDeProdutos as pedidoCustoBrutoDeProdutos_new
		resident new;

		drop table new;

		left join (historico)
		load pedidoIdUnico,
			 if(not isnull(pedidoCustoBrutoDeProdutos), pedidoCustoBrutoDeProdutos, pedidoCustoBrutoDeProdutos_new) as pedidoCustoBrutoDeProdutos_final
		resident historico;

		drop fields pedidoCustoBrutoDeProdutos, pedidoCustoBrutoDeProdutos_new from historico;
		rename fields pedidoCustoBrutoDeProdutos_final to pedidoCustoBrutoDeProdutos;

		store historico into $(pedidosCustos_arquivo) (qvd);
		drop table historico;

// término utilização histórico de custo de produtos --!>

drop field pedidoBU from itens;
store itens into $(qvdDir)itens.qvd (qvd);

drop table itens;

SET ThousandSep='.';
SET DecimalSep=',';
///$tab Dicionário de Mídia
//origens de pedidos full do admin
depara_temp:
load
	[UTM Source] as source,
	[UTM Medium] as medium,
	[UTM Campaign] as campaign,
	'Dinda' as pedidoBU,
	count([ID privado]) as registros
FROM [D:\QlikView\Dados\QVD\Admin\admin_pedidos.qvd] (qvd)
group by [UTM Source], [UTM Medium], [UTM Campaign];

concatenate (depara_temp)
LOAD source,
     medium,
     campaign,
     pedidoBU,
     count(pedidoIdExt) as registros
FROM D:\QlikView\Dados\QVD\Admin\temp_GA.qvd (qvd)
where pedidoIdExt <> 'transactionId'
group by source, medium, campaign, pedidoBU;

clientes:
load * from $(qvdDir)temp2_clientes.qvd (qvd);

concatenate (depara_temp)
load
	clienteUtmSource as source,
	clienteUtmMedium as medium,
	clienteUtmCampaign as campaign,
	clienteBU as pedidoBU,
	count(clienteIdUnico) as registros
resident clientes
group by clienteUtmSource, clienteUtmMedium, clienteUtmCampaign, clienteBU;

depara:
NoConcatenate
load source,
	 medium,
	 campaign,
	 pedidoBU,
	 sum(registros) as registros
resident depara_temp
group by source, medium, campaign, pedidoBU;

drop table depara_temp;

/*
dicionarioDinamico_temp:
LOAD if(isnull(exatoSource), '', exatoSource) as exatoSource,
	 if(isnull(exatoMedium), '', exatoMedium) as exatoMedium,
	 if(isnull(exatoCampaign), '', exatoCampaign) as exatoCampaign,
	 if(isnull(likeSource), '', likeSource) as likeSource,
	 if(isnull(likeMedium), '', likeMedium) as likeMedium,
	 if(isnull(likeCampaign), '', likeCampaign) as likeCampaign,
	 if(isnull(tratadoNivel1), '', tratadoNivel1) as tratadoNivel1,
	 if(isnull(tratadoNivel2), '', tratadoNivel2) as tratadoNivel2,
	 if(isnull(tratadoNivel3), '', tratadoNivel3) as tratadoNivel3
	 //RowNo() as regraN
FROM
[D:\QlikView\Dados\Dropbox\Midia\Planilha Mídia $(BU) - UTM 2013.xlsx]
(ooxml, embedded labels, table is [Dicionário Dinâmico]);

concatenate (dicionarioDinamico_temp)
LOAD if(isnull(exatoSource), '', exatoSource) as exatoSource,
	 if(isnull(exatoMedium), '', exatoMedium) as exatoMedium,
	 if(isnull(exatoCampaign), '', exatoCampaign) as exatoCampaign,
	 if(isnull(likeSource), '', likeSource) as likeSource,
	 if(isnull(likeMedium), '', likeMedium) as likeMedium,
	 if(isnull(likeCampaign), '', likeCampaign) as likeCampaign,
	 if(isnull(tratadoNivel1), '', tratadoNivel1) as tratadoNivel1,
	 if(isnull(tratadoNivel2), '', tratadoNivel2) as tratadoNivel2,
	 if(isnull(tratadoNivel3), '', tratadoNivel3) as tratadoNivel3
	 //RowNo() as regraN
FROM
[D:\QlikView\Dados\Dropbox\Midia\Dicionario Mídia $(BU) 2014.xlsx]
(ooxml, embedded labels, table is [Dicionário Dinâmico]);
*/

dicionarioDinamico:
LOAD if(isnull(exatoSource), '', exatoSource) as exatoSource,
	 if(isnull(exatoMedium), '', exatoMedium) as exatoMedium,
	 if(isnull(exatoCampaign), '', exatoCampaign) as exatoCampaign,
	 if(isnull(likeSource), '', likeSource) as likeSource,
	 if(isnull(likeMedium), '', likeMedium) as likeMedium,
	 if(isnull(likeCampaign), '', likeCampaign) as likeCampaign,
	 if(isnull(tratadoNivel1), '', tratadoNivel1) as tratadoNivel1,
	 if(isnull(tratadoNivel2), '', tratadoNivel2) as tratadoNivel2,
	 if(isnull(tratadoNivel3), '', tratadoNivel3) as tratadoNivel3,
	 RowNo() as regraN
FROM
[D:\QlikView\Dados\Dropbox\Midia\De Para UTM Canais.xlsx]
(ooxml, embedded labels, table is [Dicionário Dinâmico]);

/*
dicionarioDinamico_temp2:
NoConcatenate
load distinct *
resident dicionarioDinamico_temp;

drop table dicionarioDinamico_temp;

dicionarioDinamico:
load *,
	 RowNo() as regraN
resident dicionarioDinamico_temp2;

drop table dicionarioDinamico_temp2;
*/

let vQtdRegras = Peek('regraN', -1, 'dicionarioDinamico');

for i = 0 to vQtdRegras - 1
	let vExatoSource = lower(Peek('exatoSource', $(i), 'dicionarioDinamico'));
	let vExatoCampaign = lower(Peek('exatoCampaign', $(i), 'dicionarioDinamico'));
	let vExatoMedium = lower(Peek('exatoMedium', $(i), 'dicionarioDinamico'));
	let vLikeSource = lower(Peek('likeSource', $(i), 'dicionarioDinamico'));
	let vLikeCampaign = lower(Peek('likeCampaign', $(i), 'dicionarioDinamico'));
	let vLikeMedium = lower(Peek('likeMedium', $(i), 'dicionarioDinamico'));
	let vTratadoNivel1 = text(Peek('tratadoNivel1', $(i), 'dicionarioDinamico'));
	let vTratadoNivel2 = text(Peek('tratadoNivel2', $(i), 'dicionarioDinamico'));
	let vTratadoNivel3 = text(Peek('tratadoNivel3', $(i), 'dicionarioDinamico'));

	DROPmediaTratada:
	LOAD source,
	     medium,
	     campaign,
	     pedidoBU,
		 '$(vTratadoNivel1)' as tratadoNivel1,
		 '$(vTratadoNivel2)' as tratadoNivel2,
		 '$(vTratadoNivel3)' as tratadoNivel3,
		 '$(i)' as regraN
	Resident depara
	where	pedidoBU = 'Dinda'
			and
			(not IsNull(source) and not IsNull(campaign) and not IsNull(medium))
			and
			(lower(source)='$(vExatoSource)' or 'x'='$(vExatoSource)')
			and
			(lower(campaign)='$(vExatoCampaign)' or 'x'='$(vExatoCampaign)')
			and
			(lower(medium)='$(vExatoMedium)' or 'x'='$(vExatoMedium)')
			and
			(index(lower(source),'$(vLikeSource)')>0 or 'x'='$(vLikeSource)')
			and
			(index(lower(campaign),'$(vLikeCampaign)')>0 or 'x'='$(vLikeCampaign)')
			and
			(index(lower(medium),'$(vLikeMedium)')>0 or 'x'='$(vLikeMedium)')
	;
next;

drop table dicionarioDinamico;

//exportar não tratados
	left join (depara)
	load * resident DROPmediaTratada;

	naoTratado:
	NoConcatenate
	LOAD source,
		 medium,
		 campaign,
		 registros
	Resident depara
	where isnull(tratadoNivel1)
	order by registros desc;

	store naoTratado into D:\QlikView\Dados\Dropbox\Midia\NãoTratado_Admin.txt (txt);

	drop tables naoTratado, depara;

mediaTratada:
NoConcatenate
LOAD
	source as pedidoUtmSource,
	medium as pedidoUtmMedium,
	campaign as pedidoUtmCampaign,
	pedidoBU,
	FirstValue(tratadoNivel1) as pedidoTratadoNivel1_temp,
	FirstValue(tratadoNivel2) as pedidoTratadoNivel2_temp,
	FirstValue(tratadoNivel3) as pedidoTratadoNivel3_temp
Resident DROPmediaTratada
Group By source, medium, campaign, pedidoBU
Order By regraN asc;

drop table DROPmediaTratada;

store mediaTratada into $(qvdDir)temp_mediaTratada.qvd (qvd);

//aplica em pedidos e clientes
	pedidos:
	load * from $(qvdDir)temp3_pedidos.qvd (qvd);

	left join (pedidos)
	load * resident mediaTratada;

	left join (clientes)
	load pedidoBU as clienteBU,
		 pedidoUtmSource as clienteUtmSource,
		 pedidoUtmMedium as clienteUtmMedium,
		 pedidoUtmCampaign as clienteUtmCampaign,
		 pedidoTratadoNivel1_temp as clienteTratadoNivel1_temp,
		 pedidoTratadoNivel2_temp as clienteTratadoNivel2_temp,
		 pedidoTratadoNivel3_temp as clienteTratadoNivel3_temp
	resident mediaTratada;

	drop table mediaTratada;

//ajustes para n/a
	clientes_new:
	load *,
		 if(isnull(clienteTratadoNivel1_temp), 'n/a', clienteTratadoNivel1_temp) as clienteTratadoNivel1,
		 if(isnull(clienteTratadoNivel2_temp), 'n/a', clienteTratadoNivel2_temp) as clienteTratadoNivel2,
		 if(isnull(clienteTratadoNivel3_temp), 'n/a', clienteTratadoNivel3_temp) as clienteTratadoNivel3
	resident clientes;

	drop table clientes;
	drop fields clienteTratadoNivel1_temp, clienteTratadoNivel2_temp, clienteTratadoNivel3_temp;

	pedidos_new:
	load *,
		 if(isnull(pedidoTratadoNivel1_temp), 'n/a', pedidoTratadoNivel1_temp) as pedidoTratadoNivel1,
		 if(isnull(pedidoTratadoNivel2_temp), 'n/a', pedidoTratadoNivel2_temp) as pedidoTratadoNivel2,
		 if(isnull(pedidoTratadoNivel3_temp), 'n/a', pedidoTratadoNivel3_temp) as pedidoTratadoNivel3
	resident pedidos;

	drop table pedidos;
	drop fields pedidoTratadoNivel1_temp, pedidoTratadoNivel2_temp, pedidoTratadoNivel3_temp;

//ajuste origem pelo utm_term e utm_gclid - ao final de tudo, sobrescreve todos
	//pedidos
		left join (pedidos_new)
		load pedidoIdUnico,

			 if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and trim(pedidoUtmTerm) <> '' and not isnull(pedidoUtmTerm) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), 'Paid Search',
			 	if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and (pedidoUtmTerm = '' or isnull(pedidoUtmTerm)) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), 'Display Ads',
			 		pedidoTratadoNivel1
			 )) as pedidoTratadoNivel1_new,

			 if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and trim(pedidoUtmTerm) <> '' and not isnull(pedidoUtmTerm) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), 'Google Search',
			 	if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and (pedidoUtmTerm = '' or isnull(pedidoUtmTerm)) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), 'Google DCO',
			 		pedidoTratadoNivel2
			 )) as pedidoTratadoNivel2_new,

			 if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and trim(pedidoUtmTerm) <> '' and not isnull(pedidoUtmTerm) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), '',
			 	if(trim(pedidoUtmGclid) <> '' and not isnull(pedidoUtmGclid) and (pedidoUtmTerm = '' or isnull(pedidoUtmTerm)) and (trim(pedidoTratadoNivel1) = 'n/a' or trim(pedidoTratadoNivel1) = '' or isnull(pedidoTratadoNivel1)), '',
			 		pedidoTratadoNivel3
			 )) as pedidoTratadoNivel3_new
		resident pedidos_new;

		drop fields pedidoTratadoNivel1, pedidoTratadoNivel2, pedidoTratadoNivel3;

		rename fields pedidoTratadoNivel1_new to pedidoTratadoNivel1,
					  pedidoTratadoNivel2_new to pedidoTratadoNivel2,
					  pedidoTratadoNivel3_new to pedidoTratadoNivel3;
	//clientes
		left join (clientes_new)
		load clienteIdUnico,

			 if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and trim(clienteUtmTerm) <> '' and not isnull(clienteUtmTerm) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), 'Paid Search',
			 	if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and (clienteUtmTerm = '' or isnull(clienteUtmTerm)) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), 'Display Ads',
			 		clienteTratadoNivel1
			 )) as clienteTratadoNivel1_new,

			 if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and trim(clienteUtmTerm) <> '' and not isnull(clienteUtmTerm) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), 'Google Search',
			 	if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and (clienteUtmTerm = '' or isnull(clienteUtmTerm)) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), 'Google DCO',
			 		clienteTratadoNivel2
			 )) as clienteTratadoNivel2_new,

			 if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and trim(clienteUtmTerm) <> '' and not isnull(clienteUtmTerm) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), '',
			 	if(trim(clienteUtmGclid) <> '' and not isnull(clienteUtmGclid) and (clienteUtmTerm = '' or isnull(clienteUtmTerm)) and (trim(clienteTratadoNivel1) = 'n/a' or trim(clienteTratadoNivel1) = '' or isnull(clienteTratadoNivel1)), '',
			 		clienteTratadoNivel3
			 )) as clienteTratadoNivel3_new
		resident clientes_new;

		drop fields clienteTratadoNivel1, clienteTratadoNivel2, clienteTratadoNivel3;

		rename fields clienteTratadoNivel1_new to clienteTratadoNivel1,
					  clienteTratadoNivel2_new to clienteTratadoNivel2,
					  clienteTratadoNivel3_new to clienteTratadoNivel3;

//store
	store pedidos_new into $(qvdDir)temp4_pedidos.qvd (qvd);
	drop table pedidos_new;

	store clientes_new into $(qvdDir)temp3_clientes.qvd (qvd);
	drop table clientes_new;
///$tab Impostos
pedidos:
load * from $(qvdDir)temp4_pedidos.qvd (qvd);

//dinda
	impostos:
	LOAD Mês as pedidoDataMes,
	     [Imposto sobre receita] as impostoReceita,
	     [Imposto sobre custo bruto] as impostoCusto,
	     [Imposto sobre custo frete] as impostoFrete,
	     'Dinda' as pedidoBU
	FROM
	[D:\QlikView\Dados\Dados temp para novo Dashboard\External data.xlsx]
	(ooxml, embedded labels, table is [Dinda - Impostos]);

left join (pedidos)
load * resident impostos;

drop table impostos;

left join (pedidos)
load pedidoIdUnico,
	 pedidoReceitaBruta * impostoReceita as pedidoImpostoReceita,
	 pedidoCustoBrutoDeProdutos * impostoCusto as pedidoImpostoCustoBrutoDeProdutos,
	 pedidoCustoFrete * impostoFrete as pedidoImpostoCustoFrete
resident pedidos;

drop fields impostoReceita, impostoCusto, impostoFrete;

store pedidos into $(qvdDir)temp5_pedidos.qvd (qvd);
drop table pedidos;
///$tab Custos
pedidos:
load * from $(qvdDir)temp5_pedidos.qvd (qvd);

//ADQUIRENTE
	taxas:
	LOAD Mês as mes,
	     Boleto as boleto,
	     [Debito online] as debito,
	     [Taxa parcela 1] as taxa1,
	     [Taxa parcela 2] as taxa2,
	     [Taxa parcela 3] as taxa3,
	     [Taxa parcela 4] as taxa4,
	     [Taxa parcela 5] as taxa5,
	     [Taxa parcela 6] as taxa6,
	     [Taxa parcela 7] as taxa7,
	     [Taxa parcela 8] as taxa8,
	     [Taxa parcela 9] as taxa9,
	     [Taxa parcela 10] as taxa10,
	     [Taxa parcela 11] as taxa11,
	     [Taxa parcela 12] as taxa12
	FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx] (ooxml, embedded labels, table is Adquirente);

	left join (pedidos)
	load mes as pedidoDataMes,
		 'Boleto' as pedidoPagamentoForma,
		 boleto
	resident taxas;

	left join (pedidos)
	load mes as pedidoDataMes,
		 'Débito Online' as pedidoPagamentoForma,
		 debito
	resident taxas;

	for i = 1 to 12
		trace Cartão de crédito - $(i) parcelas;
		left join (pedidos)
		load mes as pedidoDataMes,
			 'Cartão de Crédito' as pedidoPagamentoForma,
			 $(i) as pedidoPagamentoParcelas,
			 taxa$(i)
		resident taxas;
	next i;

	drop table taxas;

	left join (pedidos)
	load pedidoIdUnico,
		 numsum(taxa1, taxa2, taxa3, taxa4, taxa5, taxa6, taxa7, taxa8, taxa9, taxa10, taxa11, taxa12, boleto, debito) as pedidoCustoPagamento
	resident pedidos;

	drop fields taxa1, taxa2, taxa3, taxa4, taxa5, taxa6, taxa7, taxa8, taxa9, taxa10, taxa11, taxa12, boleto, debito;

//Antifraude
	//para custos estipulados por pedido
	left join (pedidos)
	LOAD [Pedido Id] as pedidoIdExt,
	     [Anti Fraude] as antiFraudePedido,
	     'Cartão de Crédito' as pedidoPagamentoForma //custo antifraude apenas para pagamento com cartão de crédito
	FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx] (ooxml, embedded labels, table is [Anti Fraude (pedido)]);

	//para custos fixos no mês
	left join (pedidos)
	LOAD Mês as pedidoDataMes,
	     [Anti fraude] as antiFraudeMes,
	     'Cartão de Crédito' as pedidoPagamentoForma //custo antifraude apenas para pagamento com cartão de crédito
	FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx] (ooxml, embedded labels, table is [Anti Fraude]);

	left join (pedidos)
	load pedidoIdUnico,
		 if(not isnull(antiFraudePedido), antiFraudePedido, antiFraudeMes) as pedidoCustoAntifraude
	resident pedidos;

	drop fields antiFraudePedido, antiFraudeMes;

//Gateway
	left join (pedidos)
	LOAD Mês as pedidoDataMes,
	     [Custo Gateway por Pedido] as pedidoCustoGateway
	FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx] (ooxml, embedded labels, table is Gateway);

//Embalagem
	left join (pedidos)
	load Mês as pedidoDataMes,
		 [Custo Embalagem no Mês] as custoMes
	FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx] (ooxml, embedded labels, table is Embalagem);

	//rateio do custo de embalagem do mês aos pedidos
	left join (pedidos)
	load pedidoDataMes,
		 firstvalue(custoMes) / count(distinct pedidoIdUnico) as pedidoCustoEmbalagem
	resident pedidos
	group by pedidoDataMes;

	drop fields custoMes from pedidos;

//Fulfillment e Production
	left join (pedidos)
	LOAD Mês as pedidoDataMes,
	     sum([Fulfillment - staff]) as fulfillmentStaffDinda,
	     sum([Fulfillment - warehouse]) as fulfillmentCdDinda,
	     'Dinda' as pedidoBU
	FROM
	[D:\QlikView\Dados\Dropbox\Financeiro Mensal\Dados Externos.xlsx]
	(ooxml, embedded labels, table is [Dinda - Fulfillment])
	group by Mês;

	left join (pedidos)
	LOAD Mês as pedidoDataMes,
	     [Production - Staff] as productionStaffDinda,
	     [Production - Studios] as productionStudiosDinda,
	     'Dinda' as pedidoBU
	FROM
	[D:\QlikView\Dados\Dados temp para novo Dashboard\External data.xlsx]
	(ooxml, embedded labels, table is [Dinda - Production]);

	//distribuição
		left join (pedidos)
		load pedidoDataMes,
			 pedidoBU,
			 sum(pedidoReceitaBruta) as totalReceitaMes
		resident pedidos
		group by pedidoDataMes, pedidoBU;

		left join (pedidos)
		load pedidoIdUnico,
			 numsum(/*fulfillmentStaffBaby, */fulfillmentStaffDinda) * (pedidoReceitaBruta / totalReceitaMes) as pedidoFulfillmentStaff,
			 numsum(/*fulfillmentCdBaby, */fulfillmentCdDinda) * (pedidoReceitaBruta / totalReceitaMes) as pedidoFulfillmentCd,
			 numsum(/*productionStaffBaby, */productionStaffDinda) * (pedidoReceitaBruta / totalReceitaMes) as pedidoProductionStaff,
			 numsum(/*productionStudiosBaby, */productionStudiosDinda) * (pedidoReceitaBruta / totalReceitaMes) as pedidoProductionStudios
		resident pedidos;

		drop fields /*fulfillmentStaffBaby, */fulfillmentStaffDinda,
					/*fulfillmentCdBaby, */fulfillmentCdDinda,
					/*productionStaffBaby, */productionStaffDinda,
					/*productionStudiosBaby, */productionStudiosDinda;

store pedidos into $(qvdDir)temp6_pedidos.qvd (qvd);
drop table pedidos;
///$tab Frete custo real
pedidos:
load * from [$(qvdDir)temp6_pedidos.qvd] (qvd);

left join (pedidos)
load pedidoIdExt,
	 pedidoBU,
	 firstvalue(pedidoIdAbacos) as pedidoIdAbacos,
	 firstvalue(notaId) as notaId,
	 firstvalue(notaNumero) as notaNumero
from $(qvdDir)abacos_notas.qvd (qvd)
group by pedidoIdExt, pedidoBU;

logistics:
load Serie,
	 [NF baby],
	 [Valor frete]
FROM [D:\QlikView\Dados\Dropbox\Financeiro Mensal\Logistics.txt]
(txt, codepage is 1252, embedded labels, delimiter is ';', msq);

left join (pedidos)
LOAD if(Serie = 1, 'Baby', 'Dinda') as pedidoBU,
     replace([NF baby], ',00', '') as notaNumero,
     firstvalue([Valor frete]) as freteReal
resident logistics
group by if(Serie = 1, 'Baby', 'Dinda'),
		 replace([NF baby], ',00', '')
;

drop table logistics;

rename field pedidoCustoFrete to pedidoCustoFrete_admin;

left join (pedidos)
load pedidoIdUnico,
	 if(not isnull(freteReal), freteReal, pedidoCustoFrete_admin) as pedidoCustoFrete
resident pedidos;

drop field freteReal;

store pedidos into $(qvdDir)temp7_pedidos.qvd (qvd);
drop table pedidos;
///$tab LTV
//pedidos:
//load * from $(qvdDir)temp7_pedidos.qvd (qvd);
//
//clientes:
//load * from $(qvdDir)temp3_clientes.qvd (qvd);
//
///*
////Baby
//	vetorLTV:
//	load pedidoDistanciaFtp as distancia,
//		 sum(pedidoReceitaBruta) as receita
//	resident pedidos
//	where pedidoBU = 'Baby' and not isnull(pedidoDistanciaFtp)
//	group by pedidoDistanciaFtp
//	order by pedidoDistanciaFtp;
//
//	let maxDistancia = peek('distancia', -1, 'vetorLTV');
//
//	ftbs:
//	load monthname(clienteDataFtp) as mes,
//		 count(distinct clienteIdUnico) as users,
//		 rowno() - 1 as row
//	resident clientes
//	where not isnull(clienteDataFtp)
//	group by monthname(clienteDataFtp)
//	order by clienteDataFtp;
//
//	for i = 0 to $(maxDistancia)
//		ftbs_join:
//		load $(i) as distancia,
//			 sum(if(row <= ($(maxDistancia) - $(i)), users)) as users
//		resident ftbs;
//	next i;
//
//	drop table ftbs;
//
//	left join (vetorLTV)
//	load * resident ftbs_join;
//
//	drop table ftbs_join;
//
//	left join (vetorLTV)
//	load distancia,
//		 receita / users as ltvReceita
//	resident vetorLTV;
//
//	left join (vetorLTV)
//	load distancia + 1 as distancia,
//		 ltvReceita as ltvReceita_mesAnterior
//	resident vetorLTV;
//
//	left join (vetorLTV)
//	load distancia,
//		 ltvReceita / ltvReceita_mesAnterior as varReceita
//	resident vetorLTV;
//
//	//apenas até mês 12, pois dados não são significativos nos últimos meses e alteram muito na média
//	vars:
//	load avg(if(distancia > 1 and distancia <= 12, varReceita)) as avgVarReceita,
//		 sum(if(distancia = 1, varReceita)) as firstVarReceita
//	resident vetorLTV;
//
//	let LTV_Var1_Baby = peek('firstVarReceita');
//	let LTV_Var2_Baby = peek('avgVarReceita');
//
//	drop tables vars, vetorLTV;
//*/
//
////Dinda
//	vetorLTV:
//	load pedidoDistanciaFtp as distancia,
//		 sum(pedidoReceitaBruta) as receita
//	resident pedidos
//	where pedidoBU = 'Dinda' and not isnull(pedidoDistanciaFtp)
//	group by pedidoDistanciaFtp
//	order by pedidoDistanciaFtp;
//
//	let maxDistancia = peek('distancia', -1, 'vetorLTV');
//
//	trace maxdis: $(maxDistancia);
//
//	if '$(maxDistancia)' = '' then
//		exit script;
//	end if;
//
//	ftbs:
//	load monthname(clienteDataFtp) as mes,
//		 count(distinct clienteIdUnico) as users,
//		 rowno() - 1 as row
//	resident clientes
//	where not isnull(clienteDataFtp)
//	group by monthname(clienteDataFtp)
//	order by clienteDataFtp;
//
//	for i = 0 to $(maxDistancia)
//		ftbs_join:
//		load $(i) as distancia,
//			 sum(if(row <= ($(maxDistancia) - $(i)), users)) as users
//		resident ftbs;
//	next i;
//
//	drop table ftbs;
//
//	left join (vetorLTV)
//	load * resident ftbs_join;
//
//	drop table ftbs_join;
//
//	left join (vetorLTV)
//	load distancia,
//		 receita / users as ltvReceita
//	resident vetorLTV;
//
//	left join (vetorLTV)
//	load distancia + 1 as distancia,
//		 ltvReceita as ltvReceita_mesAnterior
//	resident vetorLTV;
//
//	left join (vetorLTV)
//	load distancia,
//		 ltvReceita / ltvReceita_mesAnterior as varReceita
//	resident vetorLTV;
//
//	//apenas até mês 12, pois dados não são significativos nos últimos meses e alteram muito na média
//	vars:
//	load avg(if(distancia > 1 and distancia <= 12, varReceita)) as avgVarReceita,
//		 sum(if(distancia = 1, varReceita)) as firstVarReceita
//	resident vetorLTV;
//
//	store vetorLTV into $(qvdDir)temp_vetorLTV.qvd (qvd);
//
//	let LTV_Var1_Dinda = peek('firstVarReceita');
//	let LTV_Var2_Dinda = peek('avgVarReceita');
//
//	drop tables vars, vetorLTV;
//
//drop tables clientes, pedidos;
//
////tabela final
//	ltv:
//	load //'$(LTV_Var1_Baby)' as LTV_Var1_Baby,
//		 //'$(LTV_Var2_Baby)' as LTV_Var2_Baby,
//		 '$(LTV_Var1_Dinda)' as LTV_Var1_Dinda,
//		 '$(LTV_Var2_Dinda)' as LTV_Var2_Dinda
//	AutoGenerate 1;
//
//	store ltv into $(qvdDir)ltv.qvd (qvd);
//	drop table ltv;
///$tab Admin Mg Contrib
////Inserção de Admin - margens de contribuição por mês - para inserção em LTV
///*
//adminMgContrib_temp:
//LOAD Mês as pedidoDataMes,
//	 'Baby' as pedidoBU,
//     [MC com Fulfillment] as adminMgContribComFulfillment,
//     [MC sem Fulfillment] as adminMgContribSemFulfillment
//FROM
//[D:\QlikView\Dados\Dropbox\Financeiro Mensal\Margem_Admin_LTV.xlsx]
//(ooxml, embedded labels, table is Baby);
//*/
//
//adminMgContrib_temp:
//LOAD Mês as pedidoDataMes,
//	 'Dinda' as pedidoBU,
//     [MC com Fulfillment] as adminMgContribComFulfillment,
//     [MC sem Fulfillment] as adminMgContribSemFulfillment
//FROM
//[D:\QlikView\Dados\Dropbox\Financeiro Mensal\Margem_Admin_LTV.xlsx]
//(ooxml, embedded labels, table is Dinda);
//
//adminMgContrib:
//NoConcatenate
//load pedidoDataMes,
//	 pedidoBU,
//	 firstvalue(adminMgContribComFulfillment) as adminMgContribComFulfillment,
//	 firstvalue(adminMgContribSemFulfillment) as adminMgContribSemFulfillment
//resident adminMgContrib_

//group by pedidoDataMes, pedidoBU;
//
//drop table adminMgContrib_temp;
//
//pedidos:
//load * from $(qvdDir)temp7_pedidos.qvd (qvd);
//
//left join (pedidos)
//load * resident adminMgContrib;
//
//drop table adminMgContrib;
//
//left join (pedidos)
//load pedidoIdUnico,
//	 pedidoReceitaBruta * adminMgContribComFulfillment as pedidoMgContribAdminComFulfillment,
//	 pedidoReceitaBruta * adminMgContribSemFulfillment as pedidoMgContribAdminSemFulfillment
//resident pedidos;
//
//drop fields adminMgContribComFulfillment, adminMgContribSemFulfillment;
//
//store pedidos into $(qvdDir)temp8_pedidos.qvd (qvd);
//drop table pedidos;
///$tab ExactTarget Envios
//SET ThousandSep=',';
//SET DecimalSep='.';
//
///*
//summary_temp:
//LOAD *,
//	 'Baby' as emailBU,
//	 date(if(isnum(left(EmailName, 8)), date#(left(EmailName, 8), 'YYYYMMDD'), date#(left(SendStartTime, 10), 'DD/MM/YYYY')), 'DD/MM/YYYY') as emailDate
//FROM
//[D:\QlikView\Dados\ExactTarget\Baby\reports\lucida_Account-send-summary\*.csv]
//(txt, codepage is 1252, embedded labels, delimiter is ',', msq);
//*/
//
//summary_temp:
//LOAD *,
//	 'Dinda' as emailBU,
//	 date(if(isnum(left(EmailName, 8)), date#(left(EmailName, 8), 'YYYYMMDD'), date#(left(SendStartTime, 10), 'DD/MM/YYYY')), 'DD/MM/YYYY') as emailDate
//FROM
//[D:\QlikView\Dados\ExactTarget\Dinda\reports\Account_Send_Summary\*.csv]
//(txt, codepage is 1252, embedded labels, delimiter is ',', msq);
//
//accountSendSummary:
//load EmailName as emailName,
//	 emailDate,
//	 floor(monthname(emailDate)) as emailDateMes,
//	 year(emailDate) as emailDateAno,
//	 emailBU,
//	 if(isnum(left(EmailName, 8)), mid(EmailName, 10), 'Other') as emailType,
//	 sum(Sends) as emailSends,
//	 sum(ImplicitDeliveries) as emailImplicitDeliveries,
//	 sum(UniqueOpens) as emailUniqueOpens,
//	 sum(UniqueClicks) as emailUniqueClicks,
//	 sum(UniqueUnsubscribes) as emailUniqueUnsubscribes
//resident summary_temp
//group by EmailName, emailDate, emailBU;
//
//drop table summary_temp;
//
//	temp:
//	LOAD @1 as date,
//	     @2 as source,
//	     @7 as visits,
//	     'Dinda' as emailBU
//	FROM
//	[D:\QlikView\Dados\GA\Dinda\Visits\*.csv]
//	(txt, utf8, no labels, delimiter is ',', msq);
//
//	transacoes:
//	LOAD @1 as date,
//	     @2 as source,
//	     @5 as transactionId,
//	     @8 as transactionRevenue,
//	     'Dinda' as emailBU
//	FROM
//	[D:\QlikView\Dados\GA\Dinda\Transacoes\*.csv]
//	(txt, codepage is 1252, no labels, delimiter is ',', msq);
//
//	outer join (temp)
//	load * resident transacoes;
//
//	drop table transacoes;
//
//	/*
//	Concatenate (temp)
//	load * resident tempDinda;
//
//	drop table tempDinda;
//	*/
//
//	store temp into [$(qvdDir)exactTarget_GA_temp.qvd] (qvd);
//	store accountSendSummary into [$(qvdDir)temp_accountSendSummary.qvd] (qvd);
//
//	temp_2:
//	load source as emailName,
//		 //date(date#(date, 'YYYYMMDD'), 'DD/MM/YYYY') as emailDate,
//		 date(if(isnum(left(source, 8)), date#(left(source, 8), 'YYYYMMDD'), date#(date, 'YYYYMMDD')), 'DD/MM/YYYY') as emailDate,
//		 visits,
//		 transactionId,
//		 transactionRevenue
//	resident temp;
//
//	drop table temp;
//
//	left join (accountSendSummary)
//	load emailName,
//		 emailDate,
//		 sum(visits) as emailVisits,
//		 count(distinct transactionId) as emailTransactions,
//		 sum(transactionRevenue) as emailRevenue
//	resident temp_2
//	group by emailName, emailDate;
//
//	drop table temp_2;
//
//SET ThousandSep='.';
//SET DecimalSep=',';
//
//store accountSendSummary into $(qvdDir)exactTarget_accountSendSummary.qvd (qvd);
//drop table accountSendSummary;
///$tab ExactTarget Users
//clientes:
//load * from $(qvdDir)temp3_clientes.qvd (qvd);
//
////unsubscribed users
//	Set ErrorMode = 0; //desconsiderar txt vazios ou com eventuais erros
//		//exact target
//		unsubscribes:
//		LOAD EmailAddress as clienteEmail,
//			 'Dinda' as clienteBU
//		FROM
//		[D:\QlikView\Dados\ExactTarget\Dinda\Export\unsubscribes_*.txt]
//		(txt, codepage is 1252, embedded labels, delimiter is '\t', msq);
//
//		//exact target histórico
//		unsubscribes:
//		LOAD [Email Address] as clienteEmail,
//			 'Dinda' as clienteBU
//		FROM
//		D:\QlikView\Dados\ExactTarget\Dinda\Export\export_Unsubs_01232014.csv
//		(txt, codepage is 1252, embedded labels, delimiter is '\t', msq);
//
//		//responsys
//		unsubscribes:
//		LOAD EMAIL as clienteEmail,
//			 'Dinda' as clienteBU
//		FROM
//		D:\QlikView\Dados\Responsys\opt_out\*_OPT_OUT_*.txt
//		(txt, codepage is 1252, embedded labels, delimiter is ';', msq);
//	Set ErrorMode = 1;
//
//	//inserção do campo na table de users
//	left join (clientes)
//	LOAD distinct
//		*,
//		1 as unsubscribed
//	resident unsubscribes;
//
//	drop table unsubscribes;
//
////abertura de e-mails
//	temp:
//	LOAD * FROM [D:\QlikView\Dados\ExactTarget\Dinda\Export\opens60d_*.txt] (txt, unicode, embedded labels, delimiter is ',', msq);
//
//	opened:
//	LOAD SubscriberKey as clienteEmail,
//		 EventDate
//	resident temp
//	order by EventDate desc;
//
//	drop table temp;
//
//	//responsys
//	temp_2:
//	NoConcatenate
//	LOAD EMAIL_ADDRESS_ as clienteEmail
//	FROM
//	D:\QlikView\Dados\Responsys\engajado_interact\engajado_interact.csv
//	(txt, utf8, embedded labels, delimiter is ',', msq);
//
//	concatenate (opened)
//	load *
//	resident temp_2;
//
//	drop table temp_2;
//
//	left join (clientes)
//	load clienteEmail,
//		 firstvalue(floor(date#(left(EventDate, 10), 'YYYY-MM-DD'))) as clienteAberturaEmailData,
//		 1 as clienteAbriuEmail
//	resident opened
//	group by clienteEmail;
//
//	drop table opened;
//
//	left join (clientes)
//	load distinct
//		clienteAberturaEmailData,
//		rangemin(floor(today() - clienteAberturaEmailData), 60) as clienteAberturaEmailDistancia,
//
//		if(today() - clienteAberturaEmailData <= 15, '0 - 15 dias',
//			if(today() - clienteAberturaEmailData <= 30, '15 - 30 dias',
//				if(today() - clienteAberturaEmailData <= 45, '30 - 45 dias', '45 - 60 dias'
//		))) as clienteAberturaEmailGrupo
//	resident clientes;
//
////finalização
//	left join (clientes)
//	load clienteIdUnico,
//		 if(clienteAbriuEmail = 1, 'Sim', 'Não') as clienteAberturaEmail,
//		 if(isnull(unsubscribed), 'Não', 'Sim') as clienteUnsubscribed
//	resident clientes;
//
//	drop fields unsubscribed, clienteAbriuEmail
//	from clientes;
//
//store clientes into $(qvdDir)temp4_clientes.qvd (qvd);
//drop table clientes;
///$tab Despesas marketing
//set marketingFile = D:\QlikView\Dados\Dropbox\Midia\Other Marketing Expenses_Qlikview.xls*;
//
////valores por mês
//	input:
//	LOAD *,
//		 rowno() as RowNo
//	FROM [$(marketingFile)]
//	(ooxml, no labels, header is 2 lines, table is Input)
//	where C <> '' and not isnull(C);
//
////proporção Baby Dinda
//	proporcao:
//	NoConcatenate
//	LOAD *,
//		 rowno() as RowNo
//	FROM [$(marketingFile)]
//	(ooxml, no labels, header is 2 lines, table is [Proporção Dinda-Baby])
//	where C <> '' and not isnull(C);
//
////loop para gerar tabela de valores
//	let continue = 1;
//	for i = 3 to 999
//		if ($(continue) = 1) then
//			let fieldname = fieldname($(i), 'input');
//			if ('$(fieldname)' = 'RowNo') then //última
//				let continue = 0;
//			else
//				marketing_temp:
//				load C as marketingNome,
//					 monthname(peek('$(fieldname)', 0, 'input')) as pedidoDataMes,
//					 $(fieldname) as marketingValor
//				resident input
//				where RowNo > 1;
//
//				proporcao2:
//				load C as marketingNome,
//					 monthname(peek('$(fieldname)', 0, 'input')) as pedidoDataMes,
//					 $(fieldname) as marketingProporcaoDinda
//				resident proporcao
//				where RowNo > 1;
//			end if;
//		end if;
//	next i;
//
//	outer join (marketing_temp)
//	load * resident proporcao2;
//
//	marketing:
//	load marketingNome,
//		 pedidoDataMes,
//		 marketingValor * (1 - marketingProporcaoDinda) as marketingValor,
//		 'Baby' as pedidoBU
//	resident marketing_temp;
//
//	concatenate (marketing)
//	load marketingNome,
//		 pedidoDataMes,
//		 marketingValor * marketingProporcaoDinda as marketingValor,
//		 'Dinda' as pedidoBU
//	resident marketing_temp;
//
//	drop tables input, proporcao, proporcao2, marketing_temp;
//
////atribuição por nome
//	atribuicao:
//	NoConcatenate
//	LOAD *,
//		 rowno() as RowNo,
//		 'Baby' as pedidoBU
//	FROM [$(marketingFile)]
//	(ooxml, no labels, header is 4 lines, table is [Atribuição Baby])
//	where (C <> '' and not isnull(C)) or (E <> '' and not isnull(E));
//
//	concatenate (atribuicao)
//	LOAD *,
//		 rowno() as RowNo,
//		 'Dinda' as pedidoBU
//	FROM [$(marketingFile)]
//	(ooxml, no labels, header is 4 lines, table is [Atribuição Dinda])
//	where (C <> '' and not isnull(C)) or (E <> '' and not isnull(E));
//
////loop para gerar tabela de atribuições
//	let continue = 1;
//	for i = 4 to 999
//		if ($(continue) = 1) then
//			let fieldname = fieldname($(i), 'atribuicao');
//			if ('$(fieldname)' = 'RowNo') then //última
//				let continue = 0;
//			else
//				atribuicao2:
//				load C as marketingNome,
//					 pedidoBU,
//					 D as marketingAtribuicao,
//					 peek('$(fieldname)', 0, 'atribuicao') as marketingPagamento,
//					 peek('$(fieldname)', 1, 'atribuicao') as marketingCanal,
//					 $(fieldname) as marketingCanalPercentual
//				resident atribuicao
//				where RowNo > 2;
//			end if;
//		end if;
//	next i;
//
//	outer join (marketing)
//	load * resident atribuicao2;
//
//	drop tables atribuicao, atribuicao2;
//
////cálculos finais
//	marketing2:
//	NoConcatenate
//	load pedidoDataMes,
//		 marketingNome,
//		 marketingAtribuicao,
//		 marketingPagamento,
//		 marketingCanal,
//		 marketingValor * marketingCanalPercentual as marketingValor,
//		 pedidoBU
//	resident marketing
//	where marketingValor * marketingCanalPercentual > 0;
//
//	drop table marketing;
//	rename table marketing2 to marketing;
//
//store marketing into $(qvdDir)marketing.qvd (qvd);
//drop table marketing;
///$tab RFM, opt-in
//clientes:
//load * from $(qvdDir)temp4_clientes.qvd (qvd);
//
//pedidosConfirmados:
//load * from $(qvdDir)pedidos.qvd (qvd)
//where pedidoPagamentoConfirmado = 1 and exists(clienteIdUnico);
//
////RFM
//	for each BU in /*'Baby', */'Dinda'
//		rfm_$(BU):
//		load clienteIdUnico,
//			 sum(pedidoReceitaBruta) as clienteReceitaBruta,
//			 count(pedidoId) as clienteFrequencia,
//			 firstvalue(pedidoData) as clienteRecencia,
//			 rowno() as rowNo
//		resident pedidosConfirmados
//		where pedidoBU = '$(BU)'
//		group by clienteIdUnico
//		order by pedidoData desc;
//
//		let maxRows = peek('rowNo', -1, 'rfm_$(BU)');
//		drop field rowNo;
//
//		left join (rfm_$(BU))
//		load clienteIdUnico,
//			 ceil(rowno() / ($(maxRows) / 5)) as clienteClassificacaoReceita
//		resident rfm_$(BU)
//		order by clienteReceitaBruta desc, clienteFrequencia desc, clienteRecencia desc;
//
//		left join (rfm_$(BU))
//		load clienteIdUnico,
//			 ceil(rowno() / ($(maxRows) / 5)) as clienteClassificacaoFrequencia
//		resident rfm_$(BU)
//		order by clienteFrequencia desc, clienteReceitaBruta desc, clienteRecencia desc;
//
//		left join (rfm_$(BU))
//		load clienteIdUnico,
//			 ceil(rowno() / ($(maxRows) / 5)) as clienteClassificacaoRecencia
//		resident rfm_$(BU)
//		order by clienteRecencia desc, clienteReceitaBruta desc, clienteFrequencia desc;
//
//		if (NoOfRows('rfm') > 0) then
//			concatenate (rfm)
//			load * resident rfm_$(BU);
//		else
//			rfm:
//			NoConcatenate
//			load * resident rfm_$(BU);
//		end if;
//
//		drop table rfm_$(BU);
//	next BU;
//
//	left join (clientes)
//	load *,
//		 1 * (6 - clienteClassificacaoRecencia) + 2 * (6  - clienteClassificacaoFrequencia) + 3 * (6 - clienteClassificacaoReceita) as clienteRfmScore,
//		 if(1 * (6 - clienteClassificacaoRecencia) + 2 * (6  - clienteClassificacaoFrequencia) + 3 * (6 - clienteClassificacaoReceita) >= 27, 'Sim', 'Não') as clienteRfmIsVip
//	resident rfm;
//
//	drop table rfm;
//
////Dados finais
//	//opt-in/opt-out e ativo/inativo
//		left join (clientes)
//		load clienteIdUnico,
//			 if(clienteNewsletter = 'Sim' and clienteUnsubscribed <> 'Sim', 1, 0) as clienteOptIn,
//			 if(not isnull(clienteAberturaEmailData) or today() - clienteDataRegistro <= 30, 1, 0) as clienteIsAtivo //cadastro últimos 30 dias ou abertura e-mail 60 dias
//		resident clientes;
//
//	//buyer (pedido com status de pagamento ok) - conforme arquivo "Baby & Dinda v2.pptx": apenas pedidos com status [Capturado para Dinda] e [Pago / Captura com Sucesso para Baby]
//		left join (clientes)
//		load clienteIdUnico,
//			 count(distinct pedidoId) as clientePedidosPagos_temp,
//			 firstvalue(pedidoData) as clienteFtpPagoData
//		resident pedidosConfirmados
//		group by clienteIdUnico
//		order by pedidoData;
//
//	clientes_notnull:
//	load *,
//		 if(not isnull(clientePedidosPagos_temp), clientePedidosPagos_temp, 0) as clientePedidosPagos
//	resident clientes;
//
//	drop table clientes;
//	drop field clientePedidosPagos_temp;
//
//	rename table clientes_notnull to clientes;
//
//drop table pedidosConfirmados;
//
//store clientes into $(qvdDir)clientes.qvd (qvd);
//drop table clientes;
///$tab pedidos - distancia ultimo
//pedidos:
//load *
//from $(qvdDir)temp8_pedidos.qvd (qvd);
//
//left join (pedidos)
//load clienteIdUnico,
//	 clienteDataRegistro
//from $(qvdDir)clientes.qvd (qvd)
//where exists(clienteIdUnico);
//
//left join (pedidos)
//load clienteIdUnico,
//	 pedidoCardinal + 1 as pedidoCardinal,
//	 pedidoData as ultimaData
//resident pedidos;
//
//left join (pedidos)
//load pedidoId,
//	 pedidoData - if(pedidoCardinal > 1, ultimaData, clienteDataRegistro) as pedidoDistanciaUltimoPedido
//resident pedidos;
//
//drop fields ultimaData, clienteDataRegistro;
//store pedidos into $(qvdDir)pedidos.qvd (qvd);
//drop table pedidos;
///$tab Custo Total
//custoTotal:
//load pedidoDataMes as clienteDataRegistroMes,
//	 pedidoBU as clienteBU,
//	 if(not isnull(marketingCanal), marketingCanal, 'n/a') as clienteTratadoNivel1,
//	 sum(if(marketingAtribuicao = 'Activation' or marketingAtribuicao = 'Acquisition', marketingValor)) as custoTotal
//from $(qvdDir)marketing.qvd (qvd)
//group by pedidoDataMes,
//		 pedidoBU,
//		 if(not isnull(marketingCanal), marketingCanal, 'n/a');
//
//store custoTotal into $(qvdDir)custoTotal.qvd (qvd);
//drop table custoTotal;
//
///*
//custoTotal:
//load
//	pedidoDataMes as clienteDataRegistroMes,
//	pedidoBU as clienteBU,
//
//	(
//	//payment fees
//		sum(pedidoCustoPagamento)
//		+ sum(pedidoCustoGateway)
//		+ sum(pedidoCustoAntifraude)
//	)
//	+
//	(
//		//net shipping
//		sum(pedidoCustoFrete)
//		- sum(pedidoImpostoCustoFrete)
//	)
//	+
//	(
//		//packaging
//		sum(pedidoCustoEmbalagem)
//	)
//	+
//	(
//		//fulfillment
//		sum(pedidoFulfillmentStaff)
//		+ sum(pedidoFulfillmentCd)
//	)
//	+
//	(
//		//production
//		sum(pedidoProductionStaff)
//		+ sum(pedidoProductionStudios)
//	)
//	as custoTotal_temp
//from $(qvdDir.qvd (qvd)
//group by pedidoDataMes, pedidoBU;
//
//left join (custoTotal)
//load clienteDataRegistroMes,
//	 clienteBU,
//	 numsum(custoTotal_temp, marketing) as custoTotal
//resident custoTotal;
//
//drop fields custoTotal_temp, marketing;
//*/
///$tab Friday Export
////CORRIGIDO PARA TODO DIA - por segurança, termos backup de outros dias //toda sexta-feira fazer export de client segmentation
//let diadasemana = date(today(), 'www');
//let dianumero = day(today());
//
//if ('$(diadasemana)' = 'sex' or '$(dianumero)' = 1 or 1 = 1) then
//	clientes:
//	load * from $(qvdDir)clientes.qvd (qvd);
//
//	export:
//	load clienteBU as [Business Unit],
//		 count(distinct clienteIdUnico) as [Base Total],
//		 count(distinct if(clienteOptIn = 1, clienteIdUnico)) as [Opt-in],
//		 count(distinct if(clienteOptIn <> 1, clienteIdUnico)) as [Opt-out],
//		 count(distinct if(clienteOptIn = 1 and clientePedidosPagos >= 1, clienteIdUnico)) as Buyers,
//
//		 count(distinct if(clienteOptIn = 1 and (clientePedidosPagos = 0 or isnull(clientePedidosPagos)), clienteIdUnico)) as [Never Bought],
//		 count(distinct if(clienteOptIn = 1 and (clientePedidosPagos = 0 or isnull(clientePedidosPagos)) and clienteIsAtivo = 1, clienteIdUnico)) as [Never Bought - Ativos],
//		 count(distinct if(clienteOptIn = 1 and (clientePedidosPagos = 0 or isnull(clientePedidosPagos)) and clienteIsAtivo <> 1, clienteIdUnico)) as [Never Bought - Inativos],
//
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos = 1, clienteIdUnico)) as FTB,
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos = 1 and clienteIsAtivo = 1, clienteIdUnico)) as [FTB - Ativos],
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos = 1 and clienteIsAtivo <> 1, clienteIdUnico)) as [FTB - Inativos],
//
//		 count(distinct if(clienteOptIn = 1 and clientePedidosPagos >= 1 and clienteRfmIsVip = 'Sim', clienteIdUnico)) as VIP,
//		 count(distinct if(clienteOptIn = 1 and clientePedidosPagos >= 1 and clienteRfmIsVip = 'Sim' and clienteIsAtivo = 1, clienteIdUnico)) as [VIP - Ativos],
//		 count(distinct if(clienteOptIn = 1 and clientePedidosPagos >= 1 and clienteRfmIsVip = 'Sim' and clienteIsAtivo <> 1, clienteIdUnico)) as [VIP - Inativos],
//
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos > 1, clienteIdUnico)) as [1+ Compra],
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos > 1 and clienteIsAtivo = 1, clienteIdUnico)) as [1+ Compra - Ativos],
//		 count(distinct if(clienteOptIn = 1 and /*clientePedidosPagos >= 1 and*/ clienteRfmIsVip <> 'Sim' and clientePedidosPagos > 1 and clienteIsAtivo <> 1, clienteIdUnico)) as [1+ Compra - Inativos]
//	resident clientes
//	where clienteBU = 'Dinda'
//	group by clienteBU;
//
//	drop table clientes;
//
//	let todayname = date(today(), 'YYYY_MM_DD');
//
//	store export into [D:\QlikView\Dados\Dropbox\Outros (2)\Client Segmentation $(todayname).csv] (txt);
//	drop table export;
//end if;
///$tab Churn
//clientes:
//load clienteIdUnico,
//	 clienteIsAtivo,
//	 clienteTratadoNivel1,
//	 clienteTratadoNivel2,
//	 clienteTratadoNivel3,
//	 clienteBU,
//	 clienteOptIn
//from $(qvdDir)clientes.qvd (qvd);
//
//churn:
//load floor(today()) as churn_date,
//	 clienteTratadoNivel1 as churn_nivel1,
//	 clienteTratadoNivel2 as churn_nivel2,
//	 clienteTratadoNivel3 as churn_nivel3,
//	 clienteBU as churn_BU,
//	 count(distinct clienteIdUnico) as churn_registros,
//	 count(distinct if(clienteIsAtivo = 1 and clienteOptIn = 1, clienteIdUnico)) as churn_ativos_optin,
//	 count(distinct if(clienteIsAtivo = 1 and clienteOptIn <> 1, clienteIdUnico)) as churn_ativos_optout,
//	 count(distinct if(clienteIsAtivo <> 1 and clienteOptIn = 1, clienteIdUnico)) as churn_inativos_optin,
//	 count(distinct if(clienteIsAtivo <> 1 and clienteOptIn <> 1, clienteIdUnico)) as churn_inativos_optout
//resident clientes
//group by clienteTratadoNivel1,
//		 clienteTratadoNivel2,
//		 clienteTratadoNivel3,
//		 clienteBU;
//
//drop table clientes;
//
//let churnTodayFile = date(today(), 'YYYY-MM-DD');
//
//store churn into $(qvdDir)churn\churn_$(churnTodayFile).qvd (qvd);
//drop table churn;
///$tab Export RFM
//clientes:
//load * from $(qvdDir)clientes.qvd (qvd);
//
//export:
//load
//	clienteBU as [B.U.],
//	clienteEmail as [E-mail],
//	clienteId as ID,
//	date(clienteDataRegistro, 'YYYY-MM-DD') as [Data Registro],
//	date(clienteDataFtp, 'YYYY-MM-DD') as [Data Primeira Compra],
//	clienteTratadoNivel1 as [Origem - Nível 1],
//	clienteTratadoNivel2 as [Origem - Nível 2],
//	clienteRfmScore as [Pontuação],
//	clienteRfmIsVip as VIP,
//	date(clienteRecencia, 'YYYY-MM-DD') as [Recência],
//	clienteFrequencia as [Freqüência],
//	round(clienteReceitaBruta, 0.01) as Receita,
//	clienteClassificacaoRecencia as [Classif. Recência],
//	clienteClassificacaoFrequencia as [Classif. Freqüência],
//	clienteClassificacaoReceita as [Classif. Receita]
//resident clientes
//where
//	clientePedidosPagos > 0
//order by
//	clienteRfmScore desc,
//	clienteEmail asc;
//
//maxMonth:
//load date(rangemax(max(clienteDataRegistro), max(clienteRecencia)) - 1, 'YYYY-MM') as maxMonth
//resident clientes;
//
//drop table clientes;
//
//let maxMonth = peek('maxMonth');
//
//drop table maxMonth;
//
//store export into [D:\QlikView\Dados\Dropbox\RFM\RFM-$(maxMonth).csv] (txt);
//
//drop table export;
///$tab Export Orders Cardinal
//export_base:
//NoConcatenate
//load *
//from $(qvdDir)pedidos.qvd (qvd)
//where pedidoBU = 2 or pedidoBU = 'Dinda';
//
//left join (export_base)
//load *
//from $(qvdDir)clientes.qvd (qvd)
//where clienteBU = 2 or clienteBU = 'Dinda';
//
//export:
//load
//	clienteId as [Cliente ID],
//	clienteEmail as [Cliente E-mail],
//	date(clienteDataRegistro, 'DD/MM/YYYY') as [Cliente Data Registro],
//	pedidoId as [Pedido ID],
//	pedidoIdExt as [Pedido ID Ext],
//	date(pedidoData, 'DD/MM/YYYY') as [Pedido Data],
//	if(pedidoPagamentoConfirmado = 1, 'Sim', 'Não') as [Pedido Pagamento Confirmado],
//	pedidoCardinal as [Pedido Cardinal],
//	pedidoCardinalPago as [Pedido Cardinal (pago)],
//	pedidoDistanciaUltimoPedido as [Pedido Distância ao Anterior],
//	pedidoUtmSource as [Pedido UTM Source],
//	pedidoUtmMedium as [Pedido UTM Medium],
//	pedidoUtmCampaign as [Pedido UTM Campaign],
//	pedidoOperadora as [Pedido Operadora],
//	pedidoPagamentoParcelas as [Pedido Parcelas],
//	money(pedidoReceitaBruta) as [Pedido Receita Bruta],
//	pedidoStatus as [Pedido Status]
//resident export_base
//order by pedidoData, pedidoId;
//
//drop table export_base;
//
//let export_max_date = date(peek('Pedido Data', -1, 'export') - 1, 'YYYY-MM'); //para que em 1/1/2015, exporte até 31/12/2014
//
//store export into [D:\QlikView\Dados\Dropbox\Campanhas Dinda\Orders Cardinal $(export_max_date).csv] (txt);
//drop table export;
