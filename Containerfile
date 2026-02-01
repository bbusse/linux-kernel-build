ARG KERNEL_VERSION
ARG KERNEL_REPO="https://github.com/torvalds/linux"
ARG KERNEL_CONFIG="kernel-config-rockpro64"
ARG KERNEL_CONFIG_REPO="https://github.com/bbusse/linux-kernel-config"
FROM gentoo/portage:latest as portage
FROM gentoo/stage3:systemd as build-deps

# Copy portage volume
# We don't need the full portage tree but emerge misses some
# things otherwise
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo
ADD make.conf /etc/portage/
Add package.accept_keywords /etc/portage/
Add package.unmask /etc/portage/

ARG KERNEL_VERSION
ARG KERNEL_REPO
ARG KERNEL_CONFIG
ARG KERNEL_CONFIG_REPO

# Build
RUN emerge -qv dev-vcs/git \
               virtual/libelf \
               # emerge fails on non-intel systems
               #sys-firmware/intel-microcode \
               sys-kernel/linux-firmware && \
               mkdir -p /usr/src && \
               cd /usr/src &&\
               git clone --depth 1 ${KERNEL_REPO}

FROM build-deps as builder
ARG KERNEL_VERSION
ARG KERNEL_CONFIG
ENV KERNEL_VERSION=${KERNEL_VERSION}
WORKDIR /usr/src/linux
RUN git pull && \
    git clone --depth 1 ${KERNEL_CONFIG_REPO} /usr/src/linux-kernel-config && \
    cp /usr/src/linux-kernel-config/${KERNEL_CONFIG} .config && \
    make -j3

RUN mv arch/arm64/boot/Image Image-"${KERNEL_CONFIG}" && \
    #mv arch/x86_64/boot/bzImage /output/bzImage-"${KERNEL_VERSION}" && \
    sha384sum Image-"${KERNEL_CONFIG}" > Image-"${KERNEL_CONFIG}".sha384
    #sha384sum bzImage-"${KERNEL_VERSION}" > /output/bzImage-"${KERNEL_VERSION}".sha384

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
