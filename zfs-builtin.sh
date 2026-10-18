#!/bin/sh
#
# SPDX-FileCopyrightText: Björn Busse <bj.rn@baerlin.eu>
# SPDX-License-Identifier: BSD-3-Clause
#
# Build OpenZFS into the kernel: zfs-builtin.sh <kernel tree> <zfs tree>
#
# OpenZFS's configure probes the kernel API by compiling test modules, which
# a config without CONFIG_MODULES refuses. The probe runs against a copy of
# the config with modules on, the build against the real one plus CONFIG_ZFS

set -eu

linux="${1}"
zfs="${2}"

cd "${linux}"
cp .config .config.zfs-builtin
./scripts/config --enable MODULES
make olddefconfig
make modules_prepare

cd "${zfs}"
./autogen.sh
./configure \
    --with-config=kernel \
    --enable-linux-builtin \
    --enable-linux-experimental \
    --with-linux="${linux}" \
    --with-linux-obj="${linux}"
./copy-builtin "${linux}"

cd "${linux}"
mv .config.zfs-builtin .config
./scripts/config --enable ZFS
make olddefconfig

if ! grep -qx 'CONFIG_ZFS=y' .config; then
    echo "zfs-builtin: CONFIG_ZFS=y did not survive olddefconfig" >&2
    grep -E '^(# )?CONFIG_(ZFS|EFI_PARTITION|BLOCK)[= ]' .config >&2 || true
    exit 1
fi
