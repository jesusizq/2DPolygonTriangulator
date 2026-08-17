#!/bin/bash

# Todas las rutas se anclan al directorio del script, no al directorio desde el
# que se lanza. Antes el compose file era relativo al cwd, así que el script
# solo funcionaba ejecutándolo desde docker/: desde la raíz del repo, docker
# compose no encontraba el fichero y fallaba con "no such file or directory".
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ejecuta un comando y aborta si falla. Sin esto, el script imprimía su "✓" de
# éxito pasara lo que pasara: un despliegue fallido se veía igual que uno bueno.
run_compose() {
    "$@"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: docker compose falló (código $rc). La operación NO se ha completado." >&2
        exit "$rc"
    fi
}

usage() {
    SCRIPT_NAME=$(basename "$0")
    echo "Usage: $SCRIPT_NAME [-n <service>] [-e <env>] [-d] [-c] [up|up-and-force|build|down|down-and-remove|stop|purge|stop-and-remove|logs|health|--help]"
    echo "  up              - Starts all services or specified service"
    echo "  up-and-force    - Force recreate and start services"
    echo "  build           - Builds images without starting containers"
    echo "  down            - Stops services"
    echo "  down-and-remove - Stops and removes containers, volumes, and images"
    echo "  stop            - Stops a specific service without removing it"
    echo "  purge           - Stops, removes a service, its volumes, and prunes unused images"
    echo "  stop-and-remove - Stops and removes a specific service"
    echo "  logs            - Shows logs for all services or specified service"
    echo "  health          - Checks health status of services"
    echo "  --help          - Displays this help message"
    echo ""
    echo "Options:"
    echo "  -n <service>    - Target specific service (mesh-processor, frontend)"
    echo "  -e <env>        - Environment: development, production, or test (defaults to development)"
    echo "  -d              - Run in detached mode (only for up and up-and-force)"
    echo "  -c              - Build images with --no-cache (only for up, up-and-force, and build)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME up                              # Start all services in development"
    echo "  $SCRIPT_NAME -e production up               # Start all services in production"
    echo "  $SCRIPT_NAME -n mesh-processor up           # Start only mesh-processor"
    echo "  $SCRIPT_NAME -d up                          # Start all services detached"
    echo "  $SCRIPT_NAME -c build                       # Build with no cache"
    echo "  $SCRIPT_NAME logs -n frontend               # Show frontend logs"
    exit 1
}

# Initialize variables
SERVICE=""
ENV="development"
DETACHED_MODE=""
NO_CACHE=""
COMMAND=""
FRONTEND_PORT=3000
MESH_PROCESSOR_PORT=8080

# Process options
while getopts ":n:e:dc" opt; do
    case ${opt} in
        n )
            SERVICE=$OPTARG
            ;;
        e )
            case $OPTARG in
                development|production|test)
                    ENV=$OPTARG
                    ;;
                *)
                    echo "Invalid environment: $OPTARG. Must be development, production, or test" 1>&2
                    usage
                    ;;
            esac
            ;;
        d )
            DETACHED_MODE="-d"
            ;;
        c )
            NO_CACHE="--no-cache"
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." 1>&2
            usage
            ;;
    esac
done

# Shift away the parsed options
shift $((OPTIND - 1))

COMMAND="$1"

if [ "$COMMAND" = "--help" ]; then
    usage
fi

if [ -z "$COMMAND" ]; then
    echo "ERROR: No command specified"
    usage
fi

# Set ENV_FILE based on environment
ENV_FILES_ARGS=""
# Check for base .env in repo root or docker dir
if [ -f "$REPO_ROOT/.env" ]; then
    ENV_FILES_ARGS="$ENV_FILES_ARGS --env-file $REPO_ROOT/.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    ENV_FILES_ARGS="$ENV_FILES_ARGS --env-file $SCRIPT_DIR/.env"
fi

# Check for specific environment file in repo root or docker dir
if [ -f "$REPO_ROOT/.env.$ENV" ]; then
    ENV_FILES_ARGS="$ENV_FILES_ARGS --env-file $REPO_ROOT/.env.$ENV"
elif [ -f "$SCRIPT_DIR/.env.$ENV" ]; then
    ENV_FILES_ARGS="$ENV_FILES_ARGS --env-file $SCRIPT_DIR/.env.$ENV"
fi

if [ -z "$ENV_FILES_ARGS" ]; then
    echo "ERROR: No environment files found (.env or .env.$ENV)"
    exit 1
fi

# Docker Compose configuration
# Rutas absolutas: los build.context del compose (../frontend, ../mesh-processor)
# se resuelven respecto al fichero compose, así que siguen apuntando a lo mismo.
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
COMPOSE_CMD="docker compose -f $COMPOSE_FILE $ENV_FILES_ARGS"

