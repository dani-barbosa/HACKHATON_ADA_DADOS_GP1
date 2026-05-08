# Arquitetura da Solução — BNDES Risk Intelligence

## Visão Geral

Plataforma de Risk Intelligence para análise de risco em operações de financiamento do BNDES.
Integra dados reais de crédito público brasileiro com indicadores macroeconômicos do Banco Central,
modelos de Machine Learning **com auditoria de leakage** e explicabilidade via SHAP + LLM.

## Fluxo de Dados

```
[BNDES CSV]  →  [Limpeza / Pandas]  →  [SQLite]
                                             ↓
[BCB Olinda]  →  [API requests]  →  [Join por data (mensal)]
[IBGE SIDRA]  →  [API requests]  →  [PIB + Pop por UF]
[Olist (opcional)] → [Kaggle CSVs] → [Anomalia PF]
                                             ↓
                                    [Feature Engineering]
                                  (32 features, sem leakage)
                                             ↓
        ┌────────────────────────────────────┼─────────────────────────────────┐
        │                                    │                                 │
[LogReg + RF + XGBoost + LightGBM]   [Isolation Forest]            [predict_new()]
   4 modelos comparados em CV         (anomalias BNDES)            função produção
   Tuning XGBoost via Random Search                                          │
   Calibração isotonic                                                       │
        │                                                                    │
        ↓                                                                    │
[Lift / Gain Chart] [Fairness por UF] [Threshold de Negócio]                │
        │                                                                    │
        └─────────────────┬──────────────────────────────────────────────────┘
                          ↓
                  [SHAP TreeExplainer]
                  (top 5 features/contrato + waterfall)
                          ↓
         [Ollama (local) → Groq (fallback) → SHAP-only]
              Comitê de Risco Inteligente — 4 Agentes:
         🔬 Analista Quantitativo  (risco técnico, SHAP)
         ⚖️  Assessor Jurídico     (LGPD · Lei 13.303 · BCB 4.658)
         🛡️  Defensor do Cliente   (contraditório, PNDR)
         🏛️  Presidente do Comitê  (decisão vinculante)
              → Deliberação em 4 rodadas, decisão fundamentada em lei
                          ↓
              [SQLite: tabelas predictions + committee_decisions]
              [Parquet: data/enriched/]
              [Joblib: data/models/bndes_risk_model.pkl]
```

## Componentes

### 1. Dados de Entrada

| Fonte | Tipo | Registros | Uso |
|---|---|---|---|
| BNDES CSV (GitHub) | Crédito PJ | 23.419 contratos 2002–2026 | Base principal |
| BCB SGS (API) | Macroeconômico | Séries mensais desde 2002 | Features macro (Selic, IPCA, desemprego, USD/BRL) |
| IBGE SIDRA (API) | Socioeconômico | 27 UFs | PIB per capita + população por UF |
| Olist (Kaggle, opcional) | Pagamentos PF | ~100k pedidos | Anomalia complementar PF |

### 2. Variável Target (Proxy de Stress)

- **target = 1** (stress): contratos com situação `-` OU `LIQUIDADO` com `taxa_desembolso < 50%`
- **target = 0** (saudável): contratos `LIQUIDADO` com `taxa_desembolso ≥ 70%`
- **sem label**: contratos `ATIVO` (censored) e zona cinza (50-70% taxa) → conjunto de predição
- **Validação cruzada**: target conservador alternativo (apenas situação `-`) confirma coerência

### 3. Feature Engineering — SEM Data Leakage 🚨

**Auditoria realizada:** A primeira versão incluía `valor_desembolsado_reais` nas features.
Como o target é definido a partir de `taxa_desembolso = desembolsado / contratado`,
isso causava leakage: AUC saltava para 1.0000 (impossível em risco real).

**Features removidas por leak:** `valor_desembolsado_reais`, `log_valor_desembolsado`, `diferenca_valor`

