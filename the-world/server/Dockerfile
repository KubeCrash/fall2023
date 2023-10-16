# Prepare
FROM golang:1.19.13-alpine3.18 as build
WORKDIR /go/src
COPY . .

# Build
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -o world server.go

# Package
FROM alpine:3.18.3
RUN mkdir /world
COPY --from=build /go/src/world /world
COPY --from=build /go/src/ui /world/ui
WORKDIR /world
ENTRYPOINT ["/world/world"]