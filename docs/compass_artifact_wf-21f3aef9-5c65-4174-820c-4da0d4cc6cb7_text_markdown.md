# Bases de dados para hackathon Elas+ Tech: guia completo de Risk Intelligence

**O combo vencedor para o Tema 3 do hackathon Ada/Caixa/Artemisia é o trio Olist + SCR.Data (BCB) + API Olinda BCB, costurado por um agente de IA que traduz SHAP em português claro.** Essa combinação cobre as duas abordagens (anomalia em transações e score de inadimplência), preenche todos os módulos exigidos (Python, SQL, Power BI, ML), abre espaço para um agente de explicabilidade conversacional com forte apelo social — exatamente o que uma banca formada por Caixa e Artemisia espera ver — e permite enriquecimento via PIX por município, ViaCEP e indicadores macroeconômicos. As próximas seções entregam o detalhamento completo das 12 bases brasileiras avaliadas, das 5 internacionais de backup, das 8 fontes de enriquecimento, perguntas direcionadoras de negócio para cada uma, três desenhos de agente de IA com avaliação de viabilidade em quatro dias, e a justificativa final da combinação recomendada.

---

## 1) Bases brasileiras principais — top 12

A pesquisa confirmou, em maio de 2026, que as bases abaixo estão **ativas e atualizadas**. Nubank Pricing Challenge **não é dataset oficial público** — só existem cópias informais em GitHub pessoais, e por isso foi excluída. Auxílio Brasil foi descontinuado em 2023 e substituído pelo Bolsa Família. FGTS microdados não são públicos.

### 1.1 SCR.Data (Banco Central) — o "ouro" do crédito brasileiro
**Link:** https://dadosabertos.bcb.gov.br/dataset/scr_data
**Tipo:** crédito agregado (carteira ativa, inadimplência, ativo problemático). **Volume:** dezenas de milhões de linhas; CSVs mensais de 50–300 MB; histórico desde 2012. **Formato:** CSV + API OData/Olinda. **Frequência:** mensal, defasagem ~30 dias. **Serve para:** **score de risco** (granular por modalidade, UF, CNAE, porte/renda) e **anomalias** em séries temporais. **Limitações:** dados agregados sem CPF/CNPJ; exclui operações abaixo de R$ 200 (subestima fintechs/microcrédito). **Dificuldade:** média.

**Perguntas direcionadoras:** (i) Como evolui a inadimplência PF vs PJ por modalidade nos últimos 24 meses, por UF? *(Power BI)*; (ii) Existe correlação entre porte/renda do tomador e migração para "ativo problemático"? *(EDA)*; (iii) É possível prever inadimplência t+3 por modalidade-UF-CNAE usando lags da carteira ativa, Selic e desemprego como features? *(ML)*.

### 1.2 API Olinda BCB — Selic, IPCA, PIX, expectativas Focus
**Link base:** https://dadosabertos.bcb.gov.br/ ; PIX: https://olinda.bcb.gov.br/olinda/servico/Pix_DadosAbertos/versao/v1/odata/ ; Taxas de juros: https://olinda.bcb.gov.br/olinda/servico/taxaJuros/versao/v2/odata/
**Tipo:** macroeconômico + transacional agregado. **Volume:** centenas de séries; PIX por município com milhões de linhas/mês. **Formato:** API REST OData (JSON/CSV/XML), sem autenticação. **Frequência:** diária a mensal. **Serve para:** **ambos** — features macro para o score e séries para detectar anomalias geográficas em PIX. **Limitação:** desde março/2025 há limite de séries diárias por chamada — paginar. **Dificuldade:** fácil.

**Perguntas:** (i) Dashboard de cenário macro com Selic, IPCA, taxa média do crédito rotativo e inadimplência *(Power BI)*; (ii) Quais municípios apresentam volume de PIX recebido (PJ) atípico vs sua tendência histórica — possíveis fraudes? *(anomalia)*; (iii) Variáveis exógenas (Selic, expectativa Focus de IPCA t+12) melhoram o modelo de default em quanto de AUC? *(ML)*.