**Features finais (32):**
- **Numéricas brutas (4):** valor_contratado, prazo_carencia, prazo_amortizacao, idade_contrato
- **Macro BCB (5):** selic_meta_pct, ipca_acum_12m_pct, taxa_desemprego_pct, juro_real_pct, delta_selic_6m
- **Câmbio USD/BRL (3):** usd_brl_medio, usd_volatilidade_6m, usd_trend_3m
- **IBGE socioeconômico (2):** pib_per_capita_uf, populacao_uf
- **Derivadas (9):** log(valor), razão carência/amortização, valor/mês, sazonalidade (sin/cos mês), juro_ponderado, contrato_recente
- **Categóricas (9, label encoded):** UF, setor, porte, modalidade, garantia, inovação, natureza, instrumento, forma de apoio

### 4. Modelos — Pipeline Robusto

#### 4.1 Cross-Validation Temporal (TimeSeriesSplit, 5 folds)

| Modelo | AUC-ROC (CV) | Status |
|---|---|---|
| Logistic Regression | 0.58 ± 0.06 | Baseline |
| Random Forest | 0.65 ± 0.06 | Baseline robusto |
| **XGBoost (tunado)** | **0.66–0.67 ± 0.06** | **🏆 Champion** |
| LightGBM | 0.64 ± 0.06 | Baseline rápido |

> Métricas honestas, **sem leakage**, alinhadas com benchmarks acadêmicos de credit scoring (ex: Lending Club AUC 0.65–0.72, Home Credit AUC 0.70–0.78).

#### 4.2 Hyperparameter Tuning
- **RandomizedSearchCV** no XGBoost com 30 iterações sobre 9 hiperparâmetros
- Cross-validation interna de 3 folds (TimeSeriesSplit)
- Espaço: `n_estimators`, `max_depth`, `learning_rate`, `subsample`, `colsample_bytree`, `min_child_weight`, `gamma`, `reg_alpha`, `reg_lambda`

#### 4.3 Calibração Isotonic
- `CalibratedClassifierCV(method="isotonic")` retreinado em treino+val
- Brier Score reduzido em ~20% (ex: 0.36 → 0.28)
- "Score = 0.7" agora significa ~70% de probabilidade real de stress

#### 4.4 Threshold de Negócio
- Otimização baseada em custo: FN custa 10× FP (premissa de risco de crédito)
- Threshold ótimo de F1 vs. threshold ótimo de custo total
- Matriz de confusão final apresentada com threshold de negócio

### 5. Métricas de Negócio (Linguagem da Banca)

- **Lift@10%**: top decile do score captura ~1.3× mais stress que aleatório
- **Capture@10%**: ~12-30% de TODO o stress nos top 10% do score
- **Volume R$ capturado**: % do volume em risco priorizado
- **ROI estimado**: economia esperada se priorizar revisão pelo score

### 6. Análise de Fairness (Apelo Artemisia)

- AUC segmentado por: **UF, porte, setor BNDES**
- Gap entre UFs reportado e diagnosticado
- Heatmap mostra performance consistente entre regiões (modelo justo)
- Análise de erros: top 5 falsos positivos + top 5 falsos negativos típicos

### 7. Persistência e Produção

```
data/models/bndes_risk_model.pkl   # joblib: modelo + scaler + encoders + metadata
```

Função `predict_new(contract_dict)` pronta para demo ao vivo:
- Recebe dict com features de um novo contrato
- Retorna `{score, classe (BAIXO/MÉDIO/ALTO RISCO), top 5 SHAP, recomendação}`

### 8. Anomaly Detection (Isolation Forest)

- Treinado em **toda** a base BNDES (rotulados + ATIVO), sem features de leak
- Identifica ~2% de contratos atípicos
- Stress rate entre anomalias geralmente 2-3× maior que normais (validação indireta)

### 9. Comitê de Risco Inteligente — Multi-Agent AI

- **Provedor:** Ollama (local, gratuito, sem limites) → Groq (fallback) → SHAP-only
- **Modelo padrão:** `qwen2.5:7b-instruct` (detectado automaticamente)
- **Padrão anti-alucinação:** SHAP injetado literalmente no prompt, LLM nunca infere valores de risco
- **4 Agentes especializados com deliberação em 4 rodadas:**
  - 🔬 **Analista Quantitativo** — analisa score, fatores SHAP, Isolation Forest; cita Res. CMN 4.966/2021
  - ⚖️ **Assessor Jurídico-Regulatório** — compliance bilateral (BNDES + cliente); cita LGPD Art. 20, Lei 13.303/2016, Res. BCB 4.658/2018
  - 🛡️ **Defensor do Cliente** — contraditório do empresário; cita PNDR, impacto regional
  - 🏛️ **Presidente do Comitê** — decisão vinculante (APROVAR / CONDICIONAR / MONITORAR / SUSPENDER / RECUSAR)
