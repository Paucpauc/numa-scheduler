package main

import (
	"fmt"
	"io"
	"os"

	"github.com/paucpauc/numa-scheduler/internal/cpuset"
)

func main() {
	// Read OCI specification from stdin
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read from stdin: %v\n", err)
		os.Exit(1)
	}

	// Create and configure hook
	hook := cpuset.NewHook()

	// Process specification
	if err := hook.ProcessFromJSON(data); err != nil {
		fmt.Fprintf(os.Stderr, "hook processing failed: %v\n", err)
		os.Exit(1)
	}
}
