# Yocto

The Yocto flow uses AMD's Embedded Development Framework (EDF), the announced successor to
PetaLinux. It builds a Linux image for the reference design with the cross-platform `build.py`
runner at the root of the repository, and the image exercises the AXI Ethernet ports in the same
way as the PetaLinux image.

```{note}
For 2025.2 both the PetaLinux and Yocto flows are supported. From the next tool version
onward, the PetaLinux flow for this repository will be retired and Yocto will be the only
supported Linux flow.
```

The Yocto flow is supported for the Zynq UltraScale+ and Versal targets (the same set that has
PetaLinux support). The MicroBlaze targets (AUBoard, KCU105, VCU118) are standalone-only.

## Requirements

* A physical or virtual machine running one of the [supported Linux distributions].
  The Yocto build cannot run on Windows (or WSL); Windows users can build the Vivado and
  standalone parts on Windows and the Yocto image on a Linux machine.
* Vivado 2025.2 and Vitis 2025.2. The flow uses `sdtgen` (part of Vitis) to generate a System
  Device Tree from the Vivado XSA. The runner finds and sources the tools itself.
* [Google's repo tool](https://gerrit.googlesource.com/git-repo/) on your `PATH`; it fetches the
  EDF layers.
* Disk space and time: a fresh Yocto workspace for one target needs tens of GB, and the first
  build downloads several GB of sources and builds from scratch, which can take several hours. Subsequent builds are incremental.
* A licence for the Vivado bitstream: see [Requirements](requirements) (TEMAC IP licence, and
  the Vivado Enterprise edition for most boards).
* To run the design: the [Ethernet FMC Max], your target board, an SD card of 16 GB or larger (the disk image is 8 GiB, which does not fit on a nominal 8 GB card),
  a USB cable for the board's USB-UART, Ethernet cables and a PC.

## Build

1. Clone the repository (with its submodules) and change into it:
   ```
   git clone --recurse-submodules https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth.git
   cd ethernet-fmc-max-axi-eth
   ```
2. Build the Yocto image for your target, replacing `<target>` with a target label from the
   [build instructions](build_instructions.md#target-designs) (for example `zcu106_hpc0` or
   `vck190_fmcp1`):
   ```
   ./build.sh yocto --target <target>
   ```
   This first builds the Vivado project and XSA if they don't exist yet.
3. Optionally gather the boot files into a zip:
   ```
   ./build.sh package --target <target>
   ```

Valid targets for Yocto are:
{% for design in data.designs if design.yocto and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

`./build.sh all --target <target>` builds everything the target supports (XSA, standalone
application, PetaLinux and Yocto) and packages it. `./build.sh status --target <target>` shows
which stages are built.

### Offline builds

To build without fetching from the AMD sstate mirror, extract the AMD sstate-cache and downloads
archives to one directory and write that absolute path (one line, no trailing slash) into
`Yocto/offline.txt`.

### Output files

The images are gathered into `Yocto/<target>/images/linux/`:

| File | Description |
| --- | --- |
| `rootfs.wic.xz` | Full SD-card disk image (compressed) — this is what you write to the card |
| `rootfs.wic.bmap` | Block map for `bmaptool` (fast writing) |
| `BOOT.BIN` | Boot image (FSBL/PMU firmware or PLM, bitstream/PDI, ATF, U-Boot) |
| `boot.scr` | U-Boot boot script (Zynq UltraScale+ only) |
| `Image` | Linux kernel |
| `system.dtb` | Linux device tree |
| `rootfs.tar.gz` | Root filesystem tarball |

`./build.sh package` writes `bootimages/ethernet-fmc-max-axi-eth_<target>_yocto-2025-2.zip`
containing `rootfs.wic.xz`, `rootfs.wic.bmap`, `BOOT.BIN`, a `readme.txt` with the SD-card
steps and, for Versal targets, `BOOTAA64.EFI` (the systemd-boot EFI loader, see below).

## Prepare the SD card

The Yocto flow produces a **complete SD-card disk image**: you write `rootfs.wic.xz` to the raw
card device, then copy `BOOT.BIN` (and on Versal also `BOOTAA64.EFI`) onto the card's first
partition. The commands below are for a Linux PC.

```{warning}
Writing to a raw block device cannot be undone. Make absolutely sure you have identified the
SD card's device node before running the commands below — if you use the wrong device you can
destroy the data on one of your hard drives.
```

1. **Identify the SD card.** With the card *unplugged*, run `lsblk -o NAME,SIZE,RM,TYPE`;
   insert the card and run it again. The new entry — typically `/dev/sdX`, with `RM=1` and the
   size of your card — is the card. Replace `sdX` below with that device and `<target>` with
   your target label.
2. **Unmount** any partitions that the desktop mounted automatically:
   ```
   for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
   ```
3. **Write the image** to the raw device. With `bmaptool` (fast, writes only used blocks):
   ```
   sudo bmaptool copy --bmap Yocto/<target>/images/linux/rootfs.wic.bmap \
                            Yocto/<target>/images/linux/rootfs.wic.xz \
                            /dev/sdX
   ```
   or, without `bmaptool`:
   ```
   xzcat Yocto/<target>/images/linux/rootfs.wic.xz \
       | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
4. **Copy `BOOT.BIN` onto the first partition.** The image's first partition (`esp`, FAT32) is
   where the boot ROM looks for `BOOT.BIN`, but the EDF image does not put it there, so the card
   does not boot until you copy it:
   ```
   sudo partprobe /dev/sdX
   sudo mkdir -p /mnt/sd_esp
   sudo mount /dev/sdX1 /mnt/sd_esp
   sudo cp Yocto/<target>/images/linux/BOOT.BIN /mnt/sd_esp/
   ```
5. **Versal targets only: install the systemd-boot loader.** On Versal, U-Boot starts Linux
   through systemd-boot (an EFI application), but the image ships an empty `EFI/BOOT/` folder.
   Copy `BOOTAA64.EFI` from the `bootimages` zip, or extract it from the root filesystem tarball:
   ```
   tar -xzf Yocto/<target>/images/linux/rootfs.tar.gz -O \
       ./usr/lib/systemd/boot/efi/systemd-bootaa64.efi > BOOTAA64.EFI
   sudo mkdir -p /mnt/sd_esp/EFI/BOOT
   sudo cp BOOTAA64.EFI /mnt/sd_esp/EFI/BOOT/BOOTAA64.EFI
   ```
   Without it, the board stops at the U-Boot prompt.
6. Unmount and eject the card so that all writes are flushed:
   ```
   sync
   sudo umount /mnt/sd_esp && sudo rmdir /mnt/sd_esp
   sudo eject /dev/sdX
   ```

On Windows, you can write `rootfs.wic.xz` with a tool such as balenaEtcher and then copy
`BOOT.BIN` (and `BOOTAA64.EFI` into `EFI\BOOT\` on Versal) onto the small FAT partition that
Windows shows.

## Boot

1. Fit the [Ethernet FMC Max] on the FMC connector named by your target (for example `HPC0` for
   `zcu106_hpc0`, `FMCP1` for `vck190_fmcp1`); see the target tables in the
   [build instructions](build_instructions.md#target-designs).
2. Insert the SD card and set the board to boot from SD card. The boot-mode switch settings are
   the same as for PetaLinux; see [Boot PetaLinux](petalinux.md#boot-petalinux) and the board's
   user guide.
3. Connect the board's USB-UART to the PC and open a terminal at 115200 baud, 8N1 (see
   [UART terminal](petalinux.md#uart-terminal)). On boards with several UART channels the
   Linux console is the first one (for example the first of the four `ttyUSB` ports of a ZCU10x).
4. Connect Ethernet cables to the FMC ports you want to test (and, optionally, to the board's
   own RJ45).
5. Power on the board.

A boot from SD card looks like this (ZCU106, `zcu106_hpc0`, abridged):

```
U-Boot 2025.01 ...
Model: Xilinx ZynqMP
DRAM:  2 GiB (effective 4 GiB)
...
Hit any key to stop autoboot:  2  1  0
Scanning mmc 0:2...
Found U-Boot script /boot.scr
...
EFI stub: Booting Linux Kernel...
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Kernel command line: earlycon console=ttyPS0,115200 clk_ignore_unused init_fatal_sh=1 root=/dev/mmcblk0p3 ro rootwait uio_pdrv_genirq.of_id=generic-uio cma=1536M
...
[    2.867807] systemd[1]: Hostname set to <zcu106-axieth-2025-2>.
...
[    5.807324] xilinx_axienet a0000000.ethernet end3: renamed from eth1
...
AMD Embedded Development Framework Linux distribution 25.11.1+release-... zcu106-axieth-2025-2 ttyPS0

zcu106-axieth-2025-2 login:
```

Things to check in the boot log:

* the kernel command line ends with the design's arguments (`cma=1536M` on most targets,
  `cma=1000M` on the UltraZed-EV; on Versal `clk_ignore_unused cma=1536M`);
* the hostname is `<board>-axieth-2025-2` (for example `zcu104-axieth-2025-2`,
  `vck190-axieth-2025-2`);
* one `xilinx_axienet` interface per FMC port of the target (four, or one on the ZCU104).

## Log in

Log in on the UART console as **`amd-edf`**. On first login the image requires you to choose a
new password:

```
zcu106-axieth-2025-2 login: amd-edf
You are required to change your password immediately (administrator enforced).
New password:
Retype new password:
...
zcu106-axieth-2025-2:~$
```

The `amd-edf` user can run administrative commands with `sudo` (it asks for the same password).
The image runs an OpenSSH server, so once a port has an IP address you can also log in over the
network: `ssh amd-edf@<board-ip>`.

## Use and test the ports

All Ethernet interfaces request an address by DHCP as soon as they have a link. Check what came
up:

```
ip -br addr
sudo ethtool end3 | grep -E 'Speed|Link detected'
```

Then follow [Using and testing the ports in Linux](linux_testing), which covers identifying
which `endN` is which FMC port, static IP addresses, `ethtool`/`phytool`, speed negotiation and
iperf3 throughput against a PC with the expected results.

The image includes `ethtool`, `iperf3`, `phytool`, `mtd-utils`, `can-utils`, `nfs-utils` and
`pciutils` on top of the EDF base image.

## What the Yocto BSPs add

The per-board BSPs are in `Yocto/bsp/<board>/` and the per-target port overlays in
`Yocto/bsp/port-configs/`; `Yocto/README.md` in the repository describes the mechanism. The
fixes and additions that matter when using the image:

* **Ethernet FMC Max ports (`port-config.dtsi`).** The external PHYs are not described by the
  hardware export, so each target applies a port overlay — `ports-0123` for the four-port
  targets, `ports-0xxx` for the single-port ZCU104 — that sets the MAC address, the PHY handle,
  the shared MDIO bus (on `axi_ethernet_0`) and SGMII mode of each port. The overlay is selected
  by the `portcfg` field of the target in `config/data.json`.
* **Board RJ45 (PS GEM) works.** Previously the board's own Ethernet port negotiated a 1 Gb/s
  link but passed no traffic, because the generated device tree did not describe the board's
  TI DP83867 PHY and the RGMII clock delays were never programmed. The board PHYs are now
  described in each board's `system-user.dtsi` with the delays from the board's official device
  tree (ZCU102: both PHY addresses used by the different board revisions; VEK280: properties for
  both the DP83867 and the ADIN1300 PHY fitted to different revisions). On the Zynq UltraScale+
  boards and the VCK190 the board port also gets a fixed MAC address (`local-mac-address`), so
  its DHCP lease stays the same across boots; change it if you have more than one board of the
  same type on your network.
* **Kernel arguments and hostname are applied.** Previously the image booted with the default
  `amd-edf` hostname and without the design's kernel arguments (the CMA reservation used for the
  DMA buffers). The arguments (`BSP_EXTRA_BOOTARGS` in `Yocto/bsp/<board>/conf/local.conf.append`)
  are now added to the U-Boot boot script on Zynq UltraScale+ and to the systemd-boot entry on
  Versal, and the hostname is set to `<board>-axieth-2025-2`.
* **ZCU104: FMC VADJ.** The stock 2025.2 ZCU104 first-stage boot loader reads the wrong EEPROM
  and never switches VADJ on, so the Ethernet FMC Max stays unpowered. The Yocto BSP now applies
  the same FSBL patch as the PetaLinux BSP (`zcu104_vadj_fsbl.patch`).
* **Versal: VADJ and PHY reset.** On VCK190, VMK180, VPK120 and VPK180 the U-Boot boot command
  now switches the FMC VADJ rail to 1.5 V and then pulses the four PHY resets before booting
  Linux; on VEK280 (VADJ is on by default) it pulses the PHY resets. Without this, the FMC ports
  can be dead when Linux probes them.
* **Console mapping on Zynq UltraScale+.** `system-user.dtsi` pins the UART port numbers and
  aliases so that the console on the board's UART0 is always `ttyPS0`.
* **ZCU104 SD card.** `system-user.dtsi` adds SD controller quirks that otherwise make the kernel
  time out on the SD card (`error -110`).
* **UltraZed-EV.** As a third-party board with no AMD machine definition, its `system-user.dtsi`
  describes the SoM and carrier (GTR reference clocks, on-SoM Ethernet PHY with the MAC from the
  EEPROM, I2C tree, QSPI, eMMC, SD, USB3, SATA).

## Troubleshooting

See [Troubleshooting](troubleshooting.md#yocto-issues) for a card that does not boot, a board
that stops at the U-Boot prompt, and ports that do not come up.

[Ethernet FMC Max]: https://docs.opsero.com/op080/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
