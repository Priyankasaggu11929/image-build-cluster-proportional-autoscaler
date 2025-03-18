#!UseOBSRepositories

#!BuildTag: rancher/image-build-cluster-proportional-autoscaler:v1.9.0
#!BuildTag: rancher/image-build-cluster-proportional-autoscaler:latest
#!BuildName: image-build-cluster-proportional-autoscaler

ARG GO_IMAGE=rancher/image-build-base:latest

FROM  ${GO_IMAGE} as base-builder
RUN set -euo pipefail; \
    zypper -n install --no-recommends \
    # file \
    # gcc \
    # git \
    # clang \
    # lld \
    # glibc \
    # glibc-devel-static \    
    musl-gcc \
    musl-libc-static \
    make; \
    zypper -n clean; \
    rm -rf {/target,}/var/log/{alternatives.log,lastlog,tallylog,zypper.log,zypp/history,YaST2}

# setup the autoscaler build
FROM base-builder as autoscaler-builder
ARG SRC=github.com/kubernetes-sigs/cluster-proportional-autoscaler
ARG PKG=github.com/kubernetes-sigs/cluster-proportional-autoscaler
ARG TAG=v1.9.0
ENV C_INCLUDE_PATH="/usr/x86_64-linux-musl/include/:/usr/include/"
ENV CC="musl-gcc"

COPY cluster-proportional-autoscaler ${GOPATH}/src/${PKG}

WORKDIR $GOPATH/src/${PKG}

RUN GOARCH=${ARCH} GO_LDFLAGS="-linkmode=external -X ${PKG}/pkg/version.VERSION=${TAG}" \
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -mod=vendor -buildvcs=false -o . ./...
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