### 1.3 Olist Brazilian E-Commerce (Kaggle) — clássico de comportamento de pagamento
**Link:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
**Tipo:** transacional + comportamental. **Volume:** ~100 mil pedidos (2016–2018), 9 tabelas relacionais, ~140 MB. **Formato:** 9 CSVs (pedidos, pagamentos, itens, clientes, geolocalização, sellers, reviews, produtos). **Frequência:** snapshot histórico, **não atualizado**. **Serve para:** **ambos** — anomalias em pagamentos/frete (Isolation Forest) e proxy de score (cancelamentos como label). **Limitações:** dados anonimizados; cobertura pré-pandemia/PIX; sem label real de inadimplência. **Dificuldade:** fácil — dataset super-documentado, ideal para SQL com joins.

**Perguntas:** (i) Como se distribui o valor de parcelamento por estado e tipo de pagamento? *(Power BI)*; (ii) Quais pedidos têm valor de frete/produto outliers via Isolation Forest? *(anomalia)*; (iii) É possível prever cancelamento de pedido a partir de valor, parcelamento, distância seller-cliente e categoria? *(ML)*.

### 1.4 Receita Federal — CNPJ Dados Abertos
**Link:** https://arquivos.receitafederal.gov.br/dados/cnpj/ (mirror amigável: https://dados-abertos-rf-cnpj.casadosdados.com.br/)
**Tipo:** cadastral PJ — empresas, estabelecimentos, sócios, Simples Nacional. **Volume:** **~85 GB descompactado**, 60M empresas, 25M sócios. **Formato:** CSV ZIP, encoding latin1. **Frequência:** mensal. **Serve para:** **score PJ** (idade, capital, CNAE, situação) e **anomalias** em rede de sócios. **Limitação:** volume exige Postgres/DuckDB — para hackathon, **filtre por UF/CNAE** logo no ETL. **Dificuldade:** difícil.

**Perguntas:** (i) Mapa de empresas ativas vs baixadas por município, idade média e capital social *(Power BI)*; (ii) Como construir um score cadastral combinando idade + situação + filiais + Simples? *(ML feature)*; (iii) Quais sócios figuram em mais de 10 empresas distintas — possível "laranja"? *(anomalia em grafo)*.

### 1.5 Portal da Transparência — despesas públicas + Bolsa Família
**Link:** https://portaldatransparencia.gov.br/download-de-dados (CSV) e https://api.portaldatransparencia.gov.br/swagger-ui/index.html (API com cadastro gratuito).
**Tipo:** transacional + benefícios sociais. **Volume:** GBs por ano; Bolsa Família atende ~21 milhões de famílias/mês. **Formato:** CSV mensal + API REST. **Frequência:** mensal/diária. **Serve para:** **detecção de anomalia** em fornecedores e empenhos; **fraude em benefícios** ao cruzar Bolsa Família com CNPJ ativo ou CEIS. **Limitação:** dados nominativos — usar com ética. **Dificuldade:** média.

**Perguntas:** (i) Quais fornecedores tiveram valor médio mensal subindo >5σ no último trimestre? *(anomalia)*; (ii) Heatmap UF × função de governo do gasto público em 2025 *(Power BI)*; (iii) Existem CNPJs ativos recebendo Bolsa Família simultaneamente (cruzamento com Receita)? *(fraude)*.

### 1.6 CVM — FIDC, fundos, debêntures
**Link:** https://dados.cvm.gov.br/ ; FIDC: https://dados.cvm.gov.br/dataset/fidc-doc-inf_mensal
**Tipo:** crédito estruturado — **FIDCs trazem inadimplência real** da carteira de recebíveis (PDD, atrasos por faixa). **Volume:** milhões de linhas/ano no Informe Diário; FIDC mensal desde 2013. **Formato:** CSV ZIP + API CKAN. **Frequência:** semanal/mensal. **Serve para:** **score de risco com label real**, raridade no Brasil aberto. **Limitação:** dados agregados por fundo, sem devedor individual. **Dificuldade:** média-difícil.

**Perguntas:** (i) Como evolui PDD/PL nos FIDCs de consignado vs cartão vs PJ? *(Power BI)*; (ii) É possível prever inadimplência t+1 do FIDC com composição setorial e indicadores macro? *(ML)*; (iii) Quais fundos têm maior taxa de perda esperada e por quê? *(EDA)*.

