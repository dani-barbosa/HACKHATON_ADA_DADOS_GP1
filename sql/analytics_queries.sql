-- ============================================================
-- BNDES Risk Intelligence — 7 Queries Demonstrativas
-- Arquivo: sql/analytics_queries.sql
-- Banco: data/bndes_risk.db (SQLite)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Q1: Window Function — Ranking de stress por UF e Setor BNDES
-- Demonstra: ROW_NUMBER() OVER (PARTITION BY … ORDER BY …)
-- ────────────────────────────────────────────────────────────
SELECT
    uf,
    setor_bndes,
    COUNT(*)                                              AS n_contratos,
    ROUND(AVG(target) * 100, 2)                          AS taxa_stress_pct,
    ROUND(SUM(valor_contratado_reais) / 1e9, 2)          AS volume_bi,
    ROW_NUMBER() OVER (
        PARTITION BY uf
        ORDER BY AVG(target) DESC
    )                                                     AS rank_stress_na_uf
FROM contratos
WHERE target IS NOT NULL
GROUP BY uf, setor_bndes
HAVING n_contratos >= 10
ORDER BY uf, rank_stress_na_uf;


-- ────────────────────────────────────────────────────────────
-- Q2: Self-join — CNPJs com múltiplos contratos e alta recorrência
-- Demonstra: GROUP BY + HAVING + ordenação por risco
-- ────────────────────────────────────────────────────────────
WITH cnpj_multiplos AS (
    SELECT
        cnpj,
        cliente,
        COUNT(DISTINCT numero_do_contrato)            AS n_contratos,
        COUNT(DISTINCT uf)                            AS n_estados,
        COUNT(DISTINCT setor_bndes)                   AS n_setores,
        ROUND(SUM(valor_contratado_reais) / 1e6, 1)  AS volume_total_mi,
        ROUND(AVG(target), 3)                         AS taxa_stress_media
    FROM contratos
    WHERE target IS NOT NULL
    GROUP BY cnpj, cliente
    HAVING n_contratos >= 3
)
SELECT *
FROM cnpj_multiplos
ORDER BY taxa_stress_media DESC, volume_total_mi DESC
LIMIT 20;


-- ────────────────────────────────────────────────────────────
-- Q3: Agregação temporal — Evolução por porte e ano
-- Demonstra: GROUP BY multi-coluna, agregações, filtros
-- ────────────────────────────────────────────────────────────
SELECT
    ano_contratacao,
    porte_do_cliente,
    COUNT(*)                                              AS n_contratos,
    ROUND(SUM(valor_contratado_reais) / 1e9, 2)          AS volume_bi,
    ROUND(AVG(valor_contratado_reais) / 1e6, 1)          AS ticket_medio_mi,
    ROUND(AVG(target) * 100, 1)                          AS stress_pct,
    ROUND(AVG(taxa_desembolso) * 100, 1)                 AS desembolso_medio_pct
FROM contratos
WHERE target IS NOT NULL
  AND ano_contratacao BETWEEN 2010 AND 2024
  AND porte_do_cliente IN ('MICRO', 'PEQUENA', 'MÉDIA', 'GRANDE')
GROUP BY ano_contratacao, porte_do_cliente
ORDER BY ano_contratacao DESC, porte_do_cliente;


-- ────────────────────────────────────────────────────────────
-- Q4: CTE — Análise de coorte por safra de contratação
-- Demonstra: WITH (CTE) + RANK() OVER + múltiplas métricas
-- ────────────────────────────────────────────────────────────
WITH safra AS (
    SELECT
        ano_contratacao                                   AS coorte,
        COUNT(*)                                          AS n_contratos,
        ROUND(AVG(target) * 100, 2)                      AS stress_pct,
        ROUND(SUM(valor_contratado_reais) / 1e9, 2)      AS volume_bi,
        ROUND(AVG(taxa_desembolso) * 100, 2)             AS desembolso_medio_pct,
        ROUND(AVG(prazo_amortizacao_meses), 1)           AS prazo_medio_meses
    FROM contratos
    WHERE target IS NOT NULL
      AND ano_contratacao BETWEEN 2002 AND 2022
    GROUP BY ano_contratacao
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY stress_pct DESC)        AS rank_mais_stress,
           RANK() OVER (ORDER BY volume_bi DESC)          AS rank_maior_volume
    FROM safra
)
SELECT
    coorte,
    n_contratos,
    stress_pct,
    volume_bi,
    desembolso_medio_pct,
    prazo_medio_meses,
    rank_mais_stress,
    rank_maior_volume
FROM ranked
ORDER BY coorte;