if [ "$ENV" = "production" ]; then
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE -f $SCRIPT_DIR/docker-compose.override.yml $ENV_FILES_ARGS"
fi

echo "=== 3D Processor - Environment: $ENV ==="

# Validate and run the command
case "$COMMAND" in
    up)
        echo "Starting services..."
        if [ -n "$SERVICE" ]; then
            run_compose $COMPOSE_CMD up $DETACHED_MODE $SERVICE
        else
            run_compose $COMPOSE_CMD up $DETACHED_MODE --remove-orphans
        fi
        if [ -z "$DETACHED_MODE" ]; then
            echo "✓ Services running. Press Ctrl+C to stop."
        else
            echo "✓ Services started in detached mode"
            if [ "$ENV" = "production" ]; then
                # En producción solo el gateway publica puertos (ver
                # docker-compose.override.yml); frontend y mesh-processor son
                # `expose`, así que las URLs de desarrollo no aplican.
                echo "Comprueba el estado con: docker ps"
            else
                echo "Frontend available at: http://localhost:${FRONTEND_PORT}"
                echo "Mesh Processor API at: http://localhost:${MESH_PROCESSOR_PORT}"
            fi
        fi
        ;;
    up-and-force)
        echo "Building images..."
        if [ -n "$SERVICE" ]; then
            run_compose $COMPOSE_CMD build $NO_CACHE $SERVICE
            echo "Starting service with --force-recreate..."
            run_compose $COMPOSE_CMD up $DETACHED_MODE --force-recreate $SERVICE
        else
            run_compose $COMPOSE_CMD build $NO_CACHE --parallel
            echo "Starting services with --force-recreate..."
            run_compose $COMPOSE_CMD up $DETACHED_MODE --force-recreate --remove-orphans
        fi
        ;;
    build)
        echo "Building images..."
        if [ -n "$SERVICE" ]; then
            run_compose $COMPOSE_CMD build $NO_CACHE $SERVICE
        else
            run_compose $COMPOSE_CMD build $NO_CACHE --parallel
        fi
        echo "✓ Build completed"
        ;;
    down)
        echo "Stopping services..."
        run_compose $COMPOSE_CMD down
        echo "✓ Services stopped"
        ;;
    down-and-remove)
        echo "Stopping and removing all resources..."
        run_compose $COMPOSE_CMD down -v --rmi all --remove-orphans
        echo "✓ All resources removed"
        ;;
    stop)
        if [ -z "$SERVICE" ]; then
            echo "ERROR: Service name is required for stop command"
            usage
        fi
        echo "Stopping service: $SERVICE"
        run_compose $COMPOSE_CMD stop "$SERVICE"
        echo "✓ Service $SERVICE stopped"
        ;;
    purge)
        if [ -z "$SERVICE" ]; then
            echo "ERROR: Service name is required for purge command"
            usage
        fi
        echo "Purging service: $SERVICE"
        $COMPOSE_CMD stop "$SERVICE" && \
        $COMPOSE_CMD rm -v -f "$SERVICE" && \
        docker rmi $(docker images -q --filter "label=com.docker.compose.service=$SERVICE") 2>/dev/null && \
        docker image prune -f --filter "label=com.docker.compose.service=$SERVICE" 2>/dev/null
        echo "✓ Service $SERVICE purged"
        ;;
    stop-and-remove)
        if [ -z "$SERVICE" ]; then
            echo "ERROR: Service name is required for stop-and-remove command"
            usage
        fi
        echo "Stopping and removing service: $SERVICE"
        run_compose $COMPOSE_CMD stop "$SERVICE"
        run_compose $COMPOSE_CMD rm -f "$SERVICE"
        echo "✓ Service $SERVICE stopped and removed"
        ;;
    logs)
        echo "Showing logs..."
        if [ -n "$SERVICE" ]; then
            $COMPOSE_CMD logs -f "$SERVICE"
        else
            $COMPOSE_CMD logs -f
        fi
        ;;
    health)
        echo "Checking service health..."
        
        # Check mesh-processor health
        echo -n "Mesh Processor (port $MESH_PROCESSOR_PORT): "
        if curl -sf "http://localhost:$MESH_PROCESSOR_PORT/health" >/dev/null 2>&1; then
            echo "✓ Healthy"
        else
            echo "Unhealthy or not running"
        fi
        
        # Check frontend health
        echo -n "Frontend (port $FRONTEND_PORT): "
        if curl -sf "http://localhost:$FRONTEND_PORT/" >/dev/null 2>&1; then
            echo "✓ Healthy"
        else
            echo "Unhealthy or not running"
        fi
        ;;
    *)
        echo "ERROR: Invalid command: '$COMMAND'"
        usage
        ;;
esac 