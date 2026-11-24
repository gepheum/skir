#!/bin/bash

set -e

echo "🚀 Starting pre-commit checks..."

# Activate virtual environment if it exists
if [ -d ".venv" ]; then
    echo "🔌 Activating virtual environment..."
    source .venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "⚠️  No virtual environment found at .venv, using system Python"
fi

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

if ! command_exists pyright; then
    missing_tools+=("pyright")
fi

if ! command_exists npx; then
    missing_tools+=("npx")
fi

if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "❌ Missing required tools: ${missing_tools[*]}"
    echo "💡 Please install them using one of these methods:"
    
    # Separate Python tools from npx
    python_tools=()
    needs_npx=false
    for tool in "${missing_tools[@]}"; do
        if [ "$tool" = "npx" ]; then
            needs_npx=true
        else
            python_tools+=("$tool")
        fi
    done
    
    if [ ${#python_tools[@]} -ne 0 ]; then
        echo "   For Python tools (${python_tools[*]}):"
        echo "     Option 1: pipx install ${python_tools[*]}"
        echo "     Option 2: brew install ${python_tools[*]} (if available)"
        echo "     Option 3: pip install ${python_tools[*]} --user"
    fi
    
    if [ "$needs_npx" = true ]; then
        echo "   For npx:"
        echo "     Install Node.js (which includes npx):"
        echo "     - brew install node"
        echo "     - Or download from https://nodejs.org/"
    fi
    
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

# Run Skir-to-Python codegen
echo "🔧 Running Skir codegen..."
npx skir gen
echo "✅ Skir codegen done!"

# Check import sorting with isort
echo "📦 Sorting import with isort..."
isort . --skip skirout --skip .venv
echo "✅ Import sorting done!"

# Check code formatting with Black
echo "🎨 Formatting code with Black..."
black . --exclude "(skirout|\.venv)"
echo "✅ Code formatting done!"

# Static analysis with flake8
echo "🔍 Running static analysis with flake8..."

# First check for critical errors (syntax errors, undefined names)
echo "  Checking for critical errors..."
if ! flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics --exclude=skirout,.venv; then
    echo "❌ Critical flake8 errors found!"
    exit 1
fi

# Then check for other issues (treat as warnings that should fail the build)
echo "  Checking for style and complexity issues..."
if ! flake8 . --count --ignore=E203,E704,W503 --max-line-length=127 --statistics --exclude=skirout,.venv; then
    echo "❌ flake8 warnings/errors found!"
    echo "💡 Fix the flake8 issues above before committing"
    exit 1
fi
echo "✅ Static analysis passed!"

# Type checking with pyright
echo "🔍 Running type checking with pyright..."
if ! pyright --project . ; then
    echo "❌ Type checking failed!"
    echo "💡 Fix the type errors above before committing"
    exit 1
fi
echo "✅ Type checking passed!"

# Run snippets.py
echo "▶️  Running snippets.py..."
if ! python snippets.py ; then
    echo "❌ snippets.py execution failed!"
    exit 1
fi
echo "✅ snippets.py executed successfully!"

echo "🎉 All pre-commit checks passed! Ready to commit."
