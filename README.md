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

**Frontend Service (WebGL + Nginx)**

- Interactive web application for polygon drawing and visualization
- Built with vanilla JavaScript and WebGL for 3D rendering
- Serves static files via Nginx in production
- Supports dual triangulation modes: client-side (WASM) and server-side (API)

**Mesh Processor Service (C++ Microservice)**

- RESTful API service built with cpp-httplib
- Exposes `/triangulate` endpoint for polygon triangulation requests
- Handles JSON input/output for polygon coordinates and triangle indices
- Includes health checks and structured logging with spdlog

**libtriangulation Library (Shared Core)**

- Core triangulation logic using Mapbox's Delaunay implementation
- Available in two forms:
  - **Native C++**: Statically linked into the mesh processor service
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
| Frontend       | WebGL, ES6 Modules, Nginx        |
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
cd 3D_Processor
make setup && make up
```

That's it! The application will be available at:

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8080

## Detailed Instructions

### 1. Environment Setup

```bash
# Copy environment configuration
make setup

# Or manually:
cp config/env.development .env
```

### 2. Build and Run

#### Option A: Using Make (Recommended)

```bash
# Build all services
make build

# Start all services
make up

# Start in development mode (with hot reload)
make dev-up

# Check service health
make health

# View logs
make logs
make logs service=mesh-processor
make logs service=frontend
```

#### Option B: Using run.sh Script

```bash
# Make script executable (if needed)
chmod +x scripts/run.sh

# Start all services
./scripts/run.sh -d up

# Start specific service
./scripts/run.sh -n mesh-processor up

# Start in production environment
./scripts/run.sh -e production -d up

# Check health
./scripts/run.sh health
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

# Start development frontend (hot reload)
make dev-up

# Access at http://localhost:8000
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
make wasm-build

# Or rebuild entire frontend with WASM
make build-frontend
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
- **Dev Frontend**: http://localhost:8000 (hot reload)
- **API**: http://localhost:8080
- **Features**: Debug logging, CORS enabled, development WASM

### Production

```bash
make up env=production
# or
./scripts/run.sh -e production up
```

- **Frontend**: http://localhost:80
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
make setup                   # Initial setup
make build [env=<env>]       # Build images
make up [env=<env>]          # Start services
make dev-up                  # Development mode
make down [env=<env>]        # Stop services
make clean                   # Remove all containers/images
make test                    # Run tests
make health                  # Check service health
make logs [service=<name>]   # View logs
```

### Script Commands

```bash
./scripts/run.sh --help      # Show script help
./scripts/run.sh up          # Start all services
./scripts/run.sh -n <service> up  # Start specific service
./scripts/run.sh -e <env> up # Start in specific environment
./scripts/run.sh health      # Check health
./scripts/run.sh logs        # View logs
```

## Algorithm Choice: Ear Clipping

This project uses the **Ear Clipping** algorithm via `mapbox/earcut.hpp` for triangulation.

### Why Ear Clipping?

**Advantages:**

- **Simple & Fast**: Optimal for simple polygons without holes
- **Lightweight**: Header-only library, easy integration
- **Reliable**: Battle-tested implementation from Mapbox
- **Cross-platform**: Works in both C++ and WebAssembly

**Comparison with Delaunay Triangulation:**

- **Delaunay**: Better triangle quality, handles complex inputs
- **Ear Clipping**: Faster for simple polygons, smaller footprint
- **Choice**: For this demo's requirements, ear clipping provides the best balance

## Performance & Scalability

### Current Performance

- **WASM**: < 1ms for simple polygons, runs in browser
- **Backend**: < 10ms including network latency
- **Frontend**: 60fps WebGL rendering

### Scalability Features

- **Containerized**: Easy horizontal scaling
- **Stateless**: Each service can be replicated
- **Modular**: Components can be deployed independently
- **WASM Fallback**: Reduces server load

### Future Enhancements

- Load balancing for mesh-processor
- Redis caching for frequent triangulations
- WebWorkers for complex WASM computations
- Multiple triangulation algorithms

## Contributing

### Development Setup

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes and test: `make test`
4. Commit: `git commit -m 'Add amazing feature'`
5. Push: `git push origin feature/amazing-feature`
6. Create Pull Request

### Code Style

- **C++**: Follow Google C++ Style Guide
- **JavaScript**: ES6 modules, functional style
- **Docker**: Multi-stage builds, security best practices

## License

This project is created for evaluation purposes. See individual component READMEs for specific licensing information.

## Author

**Jesús Izquierdo**
