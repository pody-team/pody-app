FROM golang:1.26-alpine AS build

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /bin/content-service ./cmd/content

FROM alpine:3.22

RUN apk add --no-cache ca-certificates wget

COPY --from=build /bin/content-service /usr/local/bin/content-service

EXPOSE 8082

ENTRYPOINT ["/usr/local/bin/content-service"]
