#!/usr/bin/env bash
set -euo pipefail

NIM_VERSION=${NIM_VERSION:-1.6.12}
NIMBLE_BIN="$HOME/.nimble/bin"

if [[ -d "$NIMBLE_BIN" ]]; then
  export PATH="$NIMBLE_BIN:$PATH"
fi

install_choosenim() {
  local urls=(
    "https://nim-lang.org/choosenim/init.sh"
    "https://raw.githubusercontent.com/dom96/choosenim/master/init.sh"
  )

  for url in "${urls[@]}"; do
    echo "Attempting to download choosenim from $url"
    if curl -fsSL "$url" | sh -s -- -y; then
      return 0
    fi
  done

  return 1
}

install_via_apt() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "Attempting to install Nim via apt-get"
    apt-get update -y
    apt-get install -y nim
    return 0
  fi
  return 1
}

if ! command -v nim >/dev/null 2>&1; then
  echo "Installing Nim via choosenim..."
  if install_choosenim; then
    export PATH="$NIMBLE_BIN:$PATH"
  else
    echo "choosenim installation failed; trying apt-get"
    install_via_apt
  fi
fi

if ! command -v nim >/dev/null 2>&1; then
  echo "Nim installation failed"
  exit 1
fi

if command -v choosenim >/dev/null 2>&1; then
  choosenim "$NIM_VERSION"
fi

echo "Nim version: $(nim -v | head -n 1)"
