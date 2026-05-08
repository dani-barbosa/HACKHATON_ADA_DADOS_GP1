# BNDES Risk Intelligence
### Hackathon Ada Tech | Tema 3 — Risk Intelligence

Plataforma de análise de risco financeiro em operações de crédito público do BNDES,
com score preditivo (XGBoost), detecção de anomalias (Isolation Forest), explicabilidade
(SHAP) e agente de IA conversacional em português — **100% local e gratuito** via Ollama.

---

## 🚀 Quick Start (5 minutos para o time)

> ✅ Esta seção foi escrita para que **qualquer integrante do time** consiga rodar o projeto
> do zero, sem depender de chaves de API ou serviços pagos.

### Passo 1 — Clonar o repositório

```bash
git clone https://github.com/<seu-usuario>/Ada.git
cd Ada
```

### Passo 2 — Instalar Python 3.11 e dependências

```bash
# Verificar Python (precisa ser 3.11+ por compatibilidade numpy/pandas/xgboost)
python3.11 --version

# Se não tiver, instale:
#   macOS:    brew install python@3.11
#   Linux:    sudo apt install python3.11 python3.11-venv
#   Windows:  https://www.python.org/downloads/

# Instalar dependências do projeto
python3.11 -m pip install -r requirements.txt
```

### Passo 3 — Setup do agente de IA local (Ollama)

**Opção A — Script automatizado (recomendado):**

```bash
bash scripts/setup_ollama.sh
```

O script faz tudo automaticamente: instala Ollama, baixa o modelo (`llama3.1:8b`, ~5 GB),
inicia o serviço local e roda um smoke test.

**Opção B — Manual:**

```bash
# 1. Instalar Ollama
curl -fsSL https://ollama.com/install.sh | sh           # macOS / Linux
# ou Windows: https://ollama.com/download

# 2. Baixar o modelo (escolha um conforme sua RAM)
ollama pull llama3.1:8b           # 8 GB RAM recomendado
ollama pull llama3.2:3b           # 4 GB RAM (mais leve)
ollama pull qwen2.5:7b-instruct   # 8 GB RAM (alternativa)

# 3. Verificar serviço
curl http://localhost:11434/api/tags
```

> 💡 **Por que Ollama?** Roda 100% local na sua máquina, **sem limites de token**,
> sem chave de API, sem custo. Os mesmos modelos que rodariam em cloud, no seu laptop.

### Passo 4 — Rodar o notebook

```bash
jupyter notebook bndes_risk_intelligence.ipynb
# ou abra no VS Code / Cursor diretamente
```

> 💡 Use o kernel **"Python 3.11"** dentro do Jupyter/VS Code.

---

## 🔄 Estratégia Multi-Provider de LLM (Fallback Automático)

O notebook detecta automaticamente qual provedor LLM está disponível, em ordem de prioridade:

| Prioridade | Provedor | Custo | Limites | Setup |
|---|---|---|---|---|
| 🥇 1 | **Ollama** (local) | Grátis | **Sem limites** | `bash scripts/setup_ollama.sh` |
| 🥈 2 | Groq (cloud) | Grátis | Rate limit (RPM) | `export GROQ_API_KEY=...` |
| 🥉 3 | SHAP-only | — | — | Funciona sempre |

**O agente nunca falha:** se Ollama não estiver instalado, tenta Groq;
se nenhum LLM responder, exibe a explicação SHAP estruturada (ainda útil).

### Customizar modelo Ollama

```bash
# Variáveis de ambiente reconhecidas pelo notebook:
export OLLAMA_BASE_URL="http://localhost:11434/v1"   # padrão
export OLLAMA_MODEL="llama3.1:8b"                    # padrão

# Trocar por um modelo maior/melhor:
export OLLAMA_MODEL="qwen2.5:7b-instruct"
ollama pull qwen2.5:7b-instruct
```

### Modelos recomendados por hardware

| RAM | Modelo recomendado | Tamanho | Qualidade |
|---|---|---|---|
| 4 GB | `llama3.2:3b` | 2 GB | Boa para PT-BR básico |
| 8 GB | `llama3.1:8b` | 5 GB | **Padrão — melhor custo-benefício** |
| 8 GB | `qwen2.5:7b-instruct` | 5 GB | Excelente em PT-BR |
| 16 GB+ | `gemma3:12b` ou `phi4:14b` | 9 GB | Qualidade superior |

---

## 📂 Estrutura do projeto

```
.
├── bndes_risk_intelligence.ipynb  # Notebook principal (todo o pipeline)
├── insights.md                    # Interpretação de negócio dos gráficos
├── requirements.txt               # Dependências Python
├── .gitignore
├── scripts/
│   └── setup_ollama.sh            # Setup automático do agente local (LLM)
├── data/                          # ⚠️ Pastas abaixo são geradas ao rodar o notebook
│   ├── figures/                   #   12 gráficos exportados (PNG)
│   ├── raw/                       #   Dataset BNDES (baixado automaticamente)
│   ├── processed/                 #   bndes_clean.parquet
│   ├── enriched/                  #   bndes_full.parquet, predictions.parquet
│   ├── models/                    #   bndes_risk_model.pkl (joblib)
│   └── bndes_risk.db              #   SQLite com 8 queries analíticas
├── sql/
│   ├── schema.sql                 # Schema das tabelas
│   └── analytics_queries.sql      # 8 queries (window fn, CTE, self-join)
└── docs/
    ├── arquitetura.md             # Documentação técnica completa
    ├── auditoria_e_roadmap.md     # Análise crítica e roadmap
    └── pitch.md                   # Script e storytelling para apresentação
```

---

## 📓 Estrutura do Notebook (107 células)

