# Skir VSCode Extension - Development Guide

This guide explains how to test and develop the Skir language extension for Visual Studio Code.

## Method 1: Development/Testing Mode (Recommended for development)

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Compile the TypeScript:**
   ```bash
   npm run compile
   ```

3. **Open the extension folder in VS Code:**
   ```bash
   code .
   ```

4. **Launch Extension Development Host:**
   - Press `F5` or go to `Run > Start Debugging`
   - This will open a new VS Code window titled "Extension Development Host"

5. **Test the extension:**
   - In the Extension Development Host window, open or create a `.skir` file
   - You should see syntax highlighting working
   - Try the "Go to Definition" feature by Ctrl/Cmd+clicking on symbols

## Method 2: Package and Install (For permanent installation)

1. **Package the extension:**
   ```bash
   npm run package
   ```
   This creates a `.vsix` file in your directory.

2. **Install the packaged extension:**
   - Open VS Code
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Extensions: Install from VSIX..."
   - Select the generated `.vsix` file

## Method 3: Publish

```bash
vsce package
vsce publish
```
