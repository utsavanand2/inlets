FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:1.13-alpine as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

ARG GIT_COMMIT
ARG VERSION

ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOPATH=/go/src/
WORKDIR /go/src/github.com/inlets/inlets

COPY .git               .git
COPY vendor             vendor
COPY go.mod             .
COPY go.sum             .
COPY pkg                pkg
COPY cmd                cmd
COPY main.go            .

RUN test -z "$(gofmt -l $(find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./function/vendor/*"))" || { echo "Run \"gofmt -s -w\" on your Golang code"; exit 1; } \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go test -mod=vendor $(go list ./... | grep -v /vendor/) -cover

# add user in this stage because it cannot be done in next stage which is built from scratch
# in next stage we'll copy user and group information from this stage
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -mod=vendor -ldflags "-s -w -X main.GitCommit=${GIT_COMMIT} -X main.Version=${VERSION}" -a -installsuffix cgo -o /usr/bin/inlets \
    && addgroup -S app \
    && adduser -S -g app app

FROM scratch

ARG REPO_URL

LABEL org.opencontainers.image.source $REPO_URL

COPY --from=builder /etc/passwd /etc/group /etc/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/bin/inlets /usr/bin/

USER app
EXPOSE 80

VOLUME /tmp/

ENTRYPOINT ["/usr/bin/inlets"]
CMD ["--help"]
