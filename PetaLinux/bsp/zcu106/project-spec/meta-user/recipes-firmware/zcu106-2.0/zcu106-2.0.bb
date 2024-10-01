#
# This file is the zcu106-2.0 recipe.
#

SUMMARY = "Simple zcu106-2.0 to use dfx_dtg_zynqmp_full class"
SECTION = "PETALINUX/apps"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit dfx_dtg_zynqmp_full

COMPATIBLE_MACHINE:zynqmp = ".*"


SRC_URI = "file://project_2.xsa \
	file://shell.json"