-- ────────────────────────────────────────────────────────────
-- Q5: Join com tabela macro — Selic × Volume por trimestre
-- Demonstra: JOIN entre contratos e macro_bcb, funções de data
-- ────────────────────────────────────────────────────────────
SELECT
    CAST(ano_contratacao AS TEXT) || '-T' ||
        CAST(
            ((CAST(strftime('%m', data_da_contratacao) AS INTEGER) - 1) / 3 + 1)
        AS TEXT)                                          AS trimestre,
    COUNT(*)                                              AS n_contratos,
    ROUND(SUM(valor_contratado_reais) / 1e9, 2)          AS volume_bi,
    ROUND(AVG(selic_meta_pct), 2)                        AS selic_media_pct,
    ROUND(AVG(juro_real_pct), 2)                         AS juro_real_medio,
    ROUND(AVG(ipca_acum_12m_pct), 2)                     AS ipca_medio,
    ROUND(AVG(target) * 100, 2)                          AS stress_pct
FROM contratos
WHERE selic_meta_pct IS NOT NULL
  AND target IS NOT NULL
  AND ano_contratacao BETWEEN 2005 AND 2024
GROUP BY trimestre
ORDER BY trimestre
LIMIT 50;


-- ────────────────────────────────────────────────────────────
-- Q6: Detecção de outliers — Top 1% por modalidade (PERCENT_RANK)
-- Demonstra: window function PERCENT_RANK() para outliers
-- ────────────────────────────────────────────────────────────
WITH percentis AS (
    SELECT
        modalidade_de_apoio,
        valor_contratado_reais,
        numero_do_contrato,
        cliente,
        uf,
        target,
        PERCENT_RANK() OVER (
            PARTITION BY modalidade_de_apoio
            ORDER BY valor_contratado_reais
        )                                                 AS pct_rank
    FROM contratos
    WHERE target IS NOT NULL
)
SELECT
    modalidade_de_apoio,
    numero_do_contrato,
    cliente,
    uf,
    ROUND(valor_contratado_reais / 1e6, 1)               AS valor_mi,
    ROUND(pct_rank * 100, 2)                             AS percentil,
    CASE WHEN target = 1 THEN 'STRESS' ELSE 'SAUDÁVEL' END AS status
FROM percentis
WHERE pct_rank >= 0.99
ORDER BY valor_contratado_reais DESC
LIMIT 25;


-- ────────────────────────────────────────────────────────────
-- Q7: Limpeza com COALESCE e CASE WHEN + join com predictions
-- Demonstra: tratamento de nulos, categorização, JOIN externo
-- ────────────────────────────────────────────────────────────
SELECT
    c.numero_do_contrato,
    c.cliente,
    c.uf,
    COALESCE(c.porte_do_cliente, 'NÃO INFORMADO')        AS porte_limpo,
    COALESCE(c.tipo_de_garantia, 'SEM GARANTIA')         AS garantia_limpa,
    COALESCE(c.selic_meta_pct, 0.0)                      AS selic_ou_zero,
    ROUND(c.valor_contratado_reais / 1e6, 2)             AS valor_mi,
    CASE
        WHEN c.target = 1                                THEN 'STRESS'
        WHEN c.target = 0
             AND c.taxa_desembolso >= 0.95               THEN 'SAUDÁVEL PLENO'
        WHEN c.target = 0                                THEN 'SAUDÁVEL'
        ELSE 'SEM LABEL'
    END                                                  AS classificacao_real,
    CASE
        WHEN c.prazo_amortizacao_meses = 0               THEN 'SEM PRAZO'
        WHEN c.prazo_amortizacao_meses <= 24             THEN 'CURTO (até 2 anos)'
        WHEN c.prazo_amortizacao_meses <= 60             THEN 'MÉDIO (2–5 anos)'
        WHEN c.prazo_amortizacao_meses <= 120            THEN 'LONGO (5–10 anos)'
        ELSE 'MUITO LONGO (>10 anos)'
    END                                                  AS faixa_prazo,
    ROUND(COALESCE(p.default_prob, -1), 3)               AS score_modelo,
    CASE
        WHEN p.default_prob >= 0.7                       THEN 'ALTO RISCO'
        WHEN p.default_prob >= 0.4                       THEN 'MÉDIO RISCO'
        WHEN p.default_prob >= 0                         THEN 'BAIXO RISCO'
        ELSE 'SEM PREDIÇÃO'
    END                                                  AS faixa_risco_ia,
    COALESCE(p.is_anomalia_bndes, 0)                     AS flag_anomalia
FROM contratos c
LEFT JOIN predictions p ON c.numero_do_contrato = p.numero_do_contrato
ORDER BY COALESCE(p.default_prob, 0) DESC
LIMIT 30;
