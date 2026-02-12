package main

import (
	"fmt"
	"io"
	"os"

	"github.com/andurbanovich/numa-scheduler/internal/cpuset"
)

func main() {
	// Читаем OCI-спецификацию из stdin
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read from stdin: %v\n", err)
		os.Exit(1)
	}

	// Создаем и настраиваем hook
	hook := cpuset.NewHook()

	// Обрабатываем спецификацию
	if err := hook.ProcessFromJSON(data); err != nil {
		fmt.Fprintf(os.Stderr, "hook processing failed: %v\n", err)
		os.Exit(1)
	}
}
