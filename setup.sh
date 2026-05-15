#!/bin/bash
set -euo pipefail

echo "== Metronome - Project Setup =="

if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "Done! Open Metronome.xcodeproj in Xcode to run the app."
echo "  open Metronome.xcodeproj"
