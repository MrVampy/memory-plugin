#!/usr/bin/env bash

set -euo pipefail

install_runtime_dependencies() {
  local root=$1
  local js_yaml=${MEMORY_JS_YAML_TARBALL:?}
  local argparse=${MEMORY_ARGPARSE_TARBALL:?}

  mkdir -p "$root/node_modules/js-yaml" "$root/node_modules/argparse"
  tar -xzf "$js_yaml" -C "$root/node_modules/js-yaml" --strip-components=1
  tar -xzf "$argparse" -C "$root/node_modules/argparse" --strip-components=1
}

case ${1:-} in
  prepare)
    shellcheck "$0"
    sed -i '/^yamerl = /d' build/packages/yay/gleam.toml
    ;;
  check)
    gleam format --check src test
    install_runtime_dependencies build/dev/javascript
    ;;
  install)
    install_runtime_dependencies "$out/lib"
    "$out/bin/memory" validate "$src/test/fixtures/valid"
    ;;
  *)
    printf 'usage: %s prepare|check|install\n' "$0" >&2
    exit 2
    ;;
esac
