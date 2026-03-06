#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[prestart] $*"; }

POD_RUNTIME_REPO="${POD_RUNTIME_REPO:-https://github.com/markwelshboy/pod-runtime}"
POD_RUNTIME_DIR="${POD_RUNTIME_DIR:-/app/pod-runtime}"
UPSTREAM_START="${UPSTREAM_START:-/start.sh}"
POD_RUNTIME_DISABLE="${POD_RUNTIME_DISABLE:-0}"

# Your preferred “local regex” list
ENV_PERSIST_REGEX="${ENV_PERSIST_REGEX:-^(HF_|GIT_|ENABLE_|INSTALL_|TELEGRAM_|DOWNLOAD_|CIVITAI_|LORA_|MODEL_|RUNPOD_|PATH=|_=)}"

fetch_pod_runtime() {
  [[ "$POD_RUNTIME_DISABLE" == "1" ]] && { log "POD_RUNTIME_DISABLE=1; skipping pod-runtime"; return 0; }
  command -v git >/dev/null 2>&1 || { log "WARNING: git not found; skipping pod-runtime"; return 0; }

  mkdir -p "$(dirname "$POD_RUNTIME_DIR")" /workspace || true

  if [[ -d "$POD_RUNTIME_DIR/.git" ]]; then
    log "pod-runtime exists; updating"
    git -C "$POD_RUNTIME_DIR" fetch --depth 1 origin || true
    git -C "$POD_RUNTIME_DIR" reset --hard origin/HEAD || true
  else
    log "cloning pod-runtime"
    git clone --depth 1 "$POD_RUNTIME_REPO" "$POD_RUNTIME_DIR"
  fi
}

install_shell_files() {
  log "installing bash config from $POD_RUNTIME_DIR"

  [[ -f "$POD_RUNTIME_DIR/.bashrc" ]] || {
    log "no .bashrc in pod-runtime; skipping"
    return 0
  }

  local tmp="/root/.bashrc.temp"

  # Copy repo version
  cp "$POD_RUNTIME_DIR/.bashrc" "$tmp"

  # Inject repo root dynamically
  sed -i "s|REPO_ROOT=<CHANGEME>|REPO_ROOT=\"$POD_RUNTIME_DIR\"|" "$tmp"

  # Install atomically
  install -m 0644 "$tmp" /root/.bashrc
  rm -f "$tmp"

  # Optional helper files
  [[ -f "$POD_RUNTIME_DIR/.bash_functions" ]] && \
    install -m 0644 "$POD_RUNTIME_DIR/.bash_functions" /root/.bash_functions

  [[ -f "$POD_RUNTIME_DIR/.bash_aliases" ]] && \
    install -m 0644 "$POD_RUNTIME_DIR/.bash_aliases" /root/.bash_aliases

  [[ -f "$POD_RUNTIME_DIR/.bash_prompt" ]] && \
    install -m 0644 "$POD_RUNTIME_DIR/.bash_prompt" /root/.bash_prompt

  [[ -f "$POD_RUNTIME_DIR/.git-qol.sh" ]] && \
    install -m 0644 "$POD_RUNTIME_DIR/.git-qol.sh" /root/.git-qol.sh

  [[ -f "$POD_RUNTIME_DIR/ai-toolkit/monitor.sh" ]] && \
    install -m 0755 "$POD_RUNTIME_DIR/aitoolkit/monitor.sh" /usr/local/bin/aitk-monitor

  [[ -f "$POD_RUNTIME_DIR/ai-toolkit/run_with_monitor.sh" ]] && \
    install -m 0755 "$POD_RUNTIME_DIR/aitoolkit/run_with_monitor.sh" /usr/local/bin/aitk-run-with-monitor

  [[ -f "$POD_RUNTIME_DIR/ai-toolkit/patch_buckets.sh" ]] && \
    install -m 0755 "$POD_RUNTIME_DIR/aitoolkit/patch_buckets.sh" /usr/local/bin/aitk-patch-buckets

}

persist_env_for_ssh() {
  local outfile="/etc/rp_environment"
  mkdir -p /etc
  : > "$outfile"

  log "writing SSH env to $outfile"
  log "ENV_PERSIST_REGEX=$ENV_PERSIST_REGEX"

  # Capture selected vars from the *current* runtime env (Vast/Docker env vars)
  printenv \
    | grep -E "$ENV_PERSIST_REGEX" \
    | awk -F= '{
        key=$1
        val=substr($0, index($0,$2))   # keep everything after first "="
        gsub(/\\/,"\\\\",val)
        gsub(/"/,"\\\"",val)
        printf("export %s=\"%s\"\n", key, val)
      }' >> "$outfile"

  # Do NOT touch /root/.bashrc here (you said it's already set up)
}

main() {
  log "wrapper starting (NOT sourcing anything; /start.sh stays clean)"
  fetch_pod_runtime
  install_shell_files
  persist_env_for_ssh

  # Tweak buckets.py to add 720x1280
  local buckets_file="/app/ai-toolkit/toolkit/buckets.py"
  if [[ -f "$buckets_file" ]]; then
    log "Patching buckets.py to add 720x1280 (and 1280x720) if missing"
    aitk-patch-buckets 720x1280 -f "$buckets_file" || log "Failed to patch buckets.py; maybe it was already patched? Continuing anyway..."
  else
    log "WARNING: buckets.py not found at expected location: $buckets_file; skipping bucket patch"
  fi

  if [[ ! -x "$UPSTREAM_START" ]]; then
    log "ERROR: upstream start script not found/executable: $UPSTREAM_START"
    ls -la / || true
    exit 127
  fi

  log "exec -> $UPSTREAM_START $*"
  exec "$UPSTREAM_START" "$@"
}

main "$@"