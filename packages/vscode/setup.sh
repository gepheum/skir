#!/bin/zsh

# This script helps set up and run the Skir VSCode extension

echo "Setting up Skir VSCode extension..."

# Install dependencies
npm install

# Check if the compilation succeeds
echo "Compiling TypeScript..."
npm run compile

if [ $? -eq 0 ]; then
  echo "✅ Compilation successful!"
  
  # Check if icon exists
  if [ ! -f "./resources/skir-icon.png" ]; then
    echo "⚠️  Warning: skir-icon.png not found in resources directory."
    echo "   Please follow the instructions in resources/ICON_INSTRUCTIONS.md to create the icon."
  fi
  
  echo ""
  echo "To test the extension:"
  echo "1. Open this folder in VS Code"
  echo "2. Press F5 to launch the extension in a new Extension Development Host window"
  echo "3. Open any .skir file in the examples directory to test syntax highlighting"
  echo "4. Try the 'Go to Definition' feature by Ctrl+clicking (or Cmd+clicking) on imported symbols"
  echo ""
  echo "To package the extension:"
  echo "1. Run: npm run package"
  echo "2. The .vsix file can then be installed in VS Code using the 'Extensions: Install from VSIX' command"
else
  echo "❌ Compilation failed. Please fix the errors and try again."
fi