### 1.7 Cadastro Único / Bolsa Família (CECAD 2.0)
**Link:** https://cecad.cidadania.gov.br/ ; painel município: https://aplicacoes.cidadania.gov.br/ri/pbfcad/
**Tipo:** socioeconômico/comportamental. **Volume:** 42,2 milhões de famílias (atualização 03/2026), ~80M pessoas. **Formato:** consultas TabCAD agregadas + microdados sob solicitação ao MDS. **Frequência:** mensal. **Serve para:** **score territorial** e features socioeconômicas para enriquecer bases de crédito. **Limitação:** microdados identificados exigem convênio LGPD; viés de cobertura (baixa renda). **Dificuldade:** média.

**Perguntas:** (i) Como se concentram famílias em pobreza por UF/município vs renda média? *(Power BI)*; (ii) Variáveis municipais (% pobreza, IDH, escolaridade) como features melhoram o score PF? *(ML)*; (iii) Quais municípios apresentam saltos atípicos de inscrições no programa? *(anomalia)*.

### 1.8 BNDES — operações de crédito
**Link:** https://dadosabertos.bndes.gov.br/ (API CKAN: https://dadosabertos.bndes.gov.br/api/3/action/)
**Tipo:** crédito PJ (financiamento, debêntures, microcrédito). **Volume:** centenas de milhares de operações desde 2002. **Formato:** CSV (encoding `windows-1252` desde fev/2025) + API. **Frequência:** mensal/trimestral. **Serve para:** **score PJ corporativo e microcrédito**. **Limitação:** sem label de default explícito. **Dificuldade:** fácil.

**Perguntas:** (i) Qual a distribuição de desembolsos por porte, CNAE e UF (2020–2025)? *(Power BI)*; (ii) Como clusterizar tomadores cruzando BNDES com Receita CNPJ? *(ML não-supervisionado)*; (iii) Volume de microcrédito por município é variável explicativa para inadimplência local do SCR? *(estatística)*.

### 1.9 IBGE — POF (Pesquisa de Orçamentos Familiares)
**Link 2017–2018 (microdados ativos):** https://www.ibge.gov.br/estatisticas/sociais/saude/24786-pesquisa-de-orcamentos-familiares-2.html ; via Base dos Dados (BigQuery): https://basedosdados.org/dataset/a1b6d2b6-4aa6-47e7-a517-8a21b28b7254
**Status:** A coleta da POF 2024–2025 encerrou em 30/10/2025; **microdados só serão divulgados ao longo de 2026** — em maio/2026 ainda não há disponibilidade pública. Use a POF 2017–2018. **Inclui módulo inédito sobre apostas online (Bets)** na nova edição. **Tipo:** comportamental/orçamentário. **Volume:** ~100k domicílios. **Formato:** TXT largura fixa (ou parquet via Base dos Dados). **Serve para:** **detecção de anomalia em padrões de gasto** — gold standard. **Dificuldade:** difícil; recomendado via SQL no BigQuery da Base dos Dados.

**Perguntas:** (i) Qual a composição percentual do orçamento por decil de renda — baseline de gasto saudável? *(EDA)*; (ii) Quais famílias têm % de gasto com cartão/empréstimo >3σ acima da média do decil? *(anomalia)*; (iii) Como criar vetores de "perfil de consumo típico" por estrato para enriquecer modelos de risco PF? *(feature engineering)*.

### 1.10 Tesouro Transparente / Tesouro Direto
**Link:** https://www.tesourotransparente.gov.br/ckan/ ; taxas históricas: https://www.tesourotransparente.gov.br/ckan/dataset/taxas-dos-titulos-ofertados-pelo-tesouro-direto
**Tipo:** comportamental (perfil investidor) + macroeconômico. **Volume:** taxas diárias desde 2002; ~10 milhões de investidores anonimizados. **Formato:** CSV via CKAN + API. **Frequência:** diária/mensal. **Serve para:** **anomalias** em resgates antecipados (sinal de stress) e features macro. **Dificuldade:** fácil.

**Perguntas:** (i) Como a curva pré e IPCA+ se relaciona com inadimplência SCR? *(Power BI storytelling)*; (ii) Qual o perfil etário de investidores ativos vs cadastrados? *(EDA)*; (iii) Quais dias têm resgate antecipado fora da banda histórica? *(anomalia)*.

