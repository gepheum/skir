#!/bin/bash

set -e

echo "🚀 Starting pre-commit checks..."

# Activate virtual environment if it exists
if [ -d ".venv" ]; then
    echo "🔌 Activating virtual environment..."
    source .venv/bin/activate
    echo "✅ Virtual environment activated"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Checking for required tools..."
missing_tools=()

if ! command_exists isort; then
    missing_tools+=("isort")
fi

if ! command_exists black; then
    missing_tools+=("black")
fi

if ! command_exists flake8; then
    missing_tools+=("flake8")
fi

if ! command_exists pyright; then
    missing_tools+=("pyright")
fi

if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "❌ Missing required tools: ${missing_tools[*]}"
    echo "💡 Please install them using one of these methods:"
    echo "   Option 1: pip install -r requirements.txt"
    echo "   Option 2: pipx install ${missing_tools[*]}"
    exit 1
fi

echo "✅ All required tools are available"

if [ -f requirements.txt ] && [ -s requirements.txt ]; then
    echo "📋 Installing project dependencies..."
    if ! python -m pip install -r requirements.txt --user 2>/dev/null && ! python -m pip install -r requirements.txt --break-system-packages 2>/dev/null; then
        echo "⚠️  Could not install requirements.txt dependencies, continuing anyway..."
    fi
fi

echo "📦 Installing local package (editable)..."
if ! python -m pip install -e . --user 2>/dev/null && ! python -m pip install -e . --break-system-packages 2>/dev/null; then
    echo "⚠️  Could not install editable package, continuing anyway..."
fi

echo "📦 Sorting imports with isort..."
isort . --skip .venv
echo "✅ Import sorting done!"

echo "🎨 Formatting code with Black..."
black . --exclude "\.venv"
echo "✅ Code formatting done!"

echo "🔍 Running static analysis with flake8..."
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics --exclude=.venv
flake8 . --count --ignore=E203,E704,W503 --max-line-length=127 --statistics --exclude=.venv
echo "✅ Static analysis passed!"

echo "🔍 Running type checking with pyright..."
pyright --project .
echo "✅ Type checking passed!"

echo "🧪 Running unit tests..."
python -m unittest discover tests/ -p "test_*.py" -v
echo "✅ All unit tests passed!"

echo "🎉 All pre-commit checks passed! Ready to commit."
