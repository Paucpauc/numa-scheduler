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
CHART_PATH="deploy/helm"
VALUES_FILE=""
DRY_RUN=false
UNINSTALL=false
UPGRADE=false

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
    echo "  -f, --values VALUES_FILE      Custom values file"
    echo "  -c, --chart CHART_PATH        Helm chart path (default: deploy/helm)"
    echo "  -d, --dry-run                 Perform a dry run installation"
    echo "  -u, --upgrade                 Upgrade existing installation"
    echo "  -x, --uninstall               Uninstall the release"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                            # Install with default settings"
    echo "  $0 -n monitoring              # Install in monitoring namespace"
    echo "  $0 -f custom-values.yaml      # Install with custom values"
    echo "  $0 -d                         # Dry run installation"
    echo "  $0 -u                         # Upgrade existing installation"
    echo "  $0 -x                         # Uninstall the release"
}

# Function to check if kubectl is available and connected
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "kubectl is available and connected"
}

# Function to check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    
    print_status "Helm is available"
}

# Function to check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace $NAMESPACE does not exist"
        print_status "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
        print_status "Namespace $NAMESPACE created"
    else
        print_status "Namespace $NAMESPACE exists"
    fi
}

# Function to check if release exists
check_release() {
    if helm status "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to install the chart
install_chart() {
    print_header "Installing Helm Chart"
    
    local helm_args=(
        "upgrade"
        "--install"
        "$RELEASE_NAME"
        "$CHART_PATH"
        "--namespace" "$NAMESPACE"
        "--create-namespace"
    )
    
    if [ "$DRY_RUN" = true ]; then
        helm_args+=("--dry-run")
        print_status "Performing dry run installation"
    fi
    
    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values file $VALUES_FILE not found"
            exit 1
        fi
        helm_args+=("--values" "$VALUES_FILE")
        print_status "Using custom values file: $VALUES_FILE"
    fi
    
    print_status "Installing release $RELEASE_NAME in namespace $NAMESPACE..."
    helm "${helm_args[@]}"
    
    if [ "$DRY_RUN" = false ]; then
        print_status "Installation completed successfully"
        
        # Show status
        print_header "Deployment Status"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        
        # Show pods
        print_header "Pods Status"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=numa-scheduler" -o wide
    fi
}

# Function to upgrade the chart
upgrade_chart() {
    print_header "Upgrading Helm Chart"
    
    local helm_args=(
        "upgrade"
        "$RELEASE_NAME"
        "$CHART_PATH"
        "--namespace" "$NAMESPACE"
    )
    
    if [ "$DRY_RUN" = true ]; then
        helm_args+=("--dry-run")
        print_status "Performing dry run upgrade"
    fi
    
    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values file $VALUES_FILE not found"
            exit 1
        fi
        helm_args+=("--values" "$VALUES_FILE")
        print_status "Using custom values file: $VALUES_FILE"
    fi
    
    print_status "Upgrading release $RELEASE_NAME in namespace $NAMESPACE..."
    helm "${helm_args[@]}"
    
    if [ "$DRY_RUN" = false ]; then
        print_status "Upgrade completed successfully"
        
        # Show status
        print_header "Deployment Status"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        
        # Show pods
        print_header "Pods Status"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=numa-scheduler" -o wide
    fi
}

# Function to uninstall the chart
uninstall_chart() {
    print_header "Uninstalling Helm Chart"
    
    if ! check_release; then
        print_warning "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        return 0
    fi
    
    print_status "Uninstalling release $RELEASE_NAME from namespace $NAMESPACE..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
    
    print_status "Uninstallation completed successfully"
}

# Function to show deployment info
show_info() {
    print_header "Deployment Information"
    
    if check_release; then
        print_status "Release: $RELEASE_NAME"
        print_status "Namespace: $NAMESPACE"
        print_status "Chart: $CHART_PATH"
        
        print_header "Helm Status"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        
        print_header "Pods"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=numa-scheduler" -o wide
        
        print_header "Events"
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep numa-scheduler || true
    else
        print_warning "Release $RELEASE_NAME not found in namespace $NAMESPACE"
    fi
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
        -c|--chart)
            CHART_PATH="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        -x|--uninstall)
            UNINSTALL=true
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
    print_header "NUMA Scheduler Deployment"
    
    # Check dependencies
    check_kubectl
    check_helm
    
    # Check namespace
    check_namespace
    
    # Perform action
    if [ "$UNINSTALL" = true ]; then
        uninstall_chart
    elif [ "$UPGRADE" = true ]; then
        upgrade_chart
    else
        install_chart
    fi
    
    # Show info if not dry run
    if [ "$DRY_RUN" = false ] && [ "$UNINSTALL" = false ]; then
        show_info
    fi
}

main