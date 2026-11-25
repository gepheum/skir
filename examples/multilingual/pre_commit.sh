#!/bin/bash

# pre_commit.sh for multilingual example

set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🚀 Starting pre-commit checks for Multilingual Example..."

npx skir format
npx skir snapshot

# 1. Run Skir codegen
echo "🔄 Regenerating Skir code..."
npx skir gen
echo "✅ Skir code generated."

# 2. Check Backend (Python)
echo "🐍 Checking Backend..."
pushd "$SCRIPT_DIR/backend" > /dev/null

# Create venv if needed (for isolated check)
if [ ! -d "venv" ]; then
    echo "   Creating venv..."
    python3 -m venv venv
fi
source venv/bin/activate

# Install requirements
if [ -f "requirements.txt" ]; then
    echo "   Installing requirements..."
    # Quiet install
    pip install -r requirements.txt > /dev/null
fi

# Basic Syntax Check
echo "   Checking backend.py syntax..."
python3 -m py_compile backend.py

# Optional: flake8 if installed
if command -v flake8 >/dev/null 2>&1; then
    echo "   Running flake8..."
    flake8 --exclude venv,skirout .
fi

deactivate
popd > /dev/null
echo "✅ Backend checks passed."

# 3. Check Frontend (TypeScript)
echo "⚛️  Checking Frontend..."
pushd "$SCRIPT_DIR/frontend" > /dev/null

echo "   Installing dependencies..."
npm install > /dev/null

echo "   Checking code formatting..."
npm run format:check

echo "   Running lint..."
npm run lint

echo "   Building..."
npm run build

popd > /dev/null
echo "✅ Frontend checks passed."

echo "🎉 All checks passed!"
