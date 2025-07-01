
FROM golang:1.24.4 AS builder
ARG KUMA_VERSION=2.11.0
ARG TARGETOS
ARG TARGETARCH

RUN apt-get update && apt-get install -y unzip
WORKDIR /app
RUN curl -L -o kuma-source.zip https://github.com/kumahq/kuma/archive/refs/tags/${KUMA_VERSION}.zip && unzip kuma-source.zip && rm kuma-source.zip
WORKDIR /app/kuma-${KUMA_VERSION}
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /app/testserver test/server/main.go


FROM gcr.io/distroless/static-debian12:debug-nonroot@sha256:edbeb7a4e79938116dc9cb672b231792e0b5ac86c56fb49781a79e54f3842c67
COPY --from=builder /app/testserver /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/testserver"]


# docker buildx build \
# --platform linux/arm64,linux/amd64 \
# --build-arg "KUMA_VERSION=${KUMA_VERSION}" \
# --tag jijiechen/testserver:kuma-${KUMA_VERSION} \
# --push .

