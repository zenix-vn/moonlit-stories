# Build stage
FROM golang:alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o api cmd/api/main.go

# Run stage
FROM alpine:latest
WORKDIR /app
RUN apk --no-cache add ca-certificates tzdata && mkdir -p /app/uploads
COPY --from=builder /app/api .
COPY --from=builder /app/migrations ./migrations
EXPOSE 8088
CMD ["./api"]
