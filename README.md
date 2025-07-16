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

- Core triangulation logic
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
cd 3DProcessor
make build && make up
```

That's it! The application will be available at:

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8080

### Troubleshooting

You may encounter submodules issues, if so, manually run:

```bash
git submodule update --init --recursive --remote
```

And then, run `make build && make up` again.

## Detailed Instructions

### 1. Environment Setup

The project includes a `.env` file for development configuration. You would usually not commit this, adding it to `.gitignore`, but we've included it for the reviewer's convenience.

The build process automatically handles:

- Git submodule initialization
- npm dependency installation
- WASM compilation
- Docker image building

### 2. Helpful make commands

```bash
# Build and start all services
make build && make up

# Check service health
make health

# View logs
make logs
make logs service=mesh-processor
make logs service=frontend

# help
make help
```

## Testing

### Run All Tests

```bash
make test
```

Runs the C++ unit tests using GoogleTest in a clean Docker environment. This command automatically builds the test image if it doesn't exist, then executes all tests in an isolated container.

#### Test Commands

- **`make test`** - Run tests (builds test image if not exists) - Fast for repeated runs

## Using the Application

### 1. Interactive Drawing

1. Open the frontend in your browser
2. Click on the left canvas to draw a polygon
3. Complete the polygon by clicking near the first point
4. Click "Triangulate" buttons to see the result

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

## License

This project is created for evaluation purposes. See individual component READMEs for specific licensing information.

## Author

**Jesús Izquierdo**

- **LinkedIn**: [linkedin.com/in/jesus-izquierdo-cubas/](https://www.linkedin.com/in/jesus-izquierdo-cubas/)
- **GitHub**: [github.com/jesusizq](https://github.com/jesusizq)
