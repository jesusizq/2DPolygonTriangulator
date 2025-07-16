# 3D Processor

A comprehensive system for 2D polygon triangulation with both backend and WebAssembly support, featuring a C++ microservice, WebGL frontend, and interactive visualization capabilities.

## Project Overview

This project demonstrates a scalable, modular approach to geometric processing with the following components:

- **mesh-processor**: High-performance C++ microservice for triangulation using HTTP API
- **frontend**: WebGL-based interactive client with both backend and WASM triangulation options
- **libtriangulation**: Reusable C++ library with WebAssembly bindings
- **Docker Infrastructure**: Complete containerization for easy deployment and development

## Architecture

The system consists of three main components working together:

**Frontend Service (WebGL + HTTP Server)**

- Interactive web application for polygon drawing and visualization
- Built with JavaScript and WebGL for rendering
- Serves static files via simple HTTP server
- Supports dual triangulation modes: client-side (WASM) and server-side (API)

**Mesh Processor Service (C++ Microservice)**

- RESTful API service built with cpp-httplib
- Exposes `/triangulate` endpoint for polygon triangulation requests
- Handles JSON input/output for polygon coordinates and triangle indices
- Includes health checks and structured logging with spdlog

**libtriangulation Library (Shared Core)**

- Core triangulation logic using Mapbox's Delaunay implementation
- Available in two forms:
  - **Native C++**: in the mesh processor service
  - **WebAssembly**: Compiled with Emscripten for client-side processing

**Communication Flow:**

1. Frontend sends HTTP POST requests to `/triangulate` endpoint
2. Mesh processor processes polygons using native libtriangulation
3. Frontend can also process polygons locally using WASM version
4. Both approaches return triangle indices for WebGL rendering

### Technology Stack

| Component      | Technology                       |
| -------------- | -------------------------------- |
| Backend API    | C++17, CMake, cpp-httplib        |
| Core Algorithm | Ear Clipping (mapbox/earcut.hpp) |
| Frontend       | WebGL, ES6 Modules, http-server  |
| WebAssembly    | Emscripten, embind               |
| Container      | Docker, Docker Compose           |
| Build System   | CMake, Make, Shell Scripts       |

## Quick Start

### Prerequisites

- **Docker** and **Docker Compose** (required)
- **Make** (recommended for convenience)
- **Git** with submodule support
- **curl** (for health checks)

### One-Command Setup

```bash
# Clone and start everything
git clone <repository-url>
cd 3D_Processor/3DProcessor
make build && make up
```

That's it! The application will be available at:

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8080

## Detailed Instructions

### 1. Environment Setup

The project includes a `.env` file for development configuration. You would usually not commit this, adding it to `.gitignore`, but we've included it for the reviewer's convenience.

The build process automatically handles:

- Git submodule initialization
- npm dependency installation
- WASM compilation
- Docker image building

### 2. Build and Run (using Make)

```bash
# Build all services
make build

# Start all services
make up

# Check service health
make health

# View logs
make logs
make logs service=mesh-processor
make logs service=frontend
```

#### Option C: Direct Docker Compose

```bash
# Start services
docker compose --env-file config/env.development up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### 3. Development Workflow

#### Frontend Development

```bash
# Start backend only
make mesh-processor-up

# For local development, you can also use npm directly
cd frontend && npm install && npm start

# Access at http://localhost:8000 (local) or http://localhost:3000 (Docker)
```

#### Backend Development

```bash
# Rebuild and restart mesh-processor
make build-mesh-processor
make mesh-processor-up

# View logs
make mesh-processor-logs

# Execute commands in container
make exec service=mesh-processor cmd="bash"
```

#### WASM Development

```bash
# Rebuild WASM module manually
make build-wasm

# Or rebuild entire frontend with WASM
make build-frontend

# Or use npm script directly
cd frontend && npm run build:wasm
```

## Testing

### Run All Tests

```bash
make test
```

Runs the C++ unit tests using GoogleTest in a clean Docker environment. This command automatically builds the test image if it doesn't exist, then executes all tests in an isolated container.

#### Test Commands

- **`make test`** - Run tests (builds test image if not exists) - Fast for repeated runs
- **`make build-test`** - Build test Docker image only
- **`make test-rebuild`** - Force rebuild test image and run tests - Use after code changes

#### Workflow

```bash
# First time or after code changes
make test-rebuild

# Quick test reruns (uses cached image)
make test

# Just build test environment
make build-test
```

### Manual Testing

```bash
# Test mesh-processor API
curl -X POST http://localhost:8080/triangulate \
  -H "Content-Type: application/json" \
  -d '[[0,0],[1,0],[0.5,1]]'

# Test health endpoint
curl http://localhost:8080/health

# Test frontend
curl http://localhost:3000/
```

## Environment Configuration

The project supports multiple environments with different configurations:

### Development (Default)

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8080
- **Features**: Debug logging, CORS enabled, development WASM

### Production

```bash
make up env=production
```

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8080
- **Features**: Optimized builds, compressed assets, production WASM

### Test

```bash
make up env=test
```

- **Frontend**: http://localhost:3001
- **API**: http://localhost:8081
- **Features**: Test-specific configurations, debug logging

## Using the Application

### 1. Interactive Drawing

1. Open the frontend in your browser
2. Click on the left canvas to draw a polygon
3. Complete the polygon by clicking near the first point
4. Click "Triangulate" to see the result

### 2. File Upload

1. Click "Choose File" and select a JSON file
2. File format: `[[x1, y1], [x2, y2], [x3, y3], ...]`
3. Example:
   ```json
   [
     [100, 100],
     [200, 100],
     [200, 200],
     [100, 200]
   ]
   ```

### 3. Triangulation Options

- **Backend**: Uses the C++ microservice (network call)
- **WASM**: Uses client-side WebAssembly (faster, offline capable)

### 4. Interaction

- **Zoom**: Mouse wheel
- **Pan**: Right-click and drag
- **Reset**: Clear button

## Available Commands

### Make Commands

```bash
make help                    # Show all available commands
```

## License

This project is created for evaluation purposes. See individual component READMEs for specific licensing information.

## Author

**Jesús Izquierdo**