- **Persistência:** resultados salvos na tabela `committee_decisions` (SQLite)
- **Temperature:** `0.3` — respostas consistentes e auditáveis

### 10. Armazenamento

```
data/
├── raw/bndes_op.csv                # dados brutos BNDES
├── processed/bndes_clean.parquet   # dados limpos + target
├── enriched/
│   ├── bndes_full.parquet          # 32 features ML
│   ├── predictions.parquet         # scores + SHAP
│   └── olist_anomaly.parquet       # anomalias Olist (PF, opcional)
├── models/bndes_risk_model.pkl     # modelo serializado (joblib)
└── bndes_risk.db                   # SQLite — 4 tabelas:
                                    #   contratos, macro_bcb,
                                    #   predictions, committee_decisions
```

## ⚠️ Limitações Honestas (Slide de Ética)

1. **Concept drift temporal**: contratos pós-2022 são mais frequentemente stress (taxa sobe de 5% em 2002 para >50% em 2023+). Causa: **viés de seleção** — contratos saudáveis recentes ainda estão `ATIVO` (sem rótulo). Por isso a métrica principal é a CV no treino (≤2019), não o teste.
2. **Amostra de teste pequena (n=82)**: para 2022-2024, métricas de teste são noisy. Reportamos CV como referência principal.
3. **Target proxy**: `taxa_desembolso < 50%` pode capturar tanto stress quanto escolha do tomador. Validação cruzada com target conservador (apenas situação `-`) confirma coerência.
4. **Sem features socioeconômicas municipais**: futura iteração incluiria IBGE SIDRA (renda per capita, IDH).

## Requisitos do Bootcamp — Como Cobrimos

| Requisito | Cobertura |
|---|---|
| Python + Estatística | Seções 2-5 (EDA, stats descritiva, correlações), 15 perguntas de negócio |
| SQL | Seção 6: 7 queries (window fn, CTE, self-join, COALESCE, percentile_rank) |
| ML | Seção 8: 4 modelos + CV temporal + tuning + calibração + Isolation Forest |
| Métricas de Negócio | Lift / Gain Chart + threshold cost-sensitive |
| Fairness/ESG | AUC segmentado por UF/porte/setor (apelo Artemisia) |
| Dashboard | Visualizações matplotlib/seaborn no notebook (storytelling completo) |
| Agente IA | Seção 10: Comitê de Risco — 4 agentes (Ollama/Groq), deliberação em 4 rodadas, SHAP grounded, decisão fundamentada em lei |
| Produção | `predict_new()` + `joblib.dump` (modelo serializado pronto) |

## Diferenciais Competitivos

1. **Dados reais BNDES 2002–2026** — narrativa direta para banca CAIXA/Artemisia
2. **Auditoria de leakage explícita** — encontramos e corrigimos um bug de AUC=1.0 → 0.66
3. **4 modelos comparados em CV temporal** — não 1 modelo cego
4. **Calibração isotonic** — probabilidades interpretáveis (Brier reduzido em 20%)
5. **Lift / Gain Charts** — métricas de negócio (R$ priorizados), não só acadêmicas
6. **Fairness analysis por UF/porte/setor** — apelo ESG/Artemisia
7. **predict_new() para demo ao vivo** — modelo serializado, pronto para piloto
8. **SHAP por contrato** — explicabilidade auditável (LGPD, Resolução BCB 4.658)
9. **Comitê Multi-Agente com fundamento jurídico** — 4 agentes, 4 rodadas de deliberação, decisão vinculante rastreável (Ollama/Groq, 100% gratuito)
10. **Enriquecimento tri-fonte** — BCB (macro) + IBGE SIDRA (socioeconômico por UF) + USD/BRL (risco cambial)
11. **Lente PF + PJ opcional** — Olist (pagamentos PF) + BNDES (crédito corporativo)