### 1.11 Caixa Econômica — bonus por parceria
**Link de dados abertos formal:** https://www.caixa.gov.br/acesso-a-informacao/Paginas/dados-abertos.aspx — a Caixa **declara não estar obrigada** ao Decreto 8.777/2016 (Política Nacional de Dados Abertos). **O que existe gratuito:** loterias (https://loterias.caixa.gov.br/ + https://basedosdados.org/dataset/6153e6ff-ecca-4bec-9165-64a7619262e0), Bolsa Família (via Portal da Transparência) e estatísticas FGTS apenas agregadas. **Volume loterias:** todos os concursos desde 1996. **Serve para:** narrativa simbólica em parceria com a Caixa, especialmente cruzando crescimento de loterias e Bets com inadimplência. **Dificuldade:** fácil.

**Perguntas:** (i) Como a arrecadação de loterias evolui vs Selic e desemprego — comportamento pró-cíclico? *(storytelling)*; (ii) Quais concursos apresentam número atípico de apostas (jackpots)? *(anomalia)*; (iii) Há correlação entre crescimento de Bets/loterias e indicadores Serasa de inadimplência? *(análise social)*.

### 1.12 Serasa Experian — Mapa da Inadimplência e Mapa Score
**Link Mapa Inadimplência:** https://www.serasa.com.br/limpa-nome-online/blog/mapa-da-inadimplencia-e-renogociacao-de-dividas-no-brasil/ ; **Mapa Score:** https://www.serasa.com.br/score/mapa-do-score/ ; **Indicadores Econômicos:** https://www.serasaexperian.com.br/conteudos/indicadores-economicos/
**Status:** **NÃO existem microdados públicos da Serasa** — apenas séries agregadas mensais em PDF/HTML (idade, gênero, UF, faixa de renda, tipo de dívida). **Serve para:** **benchmarking e validação** do modelo, e storytelling em Power BI. **Dificuldade:** fácil para visual; difícil para automação (sem API).

**Perguntas:** (i) Como evolui o número de inadimplentes Brasil 2016–2026 por faixa etária? *(Power BI narrativo)*; (ii) A predição do nosso modelo (SCR) bate com a curva oficial Serasa? *(validação)*; (iii) Qual a média de Serasa Score por região e como se relaciona com inadimplência local? *(EDA)*.

---

## 2) Bases internacionais complementares — top 5

