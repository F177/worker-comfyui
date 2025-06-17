#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Ensure ComfyUI-Manager runs in offline network mode
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-comfyui: Starting ComfyUI server in the background..."

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Start the ComfyUI server process
python -u /comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

# Capture its PID and save it
echo $! > /tmp/comfyui.pid

# --- NOVO BLOCO DE ESPERA ---
# Espera ativamente até que a API do ComfyUI esteja respondendo
echo "worker-comfyui: Waiting for ComfyUI API to be available..."
while ! curl -s --fail http://127.0.0.1:8188/prompt > /dev/null; do
    echo -n "."
    sleep 1
done
echo "worker-comfyui: ComfyUI API is ready!"
# --- FIM DO BLOCO DE ESPERA ---

echo "worker-comfyui: Starting RunPod Handler"

# A lógica do if/else para o handler permanece a mesma
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /handler.py
fi