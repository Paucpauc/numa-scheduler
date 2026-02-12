# Variables
BINARY_NAME=cpuset-hook
DOCKER_IMAGE_NAME=numa-scheduler
DOCKER_TAG?=latest
VERSION?=$(shell git describe --tags --always --dirty)
LDFLAGS=-ldflags "-X main.version=$(VERSION)"

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

.PHONY: all build clean test coverage deps docker-build docker-push helm-package help

all: build

# Build the binary
build:
	$(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME) -v ./cmd/cpuset-hook

# Clean build artifacts
clean:
	$(GOCLEAN)
	rm -f bin/$(BINARY_NAME)
	rm -rf dist/

# Run tests
test:
	$(GOTEST) -v ./...

# Run tests with coverage
coverage:
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

# Download dependencies
deps:
	$(GOMOD) download
	$(GOMOD) tidy

# Build Docker image
docker-build:
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) .
	docker tag $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) $(DOCKER_IMAGE_NAME):$(VERSION)

# Push Docker image
docker-push:
	docker push $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)
	docker push $(DOCKER_IMAGE_NAME):$(VERSION)

# Build binary for multiple platforms
build-all:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-amd64 ./cmd/cpuset-hook
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-arm64 ./cmd/cpuset-hook

# Package Helm chart
helm-package:
	cd deploy/helm && helm package .

# Install Helm chart locally
helm-install:
	helm upgrade --install numa-scheduler ./deploy/helm --namespace kube-system --create-namespace

# Uninstall Helm chart
helm-uninstall:
	helm uninstall numa-scheduler --namespace kube-system

# Generate binary for ConfigMap
generate-binary: build
	@echo "Generating base64 binary for ConfigMap..."
	@base64 bin/$(BINARY_NAME) | tr -d '\n' > deploy/helm/templates/_binary.txt
	@echo "Binary encoded in deploy/helm/templates/_binary.txt"
	@echo "Updating values-binary.yaml..."
	@sed -i.bak 's/content: "{{ placeholder }}"/content: "'$$$(cat deploy/helm/templates/_binary.txt)'"/' deploy/helm/values-binary.yaml
	@rm -f deploy/helm/values-binary.yaml.bak
	@echo "values-binary.yaml updated with binary content"

# Format code
fmt:
	$(GOCMD) fmt ./...

# Run linter
lint:
	golangci-lint run

# Run security check
sec:
	gosec ./...

# Help target
help:
	@echo "Available targets:"
	@echo "  build          - Build the binary"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run tests"
	@echo "  coverage       - Run tests with coverage"
	@echo "  deps           - Download dependencies"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-push    - Push Docker image"
	@echo "  build-all      - Build binary for multiple platforms"
	@echo "  helm-package   - Package Helm chart"
	@echo "  helm-install   - Install Helm chart locally"
	@echo "  helm-uninstall - Uninstall Helm chart"
	@echo "  generate-binary - Generate base64 binary for ConfigMap"
	@echo "  fmt            - Format code"
	@echo "  lint           - Run linter"
	@echo "  sec            - Run security check"
	@echo "  help           - Show this help message"