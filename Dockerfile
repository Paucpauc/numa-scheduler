# Multi-stage build for minimal container
FROM golang:1.21-alpine AS builder

# Install ca-certificates for SSL/TLS connections
RUN apk add --no-cache ca-certificates git

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o cpuset-hook \
    ./cmd/cpuset-hook

# Final stage: minimal image
FROM scratch

# Import from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/cpuset-hook /cpuset-hook

# Set entrypoint
ENTRYPOINT ["/cpuset-hook"]