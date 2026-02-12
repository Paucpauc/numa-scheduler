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

// Hook реализует OCI hook для настройки cpuset
type Hook struct {
	cgroupMountPrefix string
}

// NewHook создает новый экземпляр Hook
func NewHook() *Hook {
	return &Hook{
		cgroupMountPrefix: cgroupMountPrefix,
	}
}

// Process обрабатывает OCI спецификацию и настраивает cpuset
func (h *Hook) Process(spec *specs.Spec) error {
	// Извлекаем аннотации пода
	annotations := spec.Annotations
	if annotations == nil {
		return fmt.Errorf("no annotations found")
	}

	// Получаем требуемый cpuset из аннотации "cpu-set"
	cpuSet, ok := annotations["cpu-set"]
	if !ok {
		return fmt.Errorf("annotation 'cpu-set' not found")
	}

	// Определяем путь к cgroup контейнера
	cgroupPath := spec.Linux.CgroupsPath
	if cgroupPath == "" {
		return fmt.Errorf("cgroup path is empty")
	}

	// Формируем полный путь к cpuset.cpus
	fullPath := filepath.Join(h.cgroupMountPrefix, "cpuset", cgroupPath, "cpuset.cpus")

	// Записываем значение
	if err := os.WriteFile(fullPath, []byte(cpuSet), 0644); err != nil {
		return fmt.Errorf("failed to write cpuset: %w", err)
	}

	fmt.Printf("Successfully set cpuset %s for container\n", cpuSet)
	return nil
}

// ProcessFromJSON читает OCI спецификацию из JSON и обрабатывает ее
func (h *Hook) ProcessFromJSON(data []byte) error {
	var spec specs.Spec
	if err := json.Unmarshal(data, &spec); err != nil {
		return fmt.Errorf("failed to decode OCI spec: %w", err)
	}

	return h.Process(&spec)
}
