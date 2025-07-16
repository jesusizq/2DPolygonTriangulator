#!/bin/bash

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
ENV_FILE="config/env.$ENV"
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file $ENV_FILE not found"
    echo "Available environments: development, production, test"
    exit 1
fi

# Docker Compose configuration
COMPOSE_FILE="docker-compose.yml"
COMPOSE_CMD="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"

echo "=== 3D Processor - Environment: $ENV ==="

# Validate and run the command
case "$COMMAND" in
    up)
        echo "Starting services..."
        if [ -n "$SERVICE" ]; then
            $COMPOSE_CMD up $DETACHED_MODE $SERVICE
        else
            $COMPOSE_CMD up $DETACHED_MODE --remove-orphans
        fi
        if [ -z "$DETACHED_MODE" ]; then
            echo "✓ Services running. Press Ctrl+C to stop."
        else
            echo "✓ Services started in detached mode"
            echo "Frontend available at: http://localhost:$(FRONTEND_PORT)"
            echo "Mesh Processor API at: http://localhost:$(MESH_PROCESSOR_PORT)"
        fi
        ;;
    up-and-force)
        echo "Building images..."
        if [ -n "$SERVICE" ]; then
            $COMPOSE_CMD build $NO_CACHE $SERVICE
            echo "Starting service with --force-recreate..."
            $COMPOSE_CMD up $DETACHED_MODE --force-recreate $SERVICE
        else
            $COMPOSE_CMD build $NO_CACHE --parallel
            echo "Starting services with --force-recreate..."
            $COMPOSE_CMD up $DETACHED_MODE --force-recreate --remove-orphans
        fi
        ;;
    build)
        echo "Building images..."
        if [ -n "$SERVICE" ]; then
            $COMPOSE_CMD build $NO_CACHE $SERVICE
        else
            $COMPOSE_CMD build $NO_CACHE --parallel
        fi
        echo "✓ Build completed"
        ;;
    down)
        echo "Stopping services..."
        $COMPOSE_CMD down
        echo "✓ Services stopped"
        ;;
    down-and-remove)
        echo "Stopping and removing all resources..."
        $COMPOSE_CMD down -v --rmi all --remove-orphans
        echo "✓ All resources removed"
        ;;
    stop)
        if [ -z "$SERVICE" ]; then
            echo "ERROR: Service name is required for stop command"
            usage
        fi
        echo "Stopping service: $SERVICE"
        $COMPOSE_CMD stop "$SERVICE"
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
        $COMPOSE_CMD stop "$SERVICE" && \
        $COMPOSE_CMD rm -f "$SERVICE"
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