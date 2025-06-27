#!/bin/bash
set -e

# Build script for dart_api_extractor

echo "==> Running pub get..."
dart pub get

# Create build directory if it doesn't exist
mkdir -p build

# Compile the CLI to a native executable
CLI_SRC="src/dart_api_extractor.dart"
OUTPUT="build/dart_api_extractor"

echo "==> Compiling $CLI_SRC to native executable..."
dart compile exe $CLI_SRC -o $OUTPUT

echo "==> Build complete!"
echo "Executable created at: $OUTPUT" 