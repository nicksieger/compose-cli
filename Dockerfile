# syntax = docker/dockerfile:experimental
ARG GO_VERSION=1.14.2

FROM golang:${GO_VERSION} AS fs
ARG TARGET_OS=unknown
ARG TARGET_ARCH=unknown
ARG PWD=/api
ENV GO111MODULE=on

RUN apt-get update && apt-get install --no-install-recommends -y \
    make \
    git \
    protobuf-compiler \
    libprotobuf-dev

RUN go get github.com/golang/protobuf/protoc-gen-go@v1.4.1 && \
    go get golang.org/x/tools/cmd/goimports && \
    go get gotest.tools/gotestsum@v0.4.2 && \
    go get github.com/golangci/golangci-lint/cmd/golangci-lint@v1.26.0

WORKDIR ${PWD}
ADD go.* ${PWD}
RUN go mod download
ADD . ${PWD}

FROM fs AS make-protos
RUN make -f builder.Makefile protos

FROM fs AS make-cli
RUN --mount=type=cache,target=/root/.cache/go-build \
    GOOS=${TARGET_OS} \
    GOARCH=${TARGET_ARCH} \
    make -f  builder.Makefile cli

FROM fs AS make-cross
RUN --mount=type=cache,target=/root/.cache/go-build \
    make -f builder.Makefile cross

FROM scratch AS protos
COPY --from=make-protos /api .

FROM scratch AS cli
COPY --from=make-cli /api/bin/* .

FROM scratch AS cross
COPY --from=make-cross /api/bin/* .

FROM make-protos as test
RUN make -f builder.Makefile test

FROM fs AS lint
RUN make -f builder.Makefile lint