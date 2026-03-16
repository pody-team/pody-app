FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/identity-service ./cmd/identity

FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/identity-service /usr/local/bin/identity-service

EXPOSE 8081

ENTRYPOINT ["/usr/local/bin/identity-service"]
