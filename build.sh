#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
APP_DIR="$ROOT_DIR/SubtitleBurner.app"
BIN="$APP_DIR/Contents/MacOS/SubtitleBurner"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.clang-module-cache" \
  swiftc "$ROOT_DIR/SubtitleBurnerApp.swift" -o "$BIN"

rm -rf "$APP_DIR/Contents/_CodeSignature"
codesign --force --deep --sign - "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "Built $APP_DIR"
