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
ENV UV_NO_CACHE=1
ENV WORKSPACE="/workspace"
WORKDIR ${WORKSPACE}
RUN python3 -m venv venv
RUN mkdir "pip_cache" && mkdir "tmp" && mkdir "HF" && mkdir "models"
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ComfyUI && cd ComfyUI/custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Manager.git
RUN bash -c "source 'venv/bin/activate' && pip3 install --upgrade pip && pip install uv"
RUN bash -c "source 'venv/bin/activate' && cd ComfyUI && pip install --upgrade --upgrade-strategy only-if-needed -r requirements.txt"
RUN git clone https://github.com/ggml-org/llama.cpp
RUN cd llama.cpp && cmake -B build -DGGML_CUDA=ON && cmake --build build --config Release
RUN git clone https://github.com/vllm-project/vllm.git
RUN bash -c "source 'venv/bin/activate' && cd vllm && python use_existing_torch.py && uv pip install -r requirements/common.txt && uv pip install -r requirements/cuda.txt"
RUN bash -c "source 'venv/bin/activate' && cd vllm && VLLM_USE_PRECOMPILED=1 uv pip install vllm"
RUN bash -c "source 'venv/bin/activate' && uv pip install open-webui"
RUN curl -LO https://ollama.com/download/ollama-linux-amd64.tgz && tar -C /usr -xzf ollama-linux-amd64.tgz && rm ollama-linux-amd64.tgz
RUN git clone https://github.com/ICTylor/HFDownloaderWebUI.git && ln -s /workspace/models /workspace/HFDownloaderWebUI/downloads
RUN bash -c "source 'venv/bin/activate' && uv pip install -r HFDownloaderWebUI/requirements.txt"
RUN curl -L -o llama-swap.tar.gz https://github.com/mostlygeek/llama-swap/releases/download/v157/llama-swap_157_linux_amd64.tar.gz \
    && tar -xzf llama-swap.tar.gz && chmod +x llama-swap && rm llama-swap.tar.gz
RUN bash -c "source 'venv/bin/activate' && uv pip install watchdog PyYAML"
COPY model_monitor.py /workspace
COPY run_everything.sh /

EXPOSE 8188
EXPOSE 3000
EXPOSE 5000
EXPOSE 7000
USER root
# We use ENTRYPOINT to run the init script (from CMD)
ENTRYPOINT [ "/run_everything.sh" ]
