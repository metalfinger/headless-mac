#!/bin/bash
# Builds factory-display with the command line developer tools (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O -import-objc-header CGVirtualDisplay.h main.swift -o factory-display
codesign --force --sign - factory-display
echo "built $(pwd)/factory-display"
