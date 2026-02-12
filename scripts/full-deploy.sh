#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="kube-system"
RELEASE_NAME="numa-scheduler"
VALUES_FILE="deploy/helm/values-binary.yaml"
DRY_RUN=false

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

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE     Kubernetes namespace (default: kube-system)"
    echo "  -r, --release RELEASE_NAME    Helm release name (default: numa-scheduler)"
    echo "  -f, --values VALUES_FILE      Custom values file (default: deploy/helm/values-binary.yaml)"
    echo "  -d, --dry-run                 Perform a dry run installation"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "This script performs a complete build and deployment:"
    echo "  1. Builds the Go binary"
    echo "  2. Generates base64 encoding for ConfigMap"
    echo "  3. Updates values file with binary content"
    echo "  4. Deploys via Helm"
    echo ""
    echo "Examples:"
    echo "  $0                            # Full build and deploy"
    echo "  $0 -d                         # Full build and dry run"
    echo "  $0 -n monitoring              # Deploy to monitoring namespace"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header "NUMA Scheduler Full Build and Deploy"
    
    print_status "Starting complete build and deployment process..."
    
    # Step 1: Build binary
    print_header "Step 1: Building Go Binary"
    make build
    print_status "Binary built successfully"
    
    # Step 2: Generate binary for ConfigMap
    print_header "Step 2: Generating Binary for ConfigMap"
    make generate-binary
    print_status "Binary generated and encoded successfully"
    
    # Step 3: Deploy via Helm
    print_header "Step 3: Deploying via Helm"
    
    local helm_args=(
        "./scripts/deploy.sh"
        "--namespace" "$NAMESPACE"
        "--release" "$RELEASE_NAME"
        "--values" "$VALUES_FILE"
    )
    
    if [ "$DRY_RUN" = true ]; then
        helm_args+=("--dry-run")
        print_status "Performing dry run deployment"
    fi
    
    print_status "Deploying with arguments: ${helm_args[*]}"
    "${helm_args[@]}"
    
    print_header "Deployment Complete"
    print_status "NUMA Scheduler has been successfully deployed!"
    
    if [ "$DRY_RUN" = false ]; then
        print_status ""
        print_status "To check the deployment:"
        print_status "  kubectl get daemonset $RELEASE_NAME -n $NAMESPACE"
        print_status "  kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=numa-scheduler"
        print_status ""
        print_status "To test with a pod:"
        print_status "  kubectl apply -f examples/pod-with-cpu-set.yaml"
    fi
}

main