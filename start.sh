#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

check_port_in_use() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :$port >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an 2>/dev/null | grep -q ":$port.*LISTEN"
    else
        timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null
    fi
}

find_available_port() {
    local port=$1
    local attempts=0
    while [ $attempts -lt 100 ]; do
        if ! check_port_in_use $port; then
            echo $port
            return 0
        fi
        port=$((port + 1))
        attempts=$((attempts + 1))
    done
    echo $1
    return 1
}

echo "Checking ports..."
BACKEND_PORT=$(find_available_port 8000)
DASHBOARD_PORT=$(find_available_port 3000)

[ "$BACKEND_PORT" != "8000" ] && echo "Port 8000 in use, using $BACKEND_PORT"
[ "$DASHBOARD_PORT" != "3000" ] && echo "Port 3000 in use, using $DASHBOARD_PORT"

if [ ! -f .env ]; then
    cat > .env << EOF
AWS_REGION=us-east-1
ENDPOINT_NAME=your-sagemaker-endpoint
BACKEND_PORT=$BACKEND_PORT
DASHBOARD_PORT=$DASHBOARD_PORT
TF_VAR_project_name=ml-platform
TF_VAR_environment=dev
TF_VAR_aws_region=us-east-1
EOF
    echo "Created .env"
else
    echo ".env already exists (not overwriting)"
fi

if [ ! -f .env.secrets ]; then
    cat > .env.secrets << EOF
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
EOF
    echo "Created .env.secrets"
else
    echo ".env.secrets already exists (not overwriting)"
fi

set -a && source .env && set +a

echo ""
echo "Ready."
echo "  Backend port:   $BACKEND_PORT"
echo "  Dashboard port: $DASHBOARD_PORT"
echo "  AWS Region:     $AWS_REGION"
