#!/bin/bash
cd /workspace
source 'venv/bin/activate'

export PATH="/workspace/llama.cpp/build/bin/:$PATH"

touch llama-swap-models.yaml
./llama-swap --config llama-swap-models.yaml --listen 0.0.0.0:7000 --watch-config &
python model_monitor.py &
OLLAMA_MODELS=/workspace/models ollama serve &
cd ComfyUI && python3 ./main.py --listen &
OPENAI_API_BASE_URL='http://localhost:7000/v1' WEBUI_AUTH=False open-webui serve --port 3000 &
cd /workspace/HFDownloaderWebUI/ && python3 ./app.py &
sleep infinity
