#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    
    print_status "All dependencies are installed"
}

# Build the Go binary
build_binary() {
    print_status "Building Go binary..."
    
    # Create bin directory if it doesn't exist
    mkdir -p bin
    
    # Build for multiple platforms
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
        -ldflags='-w -s -extldflags "-static"' \
        -a -installsuffix cgo \
        -o bin/cpuset-hook-linux-amd64 \
        ./cmd/cpuset-hook
    
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
        -ldflags='-w -s -extldflags "-static"' \
        -a -installsuffix cgo \
        -o bin/cpuset-hook-linux-arm64 \
        ./cmd/cpuset-hook
    
    # Create symlink for default architecture
    ln -sf cpuset-hook-linux-amd64 bin/cpuset-hook
    
    print_status "Binary built successfully"
}

# Build Docker image
build_docker() {
    print_status "Building Docker image..."
    
    # Get version from git or use default
    VERSION=${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo "latest")}
    IMAGE_NAME=${IMAGE_NAME:-numa-scheduler}
    
    docker build -t "${IMAGE_NAME}:${VERSION}" .
    docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:latest"
    
    print_status "Docker image built successfully: ${IMAGE_NAME}:${VERSION}"
}

# Generate base64 binary for ConfigMap
generate_binary() {
    print_status "Generating base64 binary for ConfigMap..."
    
    if [ ! -f "bin/cpuset-hook" ]; then
        print_error "Binary not found. Run build first."
        exit 1
    fi
    
    # Generate base64 encoded binary
    base64 bin/cpuset-hook | tr -d '\n' > deploy/helm/templates/_binary.txt
    
    print_status "Base64 binary generated in deploy/helm/templates/_binary.txt"
}

# Package Helm chart
package_helm() {
    print_status "Packaging Helm chart..."
    
    cd deploy/helm
    helm package .
    cd ../..
    
    print_status "Helm chart packaged successfully"
}

# Main function
main() {
    local command=${1:-"all"}
    
    case $command in
        "deps")
            check_dependencies
            ;;
        "binary")
            check_dependencies
            build_binary
            ;;
        "docker")
            check_dependencies
            build_docker
            ;;
        "generate")
            check_dependencies
            generate_binary
            ;;
        "helm")
            check_dependencies
            package_helm
            ;;
        "all")
            check_dependencies
            build_binary
            build_docker
            generate_binary
            package_helm
            ;;
        *)
            echo "Usage: $0 {deps|binary|docker|generate|helm|all}"
            echo ""
            echo "Commands:"
            echo "  deps     - Check dependencies"
            echo "  binary   - Build Go binary"
            echo "  docker   - Build Docker image"
            echo "  generate - Generate base64 binary for ConfigMap"
            echo "  helm     - Package Helm chart"
            echo "  all      - Run all build steps (default)"
            exit 1
            ;;
    esac
}

main "$@"