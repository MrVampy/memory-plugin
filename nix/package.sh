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

prepare_dependencies() {
  local packages=${MEMORY_GLEAM_PACKAGES:?}

  rm -rf build
  mkdir -p build/packages
  cp -R --dereference --no-preserve=mode "$packages/." build/packages/
  sed -i '/^yamerl = /d' build/packages/yay/gleam.toml
}

case ${1:-} in
  build)
    shellcheck "$0"
    prepare_dependencies
    gleam build --target javascript --warnings-as-errors
    ;;
  check)
    gleam format --check src test
    install_runtime_dependencies build/dev/javascript
    gleam test --target javascript
    ;;
  install)
    main=${MEMORY_MAIN:?}
    node=${MEMORY_NODE:?}
    mkdir -p "$out/bin" "$out/lib/memory-validator"
    cp -R build/dev/javascript/. "$out/lib/memory-validator/"
    install -Dm644 "$main" "$out/lib/memory-validator/main.mjs"
    install_runtime_dependencies "$out/lib/memory-validator"
    makeWrapper "$node" "$out/bin/memory" \
      --add-flags "$out/lib/memory-validator/main.mjs"
    "$out/bin/memory" validate "$src/test/fixtures/valid"
    ;;
  *)
    printf 'usage: %s build|check|install\n' "$0" >&2
    exit 2
    ;;
esac
