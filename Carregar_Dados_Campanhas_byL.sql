///$tab main
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

set datasourceDir = D:\QlikView\DataSource\;
set qvdDir = D:\QlikView\Dados\QVD\Campanhas\;
set qvdDirAdmin = D:\QlikView\Dados\QVD\Admin\;
set tabelasExternasDir = D:\QlikView\Dados\Dropbox\Campanhas Dinda\;
set produtosDir = D:\QlikView\Dados\Dropbox\Exceis Produção Dinda (1)\;

//função para linkar campanhas do Admin com planilhas de produtos e estoques
set lucida_campanhaSlugProdutos = keepchar(lower($1), 'abcdefghijklmnopqrstuvwxyz0123456789');
///$tab teste
//QUALIFY *;
//
//OLD:
//LOAD
//	 produtoPrecoFinal,
//     campanhaSlugProdutos,
//     produtoId,
//     produtoCodigo,
//     produtoCodigoPai,
//     produtoReferencia,
//     produtoNomeOriginal,
//     produtoDescricao,
//     produtoCor,
//     produtoPrecoTabela,
//     produtoNomeTratado,
//     produtoGrupo,
//     produtoEstoque,
//     produtoTamanho,
//     produtoPrecoGrupoNome
//FROM
//D:\QlikView\Dados\QVD\Campanhas\produtos.qvd (qvd);
//
//
//NEW:
//LOAD
//	 skukey,
//     id,
//     productkey,
//     parent_product_id,
//     [Age Group],
//     Size,
//     [Supplier Size],
//     [Product Date],
//     [Product Year-Month],
//     [Product Updated],
//     brand_id,
//     brand_name,
//     Category,
//     Segment,
//     Gender,
//     Subcategory
//FROM
//D:\QlikView\DataSource\products_dimension.qvd (qvd);
//
//
//
//
//exit ;
//
///$tab campanhas
//obtém campanhas - se infos não existirem, mantém Nome e datas de início e término que existiam na tabela de produtos
	campanhas:
	LOAD campanhaId,
		 //$(lucida_campanhaSlugProdutos(campanhaNome)) & 'dinda' & date(campanhaDataInicio, 'MMYY') as campanhaSlugProdutos,
		 $(lucida_campanhaSlugProdutos(campanhaBrandName)) as campanhaSlugProdutos,
		 campanhaBrandName,
	     campanhaNome,
	     campanhaSlugTratado,
	     campanhaDataInicio,
	     campanhaDataInicio - 1 as campanhaDataInicioDia0,
	     campanhaDataFinal,
	     campanhaImagemHighlight,
	     campanhaImagemBanner,
	     dual(capitalize(date(campanhaDataInicio, 'MMM-YY')), floor(monthname(campanhaDataInicio))) as campanhaRotulo,
	     campanhaNomeRotulo,
	     campanhaNomeRotulo2,
	     $(lucida_campanhaSlugProdutos(lower(campanhaNomeRotulo))) as campanhaNomeRotuloSlug //para inserir quais campanhas já foram geradas (campanhas são salva com campanhaNomeRotulo mas removendo caracteres especiais)
	FROM [$(qvdDirAdmin)campanhas_New.qvd] (qvd)
	where campanhaDataInicio >= 42200;


