# 🌌 Intergalactic Lost & Found

A simple lost and found application demonstrating end-to-end type-safe communication between a Kotlin backend and TypeScript frontend using [Skir](https://skir.build/).

## Features

- 📝 Report lost or found items across the galaxy
- 🔍 Filter items by status (Lost, Found, Reunited)
- ✨ Mark items as reunited with their owners
- 🚀 End-to-end type safety with Skir RPC
- 💾 In-memory storage (for demo purposes)

## Architecture

- **Backend**: Kotlin with Ktor web framework
- **Frontend**: TypeScript with Vite
- **Communication**: Skir RPC over HTTP
- **Data Schema**: Defined in `.skir` files

## Project Structure

```
intergalactic_lost_and_found/
├── skir.yml                    # Skir configuration
├── skir-src/                   # Skir schema definitions
│   └── lost_and_found.skir    # Lost & found data types and RPC methods
├── backend/                    # Kotlin backend
│   ├── build.gradle.kts       # Gradle build configuration
│   └── src/main/kotlin/       # Kotlin source code
│       └── com/intergalactic/lostfound/
│           ├── Main.kt        # Ktor server setup
│           └── LostAndFoundService.kt  # Service implementation
└── frontend/                   # TypeScript frontend
    ├── package.json           # npm configuration
    ├── index.html            # Main HTML page
    └── src/
        └── main.ts           # Frontend application logic
```

## Prerequisites

- [Node.js](https://nodejs.org/) (v18 or higher)
- Java 17 or higher (for Kotlin/Gradle)
- Gradle (or use the included wrapper)

## Getting Started

### 1. Generate Skir Code

First, generate the type-safe code from the Skir schema:

```bash
npx skir gen
```

This will generate:
- Kotlin code in `backend/src/main/kotlin/com/intergalactic/lostfound/skirout/`
- TypeScript code in `frontend/skirout/`

### 2. Start the Backend

```bash
cd backend
./gradlew run
```

The backend server will start on `http://localhost:8080`

### 3. Start the Frontend

In a new terminal:

```bash
cd frontend
npm install
npm run dev
```

The frontend will start on `http://localhost:3000`

### 4. Use the Application

1. Open your browser to `http://localhost:3000`
2. Fill out the form to report a lost or found item
3. View all items in the list below
4. Filter by status using the filter buttons
5. Mark items as reunited when they're back with their owners

## API Endpoints

### Skir RPC Endpoint

- **URL**: `http://localhost:8080/api`
- **Methods**: GET (query params) and POST (JSON body)
- **Interactive Studio**: `http://localhost:8080/api?studio`

### Available RPC Methods

1. **AddItem** - Add a new lost or found item
2. **ListItems** - List all items (optionally filtered by status)
3. **ReuniteItem** - Mark an item as reunited

## Development

### Watch Mode for Skir

To automatically regenerate code when `.skir` files change:

```bash
npx skir gen --watch
```

### Backend Development

The backend uses:
- **Ktor** for HTTP server
- **Skir Service** for RPC handling
- In-memory storage (no database required for demo)

### Frontend Development

The frontend uses:
- **Vite** for fast development and building
- **Skir ServiceClient** for type-safe RPC calls
- Vanilla TypeScript (no framework)

## How Skir Works

1. **Define Schema**: Create `.skir` files with your data types and RPC methods
2. **Generate Code**: Run `npx skir gen` to generate type-safe code
3. **Implement Backend**: Use generated types and service registration
4. **Call from Frontend**: Use generated client to make type-safe RPC calls

### Example: Adding an Item

**Skir Definition** (`lost_and_found.skir`):
```skir
method AddItem(AddItemRequest): AddItemResponse = 1001;
```

**Kotlin Backend**:
```kotlin
service.addMethod(AddItem) { request, meta ->
    // Implementation
    AddItemResponse(item = newItem)
}
```

**TypeScript Frontend**:
```typescript
const response = await client.invokeRemote(AddItem, request);
```

No manual JSON serialization, no API contracts to maintain, no type mismatches! 🎉

## Try Skir Studio

Visit `http://localhost:8080/api?studio` to use the interactive API explorer:
- Browse available RPC methods
- Test endpoints with sample data
- View request/response schemas

## Learn More

- [Skir Documentation](https://skir.build/docs)
- [Skir GitHub](https://github.com/gepheum/skir)
- [Kotlin Example](https://github.com/gepheum/skir-kotlin-example)

## License

MIT
# skir-lost-and-found-example
