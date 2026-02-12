# NUMA Scheduler

NUMA-aware CPU set scheduler hook for containerd that allows configuring CPU affinity for containers based on pod annotations.

## Overview

The project provides an OCI hook for containerd that automatically configures CPU affinity (cpuset) for containers based on Kubernetes pod annotations. This is especially useful for NUMA systems where it's important to bind containers to specific CPU nodes for performance optimization.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │    containerd    │    │   OCI Hook      │
│     Pod         │───▶│   Runtime        │───▶│  cpuset-hook    │
│  (annotations)  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   cgroup fs     │
                                               │  cpuset.cpus    │
                                               └─────────────────┘
```

## Features

- **Automatic CPU affinity configuration** based on pod annotations
- **NUMA system support** for performance optimization
- **Integration with containerd** via OCI hooks
- **Flexible configuration** through Helm chart
- **Minimal footprint** - binary compiled from scratch

## Requirements

- Kubernetes 1.20+
- containerd 1.4+
- Linux with cgroups v1/v2 support
- Access to `/sys/fs/cgroup` on nodes

## Installation

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/andurbanovich/numa-scheduler.git
cd numa-scheduler

# Build and install
make build
make generate-binary
./scripts/deploy.sh
```

### Detailed Installation

#### 1. Build Binary

```bash
# Build for all platforms
make build-all

# Or only for current platform
make build
```

#### 2. Generate ConfigMap

```bash
# Generate base64 binary for ConfigMap
make generate-binary
```

#### 3. Install via Helm

```bash
# Install with default settings
helm install numa-scheduler ./deploy/helm --namespace kube-system

# Or using script
./scripts/deploy.sh
```

## Usage

### Pod Configuration

Add the `cpu-set` annotation to your pod to specify CPU affinity:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: numa-aware-pod
  annotations:
    cpu-set: "0-3"  # Bind to CPU 0,1,2,3
spec:
  containers:
  - name: app
    image: nginx:latest
```

### Usage Examples

#### Bind to Specific CPUs

```yaml
annotations:
  cpu-set: "0,2,4"  # CPU 0, 2, 4
```

#### Bind to CPU Range

```yaml
annotations:
  cpu-set: "0-7"    # CPU from 0 to 7
```

#### Combined Configuration

```yaml
annotations:
  cpu-set: "0-3,8-11"  # CPU 0-3 and 8-11
```

## Configuration

### Helm Values

Main configuration parameters:

```yaml
# Use custom image instead of ConfigMap
image:
  useCustomImage: false
  repository: numa-scheduler
  tag: "latest"

# DaemonSet settings
daemonSet:
  updateStrategy:
    type: RollingUpdate
  terminationGracePeriodSeconds: 1

# RBAC
rbac:
  create: true

# containerd configuration
containerd:
  updateConfig: true
  configPath: /etc/containerd/config.toml
  backupConfig: true

# Hook settings
hook:
  binaryPath: /opt/cni/bin/cpuset-hook
  hookType: "createRuntime"
```

### Full Configuration

See [`deploy/helm/values.yaml`](deploy/helm/values.yaml) for all available options.

## Development

### Project Structure

```
.
├── cmd/                    # Main applications
│   └── cpuset-hook/       # OCI hook application
├── internal/              # Internal packages
│   └── cpuset/           # cpuset logic
├── deploy/               # Deployment files
│   └── helm/            # Helm chart
├── scripts/              # Build and deployment scripts
├── idea/                 # Ideas and prototypes
├── Dockerfile           # Dockerfile for image build
├── Makefile            # Makefile for convenient build
└── README.md           # Documentation
```

### Build and Test

```bash
# Install dependencies
make deps

# Build
make build

# Tests
make test

# Build Docker image
make docker-build

# Linting
make lint

# Security check
make sec
```

### Scripts

#### Build

```bash
# Full build
./scripts/build.sh all

# Binary only
./scripts/build.sh binary

# Docker image only
./scripts/build.sh docker
```

#### Deployment

```bash
# Install
./scripts/deploy.sh

# With custom values
./scripts/deploy.sh -f custom-values.yaml

# Upgrade
./scripts/deploy.sh -u

# Uninstall
./scripts/deploy.sh -x

# Dry run
./scripts/deploy.sh -d
```

## OCI Hook Architecture

### Execution Flow

1. **containerd** starts container
2. **OCI hook** is called at `createRuntime` phase
3. **Hook** reads OCI specification from stdin
4. **Extracts** annotations from specification
5. **Determines** container cgroup path
6. **Writes** value to `cpuset.cpus`
7. **Container** starts with configured CPU affinity

### Code

Main logic is located in [`internal/cpuset/hook.go`](internal/cpuset/hook.go):

```go
type Hook struct {
    cgroupMountPrefix string
}

func (h *Hook) Process(spec *specs.Spec) error {
    // Extract annotations
    annotations := spec.Annotations
    
    // Get cpu-set
    cpuSet := annotations["cpu-set"]
    
    // Configure cgroup
    cgroupPath := spec.Linux.CgroupsPath
    fullPath := filepath.Join(h.cgroupMountPrefix, "cpuset", cgroupPath, "cpuset.cpus")
    
    return os.WriteFile(fullPath, []byte(cpuSet), 0644)
}
```

## Troubleshooting

### Check Operation

```bash
# Check DaemonSet status
kubectl get daemonset numa-scheduler -n kube-system

# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=numa-scheduler

# Pod logs
kubectl logs -n kube-system -l app.kubernetes.io/name=numa-scheduler

# Check ConfigMap
kubectl get configmap numa-scheduler-bin -n kube-system -o yaml
```

### Common Issues

#### Hook Not Working

1. **Check permissions** to `/sys/fs/cgroup`
2. **Ensure** containerd is configured to use hooks
3. **Check** that binary has execute permissions

#### Container Not Starting

1. **Check** `cpu-set` annotation format
2. **Ensure** specified CPUs exist on the node
3. **Check** hook logs for diagnostics

#### NUMA Issues

1. **Check** NUMA topology: `numactl --hardware`
2. **Ensure** kernel supports NUMA: `grep NUMA /proc/cpuinfo`
3. **Check** that cgroups support cpuset: `mount | grep cpuset`

## Performance

### Metrics

- **Binary size**: ~2MB (statically linked)
- **Memory**: <1MB
- **CPU**: <1ms per container
- **Latency**: minimal, runs before container start

### Optimization

- **Static compilation** to minimize dependencies
- **Minimal footprint** via scratch Docker image
- **Fast processing** without unnecessary allocations

## Security

### Security Model

- **Requires privileges** to write to cgroup fs
- **Runs** with root privileges on nodes
- **Isolated** in separate container

### Recommendations

- **Restrict** access to ConfigMap with binary
- **Use** RBAC for access control
- **Regularly** update images
- **Monitor** logs for errors

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the project
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## Support

- **Issues**: [GitHub Issues](https://github.com/andurbanovich/numa-scheduler/issues)
- **Discussions**: [GitHub Discussions](https://github.com/andurbanovich/numa-scheduler/discussions)
- **Email**: andrey.urbanovich@example.com

## Roadmap

- [ ] cgroups v2 support
- [ ] CPU affinity validation
- [ ] Metrics and monitoring
- [ ] Automatic NUMA topology detection
- [ ] Support for other runtimes (CRI-O, docker)
- [ ] GUI for management