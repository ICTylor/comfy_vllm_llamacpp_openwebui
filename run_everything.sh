#!/bin/bash
cd "${WORKSPACE_CONTAINER}" || exit

export PATH="${WORKSPACE_CONTAINER}/llama.cpp/build/bin/:$PATH"
if [ -d "/workspace" ]; then
    echo "Using permanent container for models"
    rm -rf "${WORKSPACE_CONTAINER}/models" "${WORKSPACE_PERMANENT}/models"
    ln -s "${WORKSPACE_PERMANENT}/models" "${WORKSPACE_CONTAINER}/models"
    mkdir "${WORKSPACE_PERMANENT}/models"
fi

ln -s "${WORKSPACE_CONTAINER}/models" "${WORKSPACE_CONTAINER}/HFDownloaderWebUI/downloads"

touch llama-swap-models.yaml
./llama-swap --config llama-swap-models.yaml --listen 0.0.0.0:7000 --watch-config &
python model_monitor.py &
OLLAMA_MODELS="${WORKSPACE_CONTAINER}/models" ollama serve &
cd ComfyUI && python3 ./main.py --listen &
OPENAI_API_BASE_URL='http://localhost:7000/v1' WEBUI_AUTH=False open-webui serve --port 3000 &
cd "${WORKSPACE_CONTAINER}/HFDownloaderWebUI/" && python3 ./app.py &
sleep infinity