//ppt nome
	left join (campanhas)
	load distinct campanhaId,
		 keepchar(campanhaNome & ' - ' & campanhaRotulo, 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-áéíóúÁÉÍÓÚãõÃÕàÀâêîôûÂÊÎÔÛçÇ &()äëïöüÄËÏÖÜ.') as campanhaPPTNome
	resident campanhas;

//obtém infos do de-para de marcas
	campanhas_depara_TEMP:
	LOAD trim(treated_slug) as treated_slug, //nome do de-para
		 trim(slug) as slug,
	     Marca,
	     [Tipo de marca],
	     [Tipo de campanha],
	     Gênero,
	     Exportação, //para manter valor no dump
	     rowno() as RowNo
	FROM [$(tabelasExternasDir)Campanhas De-Para.xlsx] (ooxml, embedded labels, table is [Sheet1]);

	campanhas_depara:
	NoConcatenate
	LOAD treated_slug,
		 slug,
	     trim(firstvalue(Marca)) as Marca,
	     trim(firstvalue([Tipo de marca])) as [Tipo de marca],
	     trim(firstvalue([Tipo de campanha])) as [Tipo de campanha],
	     trim(firstvalue(Gênero)) as Gênero,
	     trim(firstvalue(Exportação))as Exportação
	resident campanhas_depara_TEMP
	group by treated_slug, slug
	order by RowNo desc;

	drop table campanhas_depara_TEMP;

	left join (campanhas)
	LOAD treated_slug as campanhaSlugTratado,
	     firstvalue([Marca]) as campanhaMarca,
	     keepchar(firstvalue([Marca]), 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-áéíóúÁÉÍÓÚãõÃÕàÀâêîôûÂÊÎÔÛçÇ &()äëïöüÄËÏÖÜ.') as campanhaMarcaCorrigida, //usará como pasta para store do ppt
	     firstvalue([Tipo de marca]) as campanhaMarcaTipo,
	     firstvalue([Tipo de campanha]) as campanhaTipo,
	     firstvalue([Gênero]) as campanhaGenero
	resident campanhas_depara
	group by treated_slug;

	drop field treated_slug from campanhas;

	dump:
	load * from $(qvdDirAdmin)campaigns_dump.qvd (qvd)
	where offer_starts_at <= (today() + 1);

	left join (dump)
	load * resident campanhas_depara;

	drop table campanhas_depara;

	//formato e ordenação finais
	dump_2:
	NoConcatenate
	load
		offer_starts_at,
		offer_ends_at,
		Exportação,
		monthname(offer_starts_at) as rótulo,
		slug,
		treated_slug,
		name,
		name as [Marca],
		[Tipo de marca],
		if(isnull(brand_name),'vazio','single brand') as [Tipo de campanha],
		[Gênero],
		brand_name,
		brand_id,
		id,
		created_at,
		highlight,
		banner
	resident dump;

	drop table dump;

	store dump_2 into [D:\QlikView\Dados\Dropbox\Campanhas Dinda\Campanhas Admin Dump.csv] (txt);

//obtém quais campanhas não devem ser geradas pelo PPT
	doNotGeneratePPT:
	LOAD $(lucida_campanhaSlugProdutos(lower(@1))) as campanhaNomeRotuloSlug
	FROM
	D:\xampp\htdocs\CampaignsToExport\doNotGenerate.csv
	(txt, codepage is 1252, no labels, delimiter is '\t', msq);

	left join (campanhas)
	load Distinct
		 *,
		 1 as campanhaPPTNaoGerar
	resident doNotGeneratePPT;

	drop table doNotGeneratePPT;
	drop field campanhaNomeRotuloSlug from campanhas;

	//insere data máxima de pedidos - 1 (dia completo)
		pedidosMaxDate:
		load max([Data de Criação]) - 1 as pedidosMaxDate
		from $(qvdDirAdmin)admin_pedidos.qvd (qvd);

		let pedidosMaxDate = rangemax(0, floor(peek('pedidosMaxDate', 0, 'pedidosMaxDate')));

		drop table pedidosMaxDate;

		left join (campanhas)
		load distinct campanhaId,
			 if(
			 	campanhaPPTNaoGerar <> 1
			 	and
			 	campanhaDataFinal <= '$(pedidosMaxDate)'
			 	and
			 	campanhaTipo <> 'especial'
			 	and
			 	campanhaTipo <> 'super sale'
			 	and
			 	campanhaTipo <> 'conceito'
			 	,
			 	1
			 	,
			 	0
			 ) as campanhaPPTGerar
		resident campanhas;

		drop fields campanhaPPTNaoGerar;

//exporta campanhas não presentes no De-Para
	campanhasExport:
	NoConcatenate
	load distinct *
	resident dump_2
	where
		isnull(Marca)
		and
		isnull([Tipo de marca])
		and
		isnull([Tipo de campanha])
		and
		offer_ends_at <= '$(pedidosMaxDate)'
	;

	drop table dump_2;

	store campanhasExport into [$(tabelasExternasDir)Campanhas SEM DE-PARA.csv] (txt);
	drop table campanhasExport;

//remove campanhas em que Marca ou Tipo de Marca são "NA"
	campanhas_new:
	NoConcatenate
	load Distinct * resident campanhas
	where campanhaMarca <> 'NA' and campanhaMarcaTipo <> 'NA';

	drop table campanhas;
	rename table campanhas_new to campanhas;


store campanhas into $(qvdDir)campanhas.txt (txt);
store campanhas into $(qvdDir)campanhas.qvd (qvd);
///$tab produtos
// Produtos

	// Mapas
	Mapa_Campanha_Existente:
	MAPPING LOAD distinct
		campanhaSlugProdutos,
		1 as campanhaExiste
	FROM $(qvdDir)campanhas.qvd (qvd);


	produtos_temp:
	LOAD
		campaign_id&'|'&product_id	as campaign_productkey,
		trim(product_id)			as ChaveProduto,
	    sum(stock) 					as produtoEstoque
	FROM [$(datasourceDir)campaigns_products.qvd] (qvd)
	GROUP BY
		campaign_id&'|'&product_id,
		trim(product_id);



	LEFT JOIN(produtos_temp)
	LOAD
		 trim(id) 															as ChaveProduto,
		 trim(erp_code)														as produtoCodigo,
		 $(lucida_campanhaSlugProdutos(brand_name)) & '_' & trim(erp_code) 	as produtoId,
		 $(lucida_campanhaSlugProdutos(brand_name)) 																as campanhaSlugProdutos,
		 ApplyMap('Mapa_Campanha_Existente', $(lucida_campanhaSlugProdutos(brand_name)),0) 							as campanhaExiste,
	     trim(firstvalue(parent_product_id)) 							as produtoCodigoPai,
	     trim(firstvalue(parent_product_id)) 							as produtoReferencia,
	     trim(firstvalue(name)) 										as produtoNomeOriginal,
	     trim(firstvalue(name)) 										as produtoDescricao,
	     trim(firstvalue(capitalize(Subcategory))) 						as produtoGrupo_temp,
	     trim(firstvalue(supplier_color)) 								as produtoCor,
	     upper(firstvalue([Supplier Size])) 							as produtoTamanho_temp,
		 numsum(replace(firstvalue(product_original_price), '.', ','))  as produtoPrecoTabela,  //numsum() para converter texto em número
	     numsum(replace(firstvalue(product_final_price), '.', ',')) 	as produtoPrecoFinal,   //numsum() para converter texto em número
	     trim(firstvalue(Category & ' ' & Segment)) 					as campanhaMarcaTipo,
	     trim(firstvalue(Gender)) 										as campanhaGenero,
//	     sum(ApplyMap('Mapa_Estoque_Inicial',brand_id &'|'& productkey,0))		as produtoEstoque_1,
// 		 brand_id &'|'& productkey as campaignproductkey_P,

	     //remover tamanho do nome (Ex: "Calça estampada - G" ou "Calça estampada - PP" ou "Calça estampada - 25")
	     trim(firstvalue(if(left(right(trim(name), 4), 3) = ' - ', left(trim(name), len(trim(name)) - 4),
	     	if(left(right(trim(name), 5), 3) = ' - ', left(trim(name), len(trim(name)) - 5),
	     		name
	     )))) 															as produtoNomeTratado
	FROM [$(datasourceDir)products_dimension.qvd] (qvd)
	group by
		trim(id),
		trim(erp_code),
		$(lucida_campanhaSlugProdutos(brand_name)) & '_' & trim(erp_code),
		$(lucida_campanhaSlugProdutos(brand_name)),
		ApplyMap('Mapa_Campanha_Existente', $(lucida_campanhaSlugProdutos(brand_name)),0);



// Somente manter produtos de campanhas existentes; e redefinir nomes de grupos quando não existirem
	produtos:
	NoConcatenate
	load *,
		 if(not isnull(produtoGrupo_temp), produtoGrupo_temp, 'Sem Categoria') as produtoGrupo
	resident produtos_temp
	where campanhaExiste = 1;

	DROP TABLE produtos_temp;
	DROP FIELD produtoGrupo_temp,campanhaExiste,campaign_productkey,ChaveProduto FROM produtos;




// Ordenação dos tamanhos
	tamanhos:
	LOAD distinct upper(Tamanho) as tamanho
	FROM
	[$(tabelasExternasDir)Produtos - Ordenação Tamanhos.xls]
	(biff, embedded labels, table is [Sheet1$]);

	outer join (tamanhos)
	load distinct produtoTamanho_temp as tamanho
	resident produtos
	order by produtoTamanho_temp asc;

	left join (produtos)
	load distinct
		tamanho as produtoTamanho_temp,
		dual(tamanho, rowno()) as produtoTamanho
	resident tamanhos;

	drop table tamanhos;
	drop field produtoTamanho_temp;


// Mantém apenas campanhas para as quais existem planilhas de produtos; transfere características da campanha que estão nas planilhas de produtos
	left join (campanhas)
	load distinct
		campanhaSlugProdutos,
		firstvalue(campanhaMarcaTipo) as campanhaMarcaTipo_2,
		firstvalue(campanhaGenero) as campanhaGenero_2,
		1 as existe
	resident produtos
	group by campanhaSlugProdutos;

	drop fields campanhaMarcaTipo, campanhaGenero from produtos;

	//mantém apenas as campanhas que existem; utiliza MarcaTipo e Gênero das planilhas de produtos para campanhas a partir de dezembro de 2014 (c.c. utiliza do De-para de campanhas do Dropbox)
		campanhas_new:
		NoConcatenate
		load Distinct
			 *,
			 if(floor(monthstart(campanhaDataInicio)) < floor(makedate(2014, 12, 1)), campanhaMarcaTipo, campanhaMarcaTipo_2) as campanhaMarcaTipo_3,
			 if(floor(monthstart(campanhaDataInicio)) < floor(makedate(2014, 12, 1)), campanhaGenero, campanhaGenero_2) as campanhaGenero_3
		resident campanhas
		where existe = 1;

		drop table campanhas;
		rename table campanhas_new to campanhas;

		drop fields
			existe,
			campanhaMarcaTipo,
			campanhaMarcaTipo_2,
			campanhaGenero,
			campanhaGenero_2
		from campanhas;

		rename fields
			campanhaMarcaTipo_3 to campanhaMarcaTipo,
			campanhaGenero_3 to campanhaGenero;



store produtos into $(qvdDir)produtos.qvd (qvd);


///$tab price range
////////////////////////////////////////// Cálculo de faixas de preço ////////////////////////////////////////////////
//
// Para cada "tipo" de campanha (slugTratado), será utilizada a última campanha, para determinar as faixas de preço
// de acordo com quartil 1, mediana e quartil 3 dos produtos por preço de estoque
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

left join (produtos)
load distinct
	campanhaSlugProdutos,
	campanhaSlugTratado
resident campanhas;

//obtém apenas a última campanha de cada tipo
produtos_baseCalculo:
load Distinct
	 campanhaSlugTratado,
	 firstvalue(campanhaSlugProdutos) as campanhaSlugProdutos
resident campanhas
group by campanhaSlugTratado
order by campanhaId desc;

//traz todos os produtos da última campanha de cada tipo
left join (produtos_baseCalculo)
load campanhaSlugProdutos,
	 produtoPrecoFinal,
	 produtoEstoque
resident produtos;

drop field campanhaSlugProdutos from produtos_baseCalculo;

left join (produtos_baseCalculo)
load campanhaSlugTratado,
	 round(sum(produtoPrecoFinal * produtoEstoque) / sum(produtoEstoque), 1) as median
resident produtos_baseCalculo
group by campanhaSlugTratado;

left join (produtos_baseCalculo)
load campanhaSlugTratado,
	 round(sum(produtoPrecoFinal * produtoEstoque) / sum(produtoEstoque), 1) as q1
resident produtos_baseCalculo
where produtoPrecoFinal < median
group by campanhaSlugTratado;

left join (produtos_baseCalculo)
load campanhaSlugTratado,
	 round(sum(produtoPrecoFinal * produtoEstoque) / sum(produtoEstoque), 1) as q3
resident produtos_baseCalculo
where produtoPrecoFinal > median
group by campanhaSlugTratado;

//traz todos os preços das outras campanhas desse tipo
produtos_todosPrecos:
load distinct
	campanhaSlugTratado,
	produtoPrecoFinal
resident produtos;

left join (produtos_todosPrecos)
load distinct
	campanhaSlugTratado,
	median,
	q1,
	q3
resident produtos_baseCalculo;

drop table produtos_baseCalculo;

left join (produtos_todosPrecos)
load distinct
	campanhaSlugTratado,
	produtoPrecoFinal,

	if(isnull(q1) and isnull(q3), 'R$' & round(produtoPrecoFinal, 0.01)
	,
	if(isnull(q1),
		if(produtoPrecoFinal < median, 'Abaixo de R$' & (median - 0.01)
		,
		if(produtoPrecoFinal >= median and produtoPrecoFinal < q3, 'R$' & median & '-' & (q3 - 0.01)
		,
		'R$' & q3 & '+'
		))
	,
	if(isnull(q3),
		if(produtoPrecoFinal < q1, 'Abaixo de R$' & (q1 - 0.01)
		,
		if(produtoPrecoFinal >= q1 and produtoPrecoFinal < median, 'R$' & q1 & '-' & (median - 0.01)
		,
		'R$' & median & '+'
		))
	,
		if(produtoPrecoFinal < q1, 'Abaixo de R$' & (q1 - 0.01)
		,
		if(produtoPrecoFinal >= q1 and produtoPrecoFinal < median, 'R$' & q1 & '-' & (median - 0.01)
		,
		if(produtoPrecoFinal >= median and produtoPrecoFinal < q3, 'R$' & median & '-' & (q3 - 0.01)
		,
		'R$' & q3 & '+'
		)))
	))) as produtoPrecoGrupoNome
resident produtos_todosPrecos;

left join (produtos)
load distinct
	campanhaSlugTratado,
	produtoPrecoFinal,
	produtoPrecoGrupoNome
resident produtos_todosPrecos;

drop table produtos_todosPrecos;
drop field campanhaSlugTratado from produtos;


///$tab pedidos, itens
// Carrega pedidos
	pedidos:
	LOAD 'Dinda_' & [ID privado] as pedidoIdUnico,
	     floor([Data de Criação]) as pedidoData,
	     hour([Data de Criação]) as pedidoHora,
	     'Dinda_' & [Cliente ID] as clienteIdUnico,
	     trim(if(not isnull([Status ERP]), [Status ERP], '-')) as pedidoStatus,
	     trim(if(not isnull([Status Pagamento]), [Status Pagamento], '-')) as pedidoStatusPagamento,
	     lower(trim(if(not isnull([Estado Pedido]), [Estado Pedido], '-'))) as pedidoStatus2,
	     //[Estado Pedido - Incluir] as pedidoStatusIncluir,
	     [Status ERP e Pagamento - Incluir] as pedidoStatusIncluir_ErpEPagamento
	from $(qvdDirAdmin)admin_pedidos.qvd (qvd)
	where [Estado Pedido - Incluir] = 'Sim';

// Carrega itens
	itens:
	load distinct pedidoIdUnico
	resident pedidos; //faz com que carregue apenas itens de pedidos válidos

	left join (itens)
	LOAD itemId,
		 'Dinda_' & [ID Pedido] as pedidoIdUnico,
	     [Código ERP Variante] as produtoCodigo,
	     Quantidade as itemQuantidade
	from $(qvdDirAdmin)admin_itens.qvd (qvd);

// Leva de "pedidos" para "itens" campos que serão verificados para manter apenas itens de produtos que participaram de campanhas
	left join (itens)
	load pedidoIdUnico,
		 pedidoData
	resident pedidos;

// Enquadra datas dos pedidos nos intervalos de duração das campanhas (IntervalMatch)
	datesInterval:
	IntervalMatch(pedidoData)
	load Distinct
		 campanhaDataInicioDia0,
		 campanhaDataFinal
	resident campanhas;

// Insere ID da campanha na tabela de IntervalMatch
	left join (datesInterval)
	load Distinct
		 campanhaDataInicioDia0,
		 campanhaDataFinal,
		 campanhaId,
		 campanhaSlugProdutos
	resident campanhas;

// Insere ID da campanha na tabela "itens"
	left join (itens)
	load pedidoData,
		 campanhaId,
		 campanhaSlugProdutos
	resident datesInterval;

	drop table datesInterval;

// Marca itens cujos produtos existem em campanhas
	left join (itens)
	load produtoCodigo,
		 campanhaSlugProdutos,
		 1 as produtoExisteEmCampanha,
		 produtoPrecoFinal as itemValorUnitario,
		 produtoPrecoTabela as itemValorUnitarioTabela
	resident produtos;

// Mantém apenas itens que se encaixam em todas as condições verificadas acima
	itensNew:
	NoConcatenate
	load *,
		 itemValorUnitario * itemQuantidade as itemValorTotal
	resident itens
	where not isnull(campanhaId) and produtoExisteEmCampanha = 1;

	drop table itens;
	rename table itensNew to itens;

	drop fields produtoExisteEmCampanha from itens;

// Mantém apenas pedidos cujos itens fizeram parte das campanhas
	pedidosNew:
	load distinct pedidoIdUnico resident itens;

	left join (pedidosNew)
	load * resident pedidos;

	drop table pedidos;
	rename table pedidosNew to pedidos;

// Cálculo do dia de campanha em que cada item de campanha foi comprado - mesmo pedido pode ter itens de campanhas diferentes e portanto diasDeCampanha diferentes
	dias:
	load Distinct
		 campanhaId,
		 campanhaDataInicioDia0
	resident campanhas;

	left join (dias)
	load distinct
		campanhaId,
		pedidoData
	resident itens;

	left join (itens)
	load campanhaId,
		 pedidoData,
		 pedidoData - campanhaDataInicioDia0 as pedidoDiaCampanha
	resident dias;

	drop table dias;

	drop field pedidoData from itens;


///$tab clientes
// Clientes
	clientes:
	LOAD clienteIdUnico,
		 if(clienteSexo = 'm', 'Homem', if(clienteSexo = 'f', 'Mulher')) as clienteSexo,
		 trim(upper(clienteEstado)) as clienteEstado_temp
	FROM $(qvdDirAdmin)clientes.qvd (qvd)
	where exists(clienteIdUnico);

// Estados
	estados:
	LOAD trim(Estado) as estadoNome,
	     trim(UF) as clienteEstado,
	     trim(Região) as estadoRegião
	FROM
	[$(tabelasExternasDir)Campanhas - Tabelas Auxiliares.xlsx]
	(ooxml, embedded labels, table is TabelaUF);

// Manter em "clientes" apenas estados que existem na tabela "estados"
	left join (clientes)
	load clienteEstado as clienteEstado_temp,
		 clienteEstado as clienteEstado
	resident estados;

	drop field clienteEstado_temp;

///$tab storing
store campanhas into $(qvdDir)campanhas.txt (txt);
store campanhas into $(qvdDir)campanhas.qvd (qvd);
store produtos into $(qvdDir)produtos.qvd (qvd);
store pedidos into $(qvdDir)pedidos.qvd (qvd);
store itens into $(qvdDir)itens.qvd (qvd);
store clientes into $(qvdDir)clientes.qvd (qvd);
store estados into $(qvdDir)estados.qvd (qvd);

drop tables campanhas,
			produtos,
			clientes,
			pedidos,
			estados,
			itens;
