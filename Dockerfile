FROM gentoo/portage:latest as portage
FROM gentoo/stage3:latest

# Copy portage volume
# We don't need the full portage tree but emerge misses some
# things otherwise
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo
ADD make.conf /etc/portage/

# Build
RUN emerge -qv dev-vcs/git \
               virtual/libelf \
               sys-firmware/intel-microcode \
               sys-kernel/linux-firmware && \
    cd /output/linux && \
    mv /config .config && \
    make -j3 && \
    kernel_version=$(make kernelversion) && \
    mv arch/x86_64/boot/bzImage "/output/bzImage-${kernel_version}" && \
    sha384sum "/output/bzImage-${kernel_version}" > "/output/bzImage-${kernel_version}.sha384"
