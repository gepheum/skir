# Multilingual Skir Example

This is a simple web application demonstrating how to use Skir with a Python backend and a TypeScript frontend.

## Project Structure

- `skir.yml`: Skir configuration file.
- `skir-src/`: Skir definition files (`.skir`).
- `backend/`: Python backend using `http.server`.
- `frontend/`: TypeScript frontend using Vite.

## Prerequisites

- Node.js and npm
- Python 3

## Setup

1. **Generate Code**:
   Run the Skir code generator in watch mode
   ```bash
   npx skir gen --watch
   ```

2. **Backend**:
   Create a virtual environment and start the Python server.
   ```bash
   cd backend
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   python server.py
   ```
   The server will run on `http://localhost:8080`.

3. **Frontend**:
   In a new terminal, install dependencies and start the frontend.
   ```bash
   cd frontend
   npm install
   npm run serve
   ```
   Open the browser at the URL shown (usually `http://localhost:8000`).

## Usage

Enter a name in the input box and click "Send to Python Backend". The frontend sends a serialized `HelloRequest` struct to the backend, which responds with a serialized `HelloResponse` struct.
