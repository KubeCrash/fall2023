# Prepare
FROM golang:1.19.13-alpine3.18 as build
WORKDIR /go/src
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o app server.go

# Package
FROM alpine:3.18.3
COPY --from=build /go/src/app /
COPY --from=build /go/src/ui /ui
ENTRYPOINT ["/app"]