#!/bin/bash
echo "Setting up Git pre-commit hook..."
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
./pre_commit.sh
if [ $? -ne 0 ]; then
    echo "Pre-commit checks failed. Commit aborted."
    exit 1
fi
echo "Pre-commit checks passed. Proceeding with commit."
EOF
chmod +x .git/hooks/pre-commit
echo "Pre-commit hook has been set up successfully!"
