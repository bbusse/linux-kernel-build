ARG KERNEL_VERSION
ARG KERNEL_REPO="https://github.com/torvalds/linux"
ARG KERNEL_CONFIG="kernel-config-rockpro64"
ARG KERNEL_CONFIG_REPO="https://github.com/bbusse/linux-kernel-config"
FROM gentoo/portage:latest AS portage
FROM gentoo/stage3:systemd AS build-deps

# Copy portage tree
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo
ADD make.conf /etc/portage/
Add package.accept_keywords /etc/portage/
Add package.unmask /etc/portage/

ARG KERNEL_VERSION
ARG KERNEL_REPO
ARG KERNEL_CONFIG
ARG KERNEL_CONFIG_REPO

SHELL ["/bin/bash", "-c"]

# emerge build dependencies
# /dev/ptmx removed so pty allocation fails outright (ENOENT) and
# portage falls back to its pipe path, instead of partially succeeding
# then hitting an unhandled ENOSYS from termios under qemu-user (arm64
# builds on an x86 host). /dev is remounted fresh per RUN, so this has
# to happen in the same RUN as emerge, not a separate prior step.
# Combined with FEATURES=-pid-sandbox etc in make.conf (the documented
# fix for qemu-user chroots) since pid-sandbox is the likely cause of
# a previous indefinite hang here - wrapped in timeout as a backstop
# in case something still hangs, so it fails in 20m instead of hours.
RUN rm -f /dev/ptmx; \
    EXTRA_PKGS=""; \
    if [ "${KERNEL_CONFIG}" = "kernel-config-x230" ]; then \
        EXTRA_PKGS="sys-firmware/intel-microcode"; \
    fi; \
    timeout 20m emerge -qv sys-libs/binutils-libs \
               dev-vcs/git \
               virtual/libelf \
               sys-devel/bc \
               sys-kernel/linux-firmware \
               ${EXTRA_PKGS} 2>&1 | cat; \
               exit ${PIPESTATUS[0]}
RUN mkdir -p /usr/src && \
    cd /usr/src && \
    git clone --depth 1 ${KERNEL_REPO}

FROM build-deps AS builder
ARG KERNEL_VERSION
ARG KERNEL_CONFIG
ARG KERNEL_CONFIG_REPO
ENV KERNEL_VERSION=${KERNEL_VERSION}
WORKDIR /usr/src/linux

# Get configs, build kernel, create checksum
RUN git pull && \
    git clone --depth 1 ${KERNEL_CONFIG_REPO} /usr/src/linux-kernel-config && \
    cp /usr/src/linux-kernel-config/${KERNEL_CONFIG} .config && \
    make -j3 && \
    KERNEL_FLAVOUR="${KERNEL_CONFIG#kernel-config-}" && \
    if [ "x230" = "${KERNEL_FLAVOUR}" ]; then \
        KERNEL_IMAGE_SRC="arch/x86/boot/bzImage"; \
        KERNEL_IMAGE_OUT="bzImage-${KERNEL_FLAVOUR}"; \
    else \
        KERNEL_IMAGE_SRC="arch/arm64/boot/Image"; \
        KERNEL_IMAGE_OUT="Image-${KERNEL_FLAVOUR}"; \
    fi && \
    mv "${KERNEL_IMAGE_SRC}" "${KERNEL_IMAGE_OUT}" && \
    sha384sum "${KERNEL_IMAGE_OUT}" > "${KERNEL_IMAGE_OUT}.sha384"

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
