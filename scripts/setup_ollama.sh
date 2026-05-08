#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# BNDES Risk Intelligence — Setup do agente local (Ollama)
# ════════════════════════════════════════════════════════════════════════════
# Roda em macOS, Linux. Para Windows: baixe https://ollama.com/download
#
# Uso:    bash scripts/setup_ollama.sh
#         OLLAMA_MODEL="llama3.2:3b" bash scripts/setup_ollama.sh   # modelo menor
# ════════════════════════════════════════════════════════════════════════════

set -e

OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
OS_NAME="$(uname -s)"

echo "════════════════════════════════════════════════════════════════"
echo "  BNDES Risk Intelligence — Setup do Agente Local (Ollama)"
echo "════════════════════════════════════════════════════════════════"
echo "  Sistema:       $OS_NAME"
echo "  Modelo alvo:   $OLLAMA_MODEL"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1) Instalar Ollama se não existir
if ! command -v ollama &> /dev/null; then
    echo "📦 Ollama não encontrado. Instalando..."
    if [[ "$OS_NAME" == "Darwin" || "$OS_NAME" == "Linux" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "❌ Sistema $OS_NAME não suportado por este script."
        echo "   Para Windows, baixe o instalador em https://ollama.com/download"
        exit 1
    fi
else
    OLLAMA_VER=$(ollama --version 2>&1 | head -1)
    echo "✅ Ollama já instalado: $OLLAMA_VER"
fi

# 2) Iniciar serviço (em background) se ainda não estiver rodando
if ! curl -s -o /dev/null http://localhost:11434/api/tags; then
    echo ""
    echo "🚀 Iniciando serviço Ollama em background..."
    if [[ "$OS_NAME" == "Darwin" ]]; then
        open -ga Ollama 2>/dev/null || ollama serve > /tmp/ollama.log 2>&1 &
    else
        ollama serve > /tmp/ollama.log 2>&1 &
    fi
    sleep 3
fi

# Aguarda até o serviço responder
RETRIES=10
while ! curl -s -o /dev/null http://localhost:11434/api/tags; do
    RETRIES=$((RETRIES-1))
    if [ $RETRIES -le 0 ]; then
        echo "❌ Serviço Ollama não subiu. Tente: ollama serve"
        exit 1
    fi
    sleep 1
done
echo "✅ Serviço Ollama rodando em http://localhost:11434"

# 3) Baixar modelo
echo ""
echo "📥 Baixando modelo $OLLAMA_MODEL (pode levar alguns minutos na primeira vez)..."
ollama pull "$OLLAMA_MODEL"

# 4) Smoke test
echo ""
echo "🧪 Smoke test: enviando uma pergunta de teste..."
RESPONSE=$(curl -s http://localhost:11434/api/generate \
    -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"Responda em uma palavra: ok?\",\"stream\":false}" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('response','ERRO'))" 2>/dev/null \
    || echo "ERRO")

echo "   Resposta do modelo: ${RESPONSE:0:60}..."

if [[ "$RESPONSE" == "ERRO" || -z "$RESPONSE" ]]; then
    echo "⚠️  Smoke test falhou. Verifique o log em /tmp/ollama.log"
    exit 1
fi

# 5) Sucesso
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ TUDO PRONTO!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  O notebook irá detectar Ollama automaticamente quando rodar"
echo "  a Seção 10 (Agente de IA). Sem necessidade de configurar API key."
echo ""
echo "  Modelos baixados localmente:"
ollama list
echo ""
echo "  Para trocar o modelo, edite o notebook ou use:"
echo "    OLLAMA_MODEL=qwen2.5:7b-instruct jupyter notebook Untitled3.ipynb"
echo ""
echo "════════════════════════════════════════════════════════════════"
