#!/bin/bash

set -e

echo "🚀 Starting pre-commit checks..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools and suggest installation if missing
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

if ! command_exists pytest && ! python -c "import pytest" 2>/dev/null; then
    missing_tools+=("pytest")
fi

if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "❌ Missing required tools: ${missing_tools[*]}"
    echo "💡 Please install them using one of these methods:"
    echo "   Option 1: pipx install ${missing_tools[*]}"
    echo "   Option 2: brew install ${missing_tools[*]} (if available)"
    echo "   Option 3: pip install ${missing_tools[*]} --user"
    exit 1
fi

echo "✅ All required tools are available"

# Install project dependencies if requirements.txt exists and has content
if [ -f requirements.txt ] && [ -s requirements.txt ]; then
    echo "📋 Installing project dependencies..."
    if ! python -m pip install -r requirements.txt --user 2>/dev/null && ! python -m pip install -r requirements.txt --break-system-packages 2>/dev/null; then
        echo "⚠️  Could not install requirements.txt dependencies, continuing anyway..."
    fi
fi

# Check import sorting with isort
echo "📦 Sorting import with isort..."
isort .
echo "✅ Import sorting done!"

# Check code formatting with Black
echo "🎨 Formatting code with Black..."
black .
echo "✅ Code formatting done!"

# Static analysis with flake8
echo "🔍 Running static analysis with flake8..."

# First check for critical errors (syntax errors, undefined names)
echo "  Checking for critical errors..."
if ! flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics; then
    echo "❌ Critical flake8 errors found!"
    exit 1
fi

# Then check for other issues (treat as warnings that should fail the build)
echo "  Checking for style and complexity issues..."
if ! flake8 . --count --ignore=E203,E704,W503 --max-line-length=127 --statistics; then
    echo "❌ flake8 warnings/errors found!"
    echo "💡 Fix the flake8 issues above before committing"
    exit 1
fi
echo "✅ Static analysis passed!"

# Run unit tests
echo "🧪 Running unit tests..."
if ! python -m unittest discover tests/ -p "test_*.py" -v; then
    echo "❌ Unit tests failed!"
    exit 1
fi
echo "✅ All unit tests passed!"

echo "🎉 All pre-commit checks passed! Ready to commit."