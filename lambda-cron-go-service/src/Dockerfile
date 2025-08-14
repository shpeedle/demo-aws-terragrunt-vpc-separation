# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bootstrap .

# Runtime stage
FROM public.ecr.aws/lambda/provided:al2

# Copy the binary from builder stage as bootstrap
COPY --from=builder /app/bootstrap ${LAMBDA_RUNTIME_DIR}

# Set the CMD to your handler
CMD ["bootstrap"]
