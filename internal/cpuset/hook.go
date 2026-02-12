package cpuset

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	specs "github.com/opencontainers/runtime-spec/specs-go"
)

const (
	cgroupMountPrefix = "/sys/fs/cgroup"
)

// Hook implements OCI hook for cpuset configuration
type Hook struct {
	cgroupMountPrefix string
}

// NewHook creates a new Hook instance
func NewHook() *Hook {
	return &Hook{
		cgroupMountPrefix: cgroupMountPrefix,
	}
}

// Process processes OCI specification and configures cpuset
func (h *Hook) Process(spec *specs.Spec) error {
	// Extract pod annotations
	annotations := spec.Annotations
	if annotations == nil {
		return fmt.Errorf("no annotations found")
	}

	// Get required cpuset from "cpu-set" annotation
	cpuSet, ok := annotations["cpu-set"]
	if !ok {
		return fmt.Errorf("annotation 'cpu-set' not found")
	}

	// Determine container cgroup path
	cgroupPath := spec.Linux.CgroupsPath
	if cgroupPath == "" {
		return fmt.Errorf("cgroup path is empty")
	}

	// Form full path to cpuset.cpus
	fullPath := filepath.Join(h.cgroupMountPrefix, "cpuset", cgroupPath, "cpuset.cpus")

	// Write value
	if err := os.WriteFile(fullPath, []byte(cpuSet), 0644); err != nil {
		return fmt.Errorf("failed to write cpuset: %w", err)
	}

	fmt.Printf("Successfully set cpuset %s for container\n", cpuSet)
	return nil
}

// ProcessFromJSON reads OCI specification from JSON and processes it
func (h *Hook) ProcessFromJSON(data []byte) error {
	var spec specs.Spec
	if err := json.Unmarshal(data, &spec); err != nil {
		return fmt.Errorf("failed to decode OCI spec: %w", err)
	}

	return h.Process(&spec)
}
