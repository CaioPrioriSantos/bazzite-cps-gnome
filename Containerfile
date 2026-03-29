FROM scratch AS ctx
COPY build_files /

ARG KERNEL_FLAVOR=bazzite

FROM ghcr.io/ublue-os/bazzite-gnome:stable

ARG KERNEL_FLAVOR=bazzite
ENV KERNEL_FLAVOR=${KERNEL_FLAVOR}

### MODIFICATIONS
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
RUN bootc container lint
