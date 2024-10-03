# Updating the projects

This section contains instructions for updating the reference designs. It is intended as a guide
for anyone wanting to attempt updating the designs for a tools release that we do not yet support.
Note that the update process is not always straight-forward and sometimes requires dealing with
new issues or significant changes to the functionality of the tools and/or specific IP. Unfortunately, 
we cannot always provide support if you have trouble updating the designs.

## Vivado projects

1. Download and install the Vivado release that you intend to use.
2. In a text editor, open the `Vivado/scripts/build.tcl` file and perform the following changes:
   * Update the `version_required` variable value to the tools version number 
     that you are using.
   * Update the year in all references to `Vivado Synthesis <year>` to the 
     tools version number that you are using. For example, if you are using tools
     version 2024.1, then the `<year>` should be 2024.
   * Update the year in all references to `Vivado Implementation <year>` to the 
     tools version number that you are using. For example, if you are using tools
     version 2024.1, then the `<year>` should be 2024.
3. In a text editor, open the `Vivado/scripts/xsa.tcl` file and perform the following changes:
   * Update the `version_required` variable value to the tools version number 
     that you are using.
4. **Windows users only:** In a text editor, open the `Vivado/build-vivado.bat` file and update 
   the tools version number to the one you are using (eg. 2024.1).

After completing the above, you should now be able to use the [build instructions](build_instructions) to
build the Vivado project. If there were no significant changes to the tools and/or IP, the build script 
should succeed and you will be able to open and generate a bitstream.

## PetaLinux

The main procedure for updating the PetaLinux project is to update the BSP for the target platform.
The BSP files for each supported target platform are contained in the `PetaLinux/bsp` directory.

1. Download and install the PetaLinux release that you intend to use.
2. Download and install the BSP for the target platform for the release that you intend to use.

   * For all Xilinx evaluation boards, download the BSP from the [Xilinx downloads] page
   * For UltraZed-EV download the BSP from the [Avnet downloads] page

3. Update the BSP files for the target platform in the `PetaLinux/bsp/<platform>` directory. 
   These are the specific directories to update:
   * `<platform>/project-spec/configs/*`
   * `<platform>/project-spec/meta-user/*`   
   The simple way to update the files is to delete the `configs` and `meta-user` folders from the repository
   and copy in those folders from the more recent BSP.
4. Apply the required modifications to the updated BSP files. The modifications are described for each
   target platform in the following sections.
   
### Change project name

This BSP modification applies to all target platforms.

1. Append the following lines to `project-spec/configs/config`:

```
# Set project name
CONFIG_SUBSYSTEM_HOSTNAME="axieth"
CONFIG_SUBSYSTEM_PRODUCT="axieth"
```
   
Note that this will set the project name to "axieth" but you can use a more descriptive name, for example
one that includes the target platform name and the tools version.

### Add tools to root filesystem

This BSP modification applies to all target platforms.

1. Append the following lines to `project-spec/configs/rootfs_config`:

```
# Useful tools for Ethernet FMC Max
CONFIG_ethtool=y
CONFIG_iperf3=y
CONFIG_phytool=y
```

2. Append the following lines to `project-spec/meta-user/conf/user-rootfsconfig`:

```
CONFIG_iperf3
CONFIG_ethtool
CONFIG_phytool
```

### Include port config in device tree

This BSP modification applies to all target platforms.

1. Append the following line after `/include/ "system-conf.dtsi"` in 
   `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`:

```
/include/ "port-config.dtsi"
```

2. Append the following line after `SRC_URI:append = " file://system-user.dtsi"` in 
   `project-spec/meta-user/recipes-bsp/device-tree/device-tree.bbappend`:

```
SRC_URI:append = " file://port-config.dtsi"
```

### Add kernel configs

This BSP modification applies to all target platforms.

1. Append the following lines to file `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`:

```
# Required by all designs
CONFIG_AMD_PHY=y
CONFIG_XILINX_PHY=y
```

### Mods for all ZynqMP designs

These BSP modifications must be applied to all ZynqMP designs (MPSoC and RFSoC) in addition to 
the previous one.

1. Append the following lines to `project-spec/configs/config`. These options configure the design
   to use the SD card to store the root filesystem.

```
# SD card for root filesystem

CONFIG_SUBSYSTEM_BOOTARGS_AUTO=n
CONFIG_SUBSYSTEM_USER_CMDLINE="earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait cma=1536M"

CONFIG_SUBSYSTEM_ROOTFS_INITRD=n
CONFIG_SUBSYSTEM_ROOTFS_EXT4=y
CONFIG_SUBSYSTEM_SDROOT_DEV="/dev/mmcblk0p2"
CONFIG_SUBSYSTEM_RFS_FORMATS="tar.gz ext4 ext4.gz "
```

2. Append the following lines to `project-spec/configs/rootfs_config`:

```
# Add extra tools for debugging Ethernet with ethtool

CONFIG_ethtool-dev=y
CONFIG_ethtool-dbg=y
```

3. Add the following lines to the top of file `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`:

```
# All zynqMP designs need these kernel configs for AXI Ethernet designs
CONFIG_XILINX_DMA_ENGINES=y
CONFIG_XILINX_DPDMA=y
CONFIG_XILINX_ZYNQMP_DMA=y
```

### Mods for UltraZed-EV Carrier

These modifications are specific to the UltraZed-EV BSP.

1. Append the following lines to `project-spec/configs/config`.

```
# UZ-EV configs

CONFIG_YOCTO_MACHINE_NAME="zynqmp-generic"
CONFIG_USER_LAYER_0=""
CONFIG_SUBSYSTEM_SDROOT_DEV="/dev/mmcblk1p2"
CONFIG_SUBSYSTEM_USER_CMDLINE=" earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk1p2 rw rootwait cma=1000M"
CONFIG_SUBSYSTEM_PRIMARY_SD_PSU_SD_0_SELECT=n
CONFIG_SUBSYSTEM_PRIMARY_SD_PSU_SD_1_SELECT=y
CONFIG_SUBSYSTEM_SD_PSU_SD_0_SELECT=n
```

2. Overwrite the device tree file 
   `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi` with the one that is in the
   repository.


[Xilinx downloads]: https://www.xilinx.com/support/download.html
[Avnet downloads]: https://avnet.me/zedsupport

