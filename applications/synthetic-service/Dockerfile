FROM --platform=$BUILDPLATFORM golang:1.26 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /out/synthetic-service ./cmd/synthetic-service

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /out/synthetic-service /synthetic-service
EXPOSE 8080
ENTRYPOINT ["/synthetic-service"]
