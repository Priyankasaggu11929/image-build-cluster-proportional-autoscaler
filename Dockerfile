#!UseOBSRepositories

#!BuildTag: rancher/hardened-cluster-autoscaler:v1.9.0
#!BuildTag: rancher/hardened-cluster-autoscaler:latest
#!BuildName: hardened-cluster-autoscaler

# INFO: image-build-base:latest provides the following:
# - required packages (make, musl-gcc, musl-libc-static, etc)
# - set CC, and C_INCLUDE_PATH evironment variables, to enable building with musl libc

ARG GO_IMAGE=rancher/image-build-base:latest

# setup the autoscaler build
FROM base-builder as autoscaler-builder
ARG SRC=github.com/kubernetes-sigs/cluster-proportional-autoscaler
ARG PKG=github.com/kubernetes-sigs/cluster-proportional-autoscaler
ARG TAG=v1.9.0
COPY cluster-proportional-autoscaler ${GOPATH}/src/${PKG}

WORKDIR $GOPATH/src/${PKG}

RUN GOARCH=${ARCH} GO_LDFLAGS="-linkmode=external -X ${PKG}/pkg/version.VERSION=${TAG}" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o . ./...
RUN go-assert-static.sh cluster-proportional-autoscaler
RUN if [ `xx-info arch` = "amd64" ]; then \
    	go-assert-boring.sh cluster-proportional-autoscaler; \
    fi
RUN install cluster-proportional-autoscaler /usr/local/bin

#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
FROM ${GO_IMAGE} as strip_binary
COPY --from=autoscaler-builder /usr/local/bin/cluster-proportional-autoscaler /cluster-proportional-autoscaler
RUN strip /cluster-proportional-autoscaler

FROM scratch as autoscaler
COPY --from=strip_binary /cluster-proportional-autoscaler /cluster-proportional-autoscaler
ENTRYPOINT ["/cluster-proportional-autoscaler"]
