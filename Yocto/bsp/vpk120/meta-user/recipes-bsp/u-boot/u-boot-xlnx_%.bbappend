# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT
#
# Override the EDF default u-boot bootcmd ("bootmenu -e") so that, like the
# PetaLinux BSP's platform-top.h, the FMC VADJ rail is enabled and then the
# Ethernet FMC Max PHY resets are released before distro_bootcmd. See the
# kconfig fragment in files/ for the rationale. This layer (priority 7) merges
# after meta-amd-edf's own u-boot fragments (priority 5), so our
# CONFIG_BOOTCOMMAND wins.
#
# := captures the bbappend dir at parse time (${THISDIR} is unreliable at task
# time inside a bbappend).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://vpk120-vadj-phyreset-bootcmd.cfg"
