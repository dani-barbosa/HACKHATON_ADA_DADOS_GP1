-- ============================================================
-- BNDES Risk Intelligence — Schema SQLite
-- ============================================================

-- Tabela principal: contratos BNDES (base rotulada)
CREATE TABLE IF NOT EXISTS contratos (
    numero_do_contrato      INTEGER PRIMARY KEY,
    cnpj                    TEXT,
    cliente                 TEXT,
    uf                      TEXT,
    municipio               TEXT,
    municipio_codigo        INTEGER,
    data_da_contratacao     TEXT,
    ano_contratacao         INTEGER,
    valor_contratado_reais  REAL,
    valor_desembolsado_reais REAL,
    taxa_desembolso         REAL,
    diferenca_valor         REAL,
    prazo_carencia_meses    INTEGER,
    prazo_amortizacao_meses INTEGER,
    modalidade_de_apoio     TEXT,
    forma_de_apoio          TEXT,
    produto                 TEXT,
    setor_bndes             TEXT,
    subsetor_bndes          TEXT,
    porte_do_cliente        TEXT,
    natureza_do_cliente     TEXT,
    tipo_de_garantia        TEXT,
    situacao_do_contrato    TEXT,
    -- Features macroeconômicas (BCB Olinda)
    selic_meta_pct          REAL,
    ipca_acum_12m_pct       REAL,
    taxa_desemprego_pct     REAL,
    juro_real_pct           REAL,
    delta_selic_6m          REAL,
    -- Flags derivadas
    is_operacao_nacional    INTEGER DEFAULT 0,
    -- Target (proxy de stress)
    target                  REAL    -- 0=saudável, 1=stress, NULL=ativo/zona cinza
);

-- Tabela macro BCB (séries temporais)
CREATE TABLE IF NOT EXISTS macro_bcb (
    data            TEXT,
    ano_mes_str     TEXT,
    selic_meta_pct  REAL,
    ipca_acum_12m_pct REAL,
    taxa_desemprego_pct REAL
);

-- Tabela de predições (output do modelo ML + SHAP + LLM)
CREATE TABLE IF NOT EXISTS predictions (
    numero_do_contrato      INTEGER PRIMARY KEY,
    cnpj                    TEXT,
    cliente                 TEXT,
    uf                      TEXT,
    setor_bndes             TEXT,
    porte_do_cliente        TEXT,
    valor_contratado_reais  REAL,
    default_prob            REAL,       -- Score XGBoost [0,1]
    is_anomalia_bndes       INTEGER,    -- Isolation Forest flag
    top_shap_features       TEXT,       -- JSON array com top 5 features
    top_shap_values         TEXT,       -- JSON array com valores SHAP correspondentes
    target                  REAL,       -- Label real (se disponível)
    -- Explicações geradas pelo agente LLM (Groq)
    justificativa_gestor    TEXT,
    justificativa_regulador TEXT,
    justificativa_empresario TEXT
);

-- Tabela Olist (anomalias em pagamentos PF)
CREATE TABLE IF NOT EXISTS olist_payments (
    order_id                TEXT PRIMARY KEY,
    total_payment           REAL,
    n_installments          INTEGER,
    total_freight           REAL,
    total_price             REAL,
    freight_ratio           REAL,
    is_anomalia_pagamento   INTEGER,    -- Isolation Forest flag
    anomaly_raw_score       REAL
);

-- Índices para performance nas queries
CREATE INDEX IF NOT EXISTS idx_contratos_uf        ON contratos(uf);
CREATE INDEX IF NOT EXISTS idx_contratos_ano       ON contratos(ano_contratacao);
CREATE INDEX IF NOT EXISTS idx_contratos_porte     ON contratos(porte_do_cliente);
CREATE INDEX IF NOT EXISTS idx_contratos_setor     ON contratos(setor_bndes);
CREATE INDEX IF NOT EXISTS idx_contratos_target    ON contratos(target);
CREATE INDEX IF NOT EXISTS idx_contratos_cnpj      ON contratos(cnpj);
CREATE INDEX IF NOT EXISTS idx_predictions_prob    ON predictions(default_prob DESC);
CREATE INDEX IF NOT EXISTS idx_predictions_anomalia ON predictions(is_anomalia_bndes);