### 2.1 Credit Card Fraud Detection (ULB/Kaggle)
**Link:** https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud (mirror sem login: https://zenodo.org/records/7395559). **Tamanho:** 284.807 linhas × 31 colunas. **Target:** `Class` com **0,172% de fraudes** (severamente desbalanceada). **Features:** `Time`, `Amount`, `V1–V28` (PCA). **Serve para:** **anomalia** (autoencoder, Isolation Forest, LOF) e classificação supervisionada. **Pontos fortes:** benchmark de fato. **Pontos fracos:** features anônimas — explicabilidade limitada para Power BI. **Dificuldade:** fácil-média.

**Perguntas:** (i) Qual o trade-off ótimo Recall × Precision considerando custo de fraude vs custo de revisão manual?; (ii) Em que faixa de `Amount` e janela horária as fraudes se concentram?; (iii) Um autoencoder unsupervised antecipa fraudes não vistas com Recall ≥ 80% e FPR < 5%?

### 2.2 Give Me Some Credit (Kaggle)
**Link:** https://www.kaggle.com/c/GiveMeSomeCredit (mirror: https://www.kaggle.com/datasets/brycecf/give-me-some-credit-dataset). **Tamanho:** 150 mil linhas, 10 features interpretáveis (`RevolvingUtilization`, `age`, atrasos 30/60/90, `DebtRatio`, `MonthlyIncome`...). **Target:** `SeriousDlqin2yrs` com 6,68% positivos. **Serve para:** **score de inadimplência clássico** com Logistic Regression + WOE/IV, scorecard estilo FICO. **Pontos fortes:** features interpretáveis (excelente Power BI). **Dificuldade:** fácil.

**Perguntas:** (i) Qual a faixa de score ótima para corte de aprovação maximizando lucro esperado?; (ii) Como `RevolvingUtilization` e atrasos prévios interagem para prever default?; (iii) O modelo é estável entre faixas etárias — há viés discriminatório?

### 2.3 Lending Club Loan Data — atenção ao status
**Status atual:** o dataset original de Wendy Kan **foi removido do Kaggle em 2019**. **Mirror recomendado:** https://www.kaggle.com/datasets/wordsforthewise/lending-club (2007–2018). Versão Zenodo limpa: https://zenodo.org/records/11295916. **Tamanho:** ~2,26M loans accepted + ~27M rejected, ~1,6 GB. **Features:** ~145 colunas (FICO, grade, purpose, dti, addr_state, zip_code). **Serve para:** **score com vintage analysis** e **SQL/joins por geografia**. **Atenção:** `int_rate` e `grade` causam **target leakage** — descartar para granting model. **Dificuldade:** média-difícil.

**Perguntas:** (i) Como evolui a probabilidade de default por safra e qual o impacto da pandemia 2020?; (ii) Quais variáveis disponíveis no momento da aplicação (sem leakage) melhor predizem default?; (iii) A precificação por `grade` é eficiente quando ajustada por risco?

### 2.4 Home Credit Default Risk
**Link:** https://www.kaggle.com/c/home-credit-default-risk. **Tamanho:** ~2,7 GB em **7 tabelas relacionais** (application, bureau, bureau_balance, previous_application, POS_CASH_balance, credit_card_balance, installments_payments). **Tabela principal:** 307.511 linhas × 122 colunas. **Target:** 8% positivos. **Serve para:** demonstrar SQL com window functions, agregações e joins relacionais — **a melhor base para mostrar maestria em SQL** entre as listadas. **Dificuldade:** difícil.

**Perguntas:** (i) O histórico de bureau externo agrega quanto de AUC sobre features de aplicação atual?; (ii) Como `EXT_SOURCE_1/2/3` se comparam ao modelo construído do zero?; (iii) Para clientes "thin file", quais sinais alternativos predizem default melhor?

### 2.5 PaySim — mobile money sintético
**Link:** https://www.kaggle.com/datasets/ealaxi/paysim1. **Tamanho:** 6,36 milhões de transações × 11 colunas, ~470 MB. **Target:** `isFraud` com 0,129% positivos; fraudes só em `TRANSFER` e `CASH_OUT`. **Features interpretáveis:** `type`, `amount`, saldos antes/depois — permite tanto regras determinísticas quanto ML. **Diferencial:** suporta **análise em grafo** (cliente→destino). **Dificuldade:** média.

**Perguntas:** (i) Quais combinações `type × amount × hora` formam o "fingerprint" de fraude?; (ii) A regra `oldbalanceOrg − newbalanceOrig ≠ amount` é melhor proxy que ML supervisionado?; (iii) Existe padrão de fraude em cadeia (CASH_OUT logo após TRANSFER) detectável via grafo?

**Wildcards de diferenciação:** *Default of Credit Card Clients* (UCI Taiwan, 30 mil linhas, sem login — ótimo baseline rápido), *IEEE-CIS Fraud Detection* (590 mil × 434 colunas, dataset moderno e-commerce), *BankSim* (594 mil transações com merchant categories — excelente para Power BI com drill-down).

---

## 3) Fontes de enriquecimento — top 8

A junção mais poderosa é encadear **CEP → ViaCEP/BrasilAPI → código IBGE → SIDRA**, e em paralelo **data → BCB SGS** para contexto macro. Esse pipeline cria features densas em poucos minutos.

### 3.1 BCB API SGS (séries temporais macroeconômicas)
**Endpoint:** `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados?formato=json` ; documentação: https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do ; biblioteca recomendada: `python-bcb`. **Códigos úteis:** Selic meta=432, IPCA=433, IGP-M=189, USD venda=1, desocupação=24369. **Junção:** chave `data` (mensal/diária). **Dificuldade:** fácil.

**Features sugeridas:** `selic_no_mes`, `delta_selic_3m`, `ipca_acum_12m`, `volatilidade_cambio_30d`, `gap_juros_real` (Selic − IPCA).

### 3.2 BCB Olinda — Expectativas Focus, PTAX, IFData
**Links:** Expectativas https://olinda.bcb.gov.br/olinda/servico/Expectativas/versao/v1/documentacao ; PTAX https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/documentacao ; IFData https://olinda.bcb.gov.br/olinda/servico/IFDATA/versao/v1/documentacao . **Junção:** `data` ou CNPJ-IF. **Dificuldade:** média (sintaxe OData).

**Features:** `expectativa_ipca_12m`, `surpresa_ipca`, `ptax_spread`, `inadimplencia_carteira_IF` por porte da instituição.

### 3.3 IBGE APIs Servicodados — Localidades, SIDRA, Censo 2022
**Localidades:** https://servicodados.ibge.gov.br/api/v1/localidades/municipios . **SIDRA v3:** https://servicodados.ibge.gov.br/api/v3/agregados/{id}/periodos/{p}/variaveis/{v}?localidades=N6[all] . **Tabelas-chave:** Censo 9514/4709 (população), 200/9605 (renda/domicílios); PNADC trimestral 6468/6397 (desocupação). **Junção:** **código IBGE de 7 dígitos**. **Dificuldade:** média; biblioteca `sidrapy` ajuda.

**Features:** `pop_municipio`, `densidade_demografica`, `renda_per_capita_municipio`, `taxa_desocupacao_UF_trim` (dinâmica), `pct_informalidade_UF`.

### 3.4 ViaCEP + BrasilAPI — gateway de CEP, CNPJ, feriados
**ViaCEP:** https://viacep.com.br/ws/{CEP}/json/ . **BrasilAPI CEP v2 (com lat/lon):** https://brasilapi.com.br/api/cep/v2/{cep} . **CNPJ:** https://brasilapi.com.br/api/cnpj/v1/{cnpj} . **Feriados:** https://brasilapi.com.br/api/feriados/v1/{ano} . **Taxas (Selic, CDI, IPCA atual):** https://brasilapi.com.br/api/taxas/v1 . **Dificuldade:** fácil.

**Features:** `uf`, `cod_ibge_municipio` (chave para SIDRA), `cnpj_idade_anos`, `cnpj_porte`, `is_feriado`, `is_vespera_feriado`, `cep_valido_flag` (anomalia: muitos CEPs inválidos = sinal de fraude).

### 3.5 IBGE Malhas Territoriais
**API v3:** https://servicodados.ibge.gov.br/api/v3/malhas/municipios/{id}?formato=application/vnd.geo+json . **Download shapefile:** https://www.ibge.gov.br/geociencias/organizacao-do-territorio/malhas-territoriais/15774-malhas.html . **Junção:** código IBGE ou geometria. **Dificuldade:** média.

**Features:** `area_municipio_km2`, `densidade_pop`, `distancia_centroid_municipio_capital_uf` (proxy de remoteness), `cluster_geo_kNN` por coordenadas.

### 3.6 INMET BDMEP — meteorologia
**Download anual sem cadastro:** https://portal.inmet.gov.br/dadoshistoricos . **Portal interativo (cadastro grátis):** https://bdmep.inmet.gov.br/ . **Junção:** estação mais próxima do CEP via haversine. **Dificuldade:** difícil (parsing CSV irregular + geomatch).

**Features:** `precipitacao_acum_30d_municipio`, `evento_extremo_chuva_flag`, `dias_sem_chuva_consecutivos` — relevante para crédito rural e regional.

### 3.7 Novo CAGED / RAIS — emprego formal
**Página oficial:** https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/microdados-rais-e-caged ; FTP: ftp://ftp.mtps.gov.br/pdet/microdados/ ; versão tratada parquet: https://basedosdados.org/dataset/562b56a3-0b01-4735-a049-eeac5681f056 . **Junção:** código IBGE + CNAE + competência (AAAAMM). **Dificuldade:** média.

**Features:** `saldo_emprego_municipio_ult_3m`, `salario_medio_admissao_municipio`, `taxa_rotatividade_setor_uf` — anomalia em queda abrupta = stress local.

### 3.8 AwesomeAPI — câmbio em tempo real
**Atual:** https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,BTC-BRL ; **histórico:** https://economia.awesomeapi.com.br/json/daily/USD-BRL/30 . **Sem cadastro, sem rate limit oficial.** **Dificuldade:** fácil.

**Features:** `usd_brl_no_dia`, `volatilidade_usd_30d`, `pct_change_usd_7d`, `gap_ptax_x_mercado` (cruzando com BCB PTAX = anomalia de spread).

**Pipeline de enriquecimento recomendado:** CEP → ViaCEP → `cod_ibge` → SIDRA (Censo + PNADC) → CAGED/RAIS por município/competência → BCB SGS por data → BrasilAPI feriados → INMET (opcional para regional/rural) → BrasilAPI CNPJ se PJ. Tempo de implementação: ~6h para Daniela na Data Engineering.

---

## 4) Agente de IA — três desenhos avaliados em 4 dias

### Ideia A — Sentinela conversacional para gestor
**O que faz:** chatbot Streamlit onde o gestor pergunta em PT-BR sobre anomalias detectadas, e o agente faz function calling sobre SQLite + tabela de output do Isolation Forest. **Stack:** Groq (Llama 3.3 70B) via SDK OpenAI + LangChain `create_sql_agent` + Streamlit. **Dificuldade:** média (prompt engineering para SQL seguro). **Tempo:** 16–20h. **Risco principal:** alucinação SQL — mitigar com **whitelist de funções** ao invés de text-to-SQL livre. **Wow factor:** demo ao vivo com pergunta livre da banca.

### Ideia B — Copiloto de decisão (recomendações por score)
**O que faz:** para cada cliente, recebe `{score, top features SHAP, perfil}` e gera ação personalizada (renegociar com 15% de desconto, pré-aprovar limite, evitar concessão por 90 dias). **Stack:** Groq + OpenAI SDK puro + Streamlit; CrewAI opcional para dois personagens (analista + consultor). **Dificuldade:** fácil-média. **Tempo:** 12–16h. **Risco:** recomendações genéricas — mitigar com persona + few-shot. **Wow factor:** mostrar 3 personas reais (PJ alto risco, MEI médio, PF baixo) e como a recomendação muda.

### Ideia C — Explicador conversacional baseado em SHAP ⭐
**O que faz:** para cada cliente *flagged* gera justificativa em PT-BR claro, citando os top fatores SHAP com pesos, suportando follow-up contrafactual ("e se a renda voltar ao normal?"). **Stack:** Gemini 2.5 Flash ou Groq + `shap.TreeExplainer` + Streamlit + (opcional) RAG sobre PDFs de política via FAISS + embeddings HF. **Dificuldade:** média. **Tempo:** 18–22h. **Risco:** o LLM pode reescrever o ranking SHAP — mitigar com padrão **LLM-as-Translator** (sempre injetar SHAP no prompt; nunca pedir para inferir sozinho), validado em arXiv 2510.25701/2025. **Wow factor:** **mesmo cliente, três públicos diferentes** (gestor, regulador, cliente final) com toggle de persona — encaixa diretamente em LGPD e Resolução BCB 4.658.

### Ferramentas gratuitas 2025–2026 — ranking prático
| API LLM | Free tier | Uso recomendado |
|---|---|---|
| **Groq** | Sem limite estrito; Llama 3.3 70B; ~500 tok/s | **Principal** — melhor para demo ao vivo |
| **Google Gemini** | 5–15 RPM, 250K TPM, 1M context | Backup para textos longos; cuidar rate limit (reduzido 50–80% em dez/2025) |
| **Hugging Face** | Embeddings grátis | RAG (`all-MiniLM-L6-v2`) |

**Frameworks:** LangChain para SQL agent simples ou puro `openai` SDK apontando para Groq (`https://api.groq.com/openai/v1`). **Evitar:** AutoGen (modo manutenção em 2025), LangGraph (curva de 1–2 semanas), Power BI Copilot (exige capacity F64+ paga). LangFlow/Flowise só como emergência — banca de Ada Tech valoriza código autoral. **Integração com Power BI:** modo batch (agente popula colunas `recomendacao_ia` e `justificativa_ia` no banco; Power BI consome como qualquer coluna; tooltips e cards) + deep link bidirecional Streamlit↔Power BI.

---

## 5) Recomendação final — a combinação vencedora

### O combo
A combinação ideal para vocês é **Olist (base principal) + SCR.Data BCB + API Olinda BCB com PIX por município (enriquecimento), tudo costurado pelo agente "Explicador" da Ideia C**.

### Por que esse combo vence

**Olist como base principal** entrega EDA visualmente rica (mapas por estado, tipo de pagamento, parcelamento), tabelas relacionais que justificam SQL real com joins, target proxy de cancelamento/atraso para o modelo de classificação, e features interpretáveis para o Power BI — coisas que a base de fraude do ULB com `V1–V28` simplesmente não permite contar como história. **A literatura de hackathon brasileiro também é farta**, então a curva de subida é mínima — vocês ganham tempo para o que diferencia.

**SCR.Data + API Olinda BCB como enriquecimento macro** transformam um projeto comum em algo único: vocês passam a ler o Olist **dentro de um cenário macroeconômico real** (Selic, IPCA, expectativa Focus de IPCA t+12, inadimplência regional do SFN). Isso permite afirmar coisas como "o ticket médio de parcelamento sobe sempre que a Selic cai mais de 1pp em 6 meses, e o cancelamento sobe quando o desemprego do PNADC cresce no estado" — **storytelling sofisticado** que poucos times fazem.

**PIX por município (Olinda BCB) é o trunfo de diferenciação:** ninguém usa essa base em hackathons. Cruzando com o CEP do cliente Olist, vocês criam features de "intensidade transacional do município" que melhoram tanto o modelo de score quanto a detecção de anomalia geográfica. A pergunta "este pedido foi feito de uma região com volume PIX/PJ atípico?" é poderosa para fraude.

**Agente Explicador (Ideia C):** combina explicabilidade regulatória (LGPD + Resolução BCB 4.658) com inclusão financeira ("Maria, você foi negada porque sua renda caiu 40% — se voltar ao normal o score sobe X"). Esse duplo apelo — técnico e social — é exatamente o que jurados do Fundo Socioambiental da Caixa e da Artemisia premiam. Encaixe perfeito de talentos: **Daniela** monta o pipeline `Olist → joins → Olinda BCB → CEP/IBGE → SHAP → JSON → LLM → coluna no banco`; **Louise** treina Random Forest/XGBoost + Isolation Forest e extrai SHAP values; **Nathalia** desenha as 3 personas (gestor, regulador, cliente final), constrói o Power BI com tooltips IA e abre o pitch usando o próprio agente como ferramenta narrativa — meta-storytelling.

### Cronograma de 4 dias
**Dia 1:** Daniela monta o ETL Olist no SQLite e começa o pipeline de enriquecimento (ViaCEP → IBGE → BCB SGS); Louise faz EDA e treina baseline de Isolation Forest; Nathalia desenha as 3 personas e o storyboard do Power BI. **Dia 2:** Louise integra SHAP no modelo principal, exporta `shap_values` como JSON; Daniela liga os endpoints da Olinda BCB para PIX por município e cruza com geolocalização Olist; Nathalia inicia o dashboard com mocks. **Dia 3:** Streamlit com chat + waterfall SHAP + 3 personas via toggle; integração agente↔dashboard via deep link; primeiro ensaio de pitch. **Dia 4 manhã:** polish, gravação de vídeo backup, slide de "ética e limitações" (viés Olist 2016–2018, exclusão SCR <R$200, padrão LLM-as-Translator validado por paper recente). **Dia 4 tarde:** apresentação.

### Pitch de 60 segundos
> *"Modelos de crédito hoje são caixas-pretas. Quando a Caixa nega um cartão para a Maria, ela não sabe por quê. Construímos uma plataforma que une transações reais do e-commerce brasileiro, dados macroeconômicos do BCB e PIX por município, treina um modelo de risco com 87% de AUC e — eis a diferença — usa um agente de IA para traduzir a decisão em português claro para três públicos: o gestor da Caixa, o regulador e a própria Maria. Resultado: explicabilidade auditável, redução de risco regulatório, e inclusão financeira em ação. Em quatro dias entregamos pipeline, modelo, dashboard e agente — prontos para piloto."*

---

## Conclusão — o que faz esse projeto se destacar

A escolha não é entre "anomalia ou score" — é em **costurar as duas abordagens com uma camada explicativa** que prove que o time domina os quatro módulos do bootcamp e entende a fronteira atual de IA aplicada a finanças. Olist ancora a narrativa concreta; SCR e PIX trazem rigor macro e diferenciação técnica; o agente Explicador, baseado no padrão LLM-as-Translator validado academicamente, evita as armadilhas óbvias de demos com LLM e entrega um produto auditável. O ponto de inflexão é deliberado: enquanto a maioria dos times mostrará um dashboard bonito de Random Forest, vocês mostrarão **uma plataforma de Risk Intelligence que devolve clareza e agência ao cliente final** — exatamente a tese socioambiental que une Caixa e Artemisia. Bases brasileiras pouco-óbvias (PIX por município, FIDC da CVM como wildcard) viram pontos extras. O risco está controlado: cada decisão técnica tem fallback documentado (Groq↔Gemini, SHAP grounded prompt, modo batch para Power BI). O que falta é executar — boa sorte às três.