| Seção | Conteúdo |
|---|---|
| 1 (células 0–18) | Carregamento, inspeção inicial, limpeza base (trabalho da equipe) |
| 2 | Definição da variável target (proxy de stress) |
| 3 | 15 perguntas de negócio com visualizações |
| 4 | Enriquecimento macroeconômico — BCB Olinda (Selic, IPCA, desemprego) |
| **4.5** | **Enriquecimento ADICIONAL: USD/BRL + IBGE SIDRA (PIB e População por UF)** |
| 5 | Detecção de anomalias em pagamentos — Olist (Isolation Forest PF) |
| 6 | SQL Analytics — 7 queries no SQLite (window fn, CTE, self-join) |
| 7 | Feature Engineering — **32 features ex-ante (sem leakage)** |
| 8 | **Modelagem ML robusta:** 4 modelos + CV temporal + tuning + calibração + Lift/Gain + Fairness + análise de erros + target conservador + persistência + `predict_new()` + Isolation Forest |
| 9 | Explicabilidade SHAP (summary plot + waterfall + export JSON) |
| **10** | **Comitê de Risco Inteligente** — 4 agentes (Ollama → Groq → SHAP-only), deliberação em 4 rodadas, decisão fundamentada em lei |
| 11 | Exportação final (Parquet + SQLite + joblib) |

---

## 🌐 Datasets e Fontes de Enriquecimento

| Fonte | Tipo | Uso |
|---|---|---|
| [BNDES Operações](https://dadosabertos.bndes.gov.br/) | Crédito PJ | 23.419 contratos 2002–2026 (base principal) |
| [BCB SGS](https://api.bcb.gov.br) | Macroeconômico | Selic (432), IPCA (13522), Desemprego (24369), USD/BRL (1) |
| [IBGE SIDRA](https://servicodados.ibge.gov.br) | Socioeconômico | PIB per capita por UF, População 2024 por UF |
| [Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) | Pagamentos PF (opcional) | ~100k pedidos para anomalia complementar |

### Download Olist (opcional)

```bash
kaggle datasets download -d olistbr/brazilian-ecommerce
unzip brazilian-ecommerce.zip -d data/raw/olist/
```

---

## ⚖️ Ética e Limitações

- **Target proxy:** stress ≠ inadimplência formal; enriquecível com SCR.Data (BCB)
- **Concept drift temporal:** stress rate sobe de ~5% (2002) para >50% (2023+) por viés de
  seleção (contratos saudáveis recentes ainda estão `ATIVO`). Por isso reportamos
  CV temporal como métrica principal, não o teste pequeno.
- **Auditoria de leakage:** detectamos e corrigimos uma feature contaminada que inflava AUC
  para 1.0 → métricas honestas reportadas (~0.66 CV)
- **LLM-as-Translator:** SHAP sempre injetado no prompt — o LLM **nunca** infere valores
- **Isolation Forest:** 2% de falsos positivos por design (ajustável via `contamination`)
- **Exclusão BNDES:** operações < R$200 não aparecem; subestima microcrédito

---

## 🤖 Modelo preditivo

**Variável target:** `stress = 1` se contrato foi cancelado/não desembolsado (< 50% do valor)
**Split:** treino ≤ 2019 | validação 2020–2021 | teste 2022–2024 (temporal, sem leakage)

### 🚨 Auditoria de Leakage (transparência metodológica)

A primeira versão deste modelo reportava AUC = 1.00 — sinal claro de data leakage.
Identificamos que `valor_desembolsado_reais` estava nas features, mas o target é definido
a partir dele. Removemos toda feature contaminada. Métricas honestas abaixo.

### Métricas (Cross-Validation Temporal, 5 folds — referência principal)

| Modelo | AUC-ROC (CV) |
|---|---|
| Logistic Regression | 0.58 ± 0.06 |
| Random Forest | 0.65 ± 0.06 |
| **XGBoost (tunado)** | **0.66–0.67 ± 0.06** 🏆 |
| LightGBM | 0.64 ± 0.06 |

> Alinhado com benchmarks acadêmicos: Lending Club (0.65–0.72), Home Credit (0.70–0.78).

### Métricas de Negócio
- **Lift@10%** ≈ 1.71× — top decile prioriza stress 71% melhor que aleatório
- **Capture@10%** ≈ 17% — % do stress total nos top 10% do score (≡ R$ 45,7 bi em risco capturado)
- **Modelo serializado** em `data/models/bndes_risk_model.pkl` (~1.8 MB)
- **Função `predict_new(contract_dict)`** pronta para demo ao vivo

### Diferenciais
- Cross-validation temporal (5 folds) — não single split
- 4 modelos comparados (não 1 cego)
- Hyperparameter tuning via `RandomizedSearchCV`
- Calibração isotonic — Brier reduzido em ~20%
- Análise de fairness por UF/porte/setor
- Análise de erros (top 5 FP + top 5 FN)
- Validação cruzada com target conservador
- Enriquecimento socioeconômico via IBGE (PIB e população por UF)
- Risco cambial via USD/BRL (BCB SGS série 1)

---

## 🆘 Troubleshooting

| Problema | Solução |
|---|---|
| `numpy.dtype size changed` | Use Python 3.11 (`python3.11 -m pip install -r requirements.txt`) |
| Ollama não responde | `ollama serve` em outro terminal; ou re-rode `setup_ollama.sh` |
| Modelo Ollama não encontrado | `ollama pull llama3.1:8b` |
| BCB API timeout | Re-rode a célula; é instabilidade temporária da API |
| IBGE API timeout | Já tem fallback estático embutido (dados 2022/2024) |
| Olist não baixou | Pule a Seção 5 (é opcional); o pipeline funciona sem ela |

---

*Ada Tech Hackathon — Grupo 1*
