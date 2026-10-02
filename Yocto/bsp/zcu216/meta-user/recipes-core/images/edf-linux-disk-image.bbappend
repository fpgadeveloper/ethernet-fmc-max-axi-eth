# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# Ethernet FMC Max AXI Ethernet reference-design rootfs packages (ported from the PetaLinux
# bsp rootfs_config: design test/utility tools layered on the amd-edf base).
IMAGE_INSTALL:append = " \
    ethtool \
    iperf3 \
    phytool \
    mtd-utils \
    can-utils \
    nfs-utils \
    pciutils \
"
