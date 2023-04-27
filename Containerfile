ARG KERNEL_VERSION
FROM gentoo/portage:latest as portage
FROM gentoo/stage3:latest

# Copy portage volume
# We don't need the full portage tree but emerge misses some
# things otherwise
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo
ADD make.conf /etc/portage/

ARG KERNEL_VERSION

# Build
RUN emerge -qv dev-vcs/git \
               virtual/libelf \
               sys-firmware/intel-microcode \
               sys-kernel/linux-firmware && \
    cd /output/linux && \
    make -j3 && \
    ls -al arch/x86_64/boot && \
    mv arch/x86_64/boot/bzImage /output/bzImage-"${KERNEL_VERSION}" && \
    sha384sum /output/bzImage-"${KERNEL_VERSION}" > /output/bzImage-"${KERNEL_VERSION}".sha384 && \
    ls -al /output
