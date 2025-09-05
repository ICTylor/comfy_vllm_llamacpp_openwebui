FROM nvcr.io/nvidia/pytorch:25.08-py3

# Install system packages
ENV DEBIAN_FRONTEND=noninteractive

# Install needed packages
RUN apt-get update -y --fix-missing \
    # && apt-get upgrade -y \
    && apt-get install -y \
    build-essential \
    python3-dev \
    unzip \
    wget \
    zip \
    zlib1g \
    zlib1g-dev \
    gnupg \
    rsync \
    python3-pip \
    python3-venv \
    git \
    sudo \
    libglib2.0-0 \
    socat \
    ffmpeg \
    && apt-get clean

# https://github.com/pypa/pip/issues/2897 0 in this case actually means no cache dir
ENV PIP_NO_CACHE_DIR=0
# just to try to avoid extra size
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV UV_BREAK_SYSTEM_PACKAGES=1
ENV UV_SYSTEM_PYTHON=true
ENV UV_NO_CACHE=1
ENV WORKSPACE_CONTAINER="/workspace_container"
ENV WORKSPACE_PERMANENT="/workspace"
WORKDIR "${WORKSPACE_CONTAINER}"
RUN mkdir "pip_cache" && mkdir "tmp" && mkdir "HF" && mkdir "models"
RUN git clone https://github.com/ggml-org/llama.cpp && \
    git clone https://github.com/vllm-project/vllm.git && \
    git clone https://github.com/ICTylor/HFDownloaderWebUI.git && \
    git clone https://github.com/comfyanonymous/ComfyUI.git ComfyUI && cd ComfyUI/custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN pip3 install --upgrade pip && pip install uv
RUN cd ComfyUI && pip install --upgrade --upgrade-strategy only-if-needed -r requirements.txt
RUN cd llama.cpp && cmake -B build -DGGML_CUDA=ON && cmake --build build --config Release
RUN cd vllm && python use_existing_torch.py && uv pip install -r requirements/common.txt && uv pip install -r requirements/cuda.txt && VLLM_USE_PRECOMPILED=1 uv pip install vllm
RUN uv pip install open-webui
RUN curl -LO https://ollama.com/download/ollama-linux-amd64.tgz && tar -C /usr -xzf ollama-linux-amd64.tgz && rm ollama-linux-amd64.tgz
RUN curl -L -o llama-swap.tar.gz https://github.com/mostlygeek/llama-swap/releases/download/v157/llama-swap_157_linux_amd64.tar.gz \
    && tar -xzf llama-swap.tar.gz && chmod +x llama-swap && rm llama-swap.tar.gz
RUN uv pip install watchdog PyYAML
RUN uv pip install -r HFDownloaderWebUI/requirements.txt
COPY model_monitor.py "${WORKSPACE_CONTAINER}"
COPY run_everything.sh /

EXPOSE 8188
EXPOSE 3000
EXPOSE 5000
EXPOSE 7000
USER root
# We use ENTRYPOINT to run the init script (from CMD)
ENTRYPOINT [ "/run_everything.sh" ]
