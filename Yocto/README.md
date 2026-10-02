# Yocto / EDF builds

This folder builds Linux images for the **Ethernet FMC Max AXI Ethernet** reference
designs using the AMD Yocto / Embedded Development Framework (EDF) flow — the
announced successor to PetaLinux Tools.

## How it works: the parse-sdt flow

The build generates a **custom Yocto MACHINE directly from the Vivado XSA** —
there is no dependency on an AMD-provided machine config. This is what lets the
design serve any board (including third-party boards with no AMD machine, like
the Avnet UltraZed-EV) and lets a customer change the PS in Vivado and have it
flow through automatically:

```
XSA  --sdtgen-->  System Device Tree  --gen-machineconf parse-sdt-->  MACHINE + DTS
```

`scripts/configure-build.sh` runs `xsct`/`sdtgen` on the XSA to produce a System
Device Tree (which includes `pl.dtsi`, the PL hardware extracted from the
design), then runs `gen-machineconf parse-sdt` to emit
`conf/machine/axieth-<target>.conf` plus the lopper-generated per-domain device
trees. The PL **AXI Ethernet cores** therefore come from the design's own SDT —
no hand-curated PL device tree. Because no PL overlay is requested, the Vivado
bitstream/PDI is embedded into `BOOT.BIN` (the FSBL/PLM programs the PL at boot).

The external Ethernet PHYs, however, live off-chip on the Ethernet FMC Max and
are **not** in the XSA, so two small hand-written device-tree files are layered
on top of the generated tree:

* **`bsp/<board>/…/system-user.dtsi`** — SoC-side board quirks (see "Per-board
  fixups").
* **`bsp/port-configs/<ports-*>/…/port-config.dtsi`** — the per-target AXI
  Ethernet PHY wiring (see "Port-config overlays").

## Prerequisites

Host packages on Ubuntu 22.04 / 24.04:

```
sudo apt-get install repo gawk wget git diffstat unzip texinfo gcc \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 bmap-tools
```

Plus Vivado 2025.2 (used to produce the XSA this flow consumes) and Vitis
2025.2 — `sdtgen`/`xsct` (used to turn the XSA into a System Device Tree)
ship with Vitis, not Vivado, in 2025.2. The build runner locates and sources
the Vitis environment itself; sourcing it manually is only needed when
running the `scripts/` engine by hand:

```
source <xilinx-install>/2025.2/Vivado/settings64.sh
source <xilinx-install>/2025.2/Vitis/settings64.sh
```

## Build

Yocto images are built with the cross-platform build runner at the repo root
(this stage requires a native Linux machine; on Windows the runner refuses
it up front and prints the hand-off command):

```
./build.sh yocto --target zcu102_hpc0    # or any target from `./build.sh list`
```

The runner builds the Vivado XSA first if one isn't already present, then
sequences the four scripts in `scripts/` — the engine of the flow
(init-workspace, configure-build, build-image, package-output). The legacy
`cd Yocto && make yocto TARGET=<target>` still works on Linux (the Makefile
is now a thin wrapper around `build.sh`) but is deprecated.

The first build for a target:

1. Builds the Vivado project and exports the XSA if one isn't already
   present.
2. Initializes a manifest workspace under `Yocto/<TARGET>/` with
   `repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2025.2 -m default-edf.xml`
   and `repo sync` (≈5 GB of git history).
3. Sources `edf-init-build-env` to set up the bitbake environment.
4. Generates the System Device Tree from the XSA and runs
   `gen-machineconf parse-sdt` to create `MACHINE = "axieth-<target>"`.
5. Layers `bsp/<board>/conf/local.conf.append` (hostname, kernel cmdline) and
   `bsp/<board>/meta-user/` (kernel config, `system-user.dtsi` board fixups,
   image bbappend) over the EDF default config, plus — when the target has a
   port config — the `bsp/port-configs/<ports-*>/meta-user/` overlay layer.
6. Runs `bitbake edf-linux-disk-image`.
7. Gathers `BOOT.BIN` (with the PL bitstream/PDI embedded), `Image`,
   `system.dtb`, `boot.scr`, `rootfs.tar.gz`, `rootfs.wic.xz`, and
   `rootfs.wic.bmap` into `Yocto/<TARGET>/images/linux/`.

Subsequent builds skip `repo sync`. To force a re-config (e.g. after editing
`bsp/<board>/conf/local.conf.append`), remove `Yocto/<TARGET>/configdone.txt`.

`./build.sh yocto --target all` builds every Yocto target; `./build.sh status --target all`
reports which are built.

The Yocto flow is supported on the **Zynq UltraScale+** targets (`zcu102_hpc0`,
`zcu102_hpc1`, `zcu104`, `zcu106_hpc0`, `zcu111`, `zcu208`, `zcu216`, `uzev`) and
the **Versal** targets (`vck190_fmcp1`, `vck190_fmcp2`, `vek280`, `vhk158`,
`vmk180_fmcp1`, `vmk180_fmcp2`, `vpk120`, `vpk180`) — the same set that has
PetaLinux support. The MicroBlaze (pure-FPGA) targets are standalone-only and
have no Linux flow.

## Port-config overlays (`port-config.dtsi`)

The external Ethernet-FMC-Max PHYs are board knowledge the XSA does not carry,
and the set of active ports differs per target (a four-port design vs. the
single-port `zcu104`). Two targets can share one board BSP but need *different*
PHY wiring, so the wiring is factored into per-config overlay **layers** rather
than into the board BSP:

```
bsp/port-configs/
  ports-0123/meta-user/   four-port designs  (axi_ethernet_0..3)
  ports-0---/meta-user/   one-port designs   (axi_ethernet_0, e.g. zcu104)
```

Each overlay is a small Yocto layer whose `device-tree.bbappend` adds its
`port-config.dtsi` to the Linux device tree via `EXTRA_DT_INCLUDE_FILES`. Which
overlay applies is selected per target by the **second field** of the target's
Yocto build line (e.g. `zcu104_target := zynqMP ports-0---`):
`configure-build.sh` adds `bsp/port-configs/<that-config>/meta-user` to
`bblayers.conf` alongside the board layer. A repo/target with no port config
(empty second field) simply gets no overlay — the mechanism is a no-op there, so
the scripts stay identical across repos.

`port-config.dtsi` sets, for each active port, the `local-mac-address`,
`phy-handle`, `xlnx,has-mdio` and `phy-mode = "sgmii"` on the
`&axi_ethernet_N` node (the node itself comes from the SDT's `pl.dtsi`). The
Ethernet FMC Max routes all PHYs through a single MDIO bus on
`axi_ethernet_0`, so that node also carries the `mdio` child with one
`ethernet-phy` entry per port (`phy@1`, `phy@3`, `phy@12`, `phy@15`), each
flagged `xlnx,phy-type = <0x4>` and `enet-phy-lane-swap`; the other ports
reference those PHYs by `phy-handle`. MAC addresses are assigned
`00:0a:35:00:01:22` (Port 0) … `…:25` (Port 3).

## Per-board fixups (`system-user.dtsi`)

Each board's `bsp/<board>/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`
is layered onto the generated Linux device tree (via `EXTRA_DT_INCLUDE_FILES`,
guarded so it only applies to the Linux domain DT — the FSBL/PLM/PMU domain DTs
don't define the SoC peripheral labels). It contains only SoC-side board quirks,
not PL hardware or PHY wiring (that's the port-config overlay):

* **Zynq UltraScale+ stock boards (`zcu102`, `zcu104`, `zcu106`, `zcu111`,
  `zcu208`, `zcu216`)** carry a small, nearly identical fixup, because the
  board-specific PS config comes from each target's XSA via parse-sdt:
  * **UART mapping**: the 2025.2 flow assigns `port-number = <0>` to `uart1` by
    default, so `ttyPS0` maps to the wrong controller. These boards pin the port
    numbers and the `serial0`/`serial1` aliases so the console (cabled to UART0)
    is deterministic.
  * **`zcu104` only** additionally fixes up `&sdhci1`: the design's XSA exports a
    minimal SD node, so without `no-1-8-v`/`disable-wp`/`broken-cd`, a frequency
    cap and a UHS caps mask the kernel times out initialising the SD card with
    "error -110". Values mirror the stock 2025.2 `xilinx-zcu104` BSP.
* **`uzev` (Avnet UltraZed-EV)**: a third-party SOM+carrier with no AMD machine,
  so its `system-user.dtsi` is large and ported from the proven PetaLinux `uzev`
  BSP — it adds the board model, external GTR reference clocks + `&psgtr`
  mapping (for the PS-GTR-routed SATA/USB3/DP/PCIe), the on-SOM `gem3` PHY (with
  its MAC read from the board EEPROM via `nvmem-cells`), the I2C power/clock/
  EEPROM tree (PCA9543 switch, 5P49V5935 clock generator, IRPS5401/IR38063
  regulators), QSPI, the 8-bit eMMC (`sdhci0`), the level-shifted SD slot
  (`sdhci1`), USB3 (`dwc3_0` super-speed) and SATA (with the CEVA PHY
  parameters) — plus the same UART port-number pinning as the stock boards.
* **Versal boards (`vck190`, `vek280`, `vhk158`, `vmk180`, `vpk120`, `vpk180`)**
  need little or nothing on the SoC side because the PS config and console come
  entirely from the SDT:
  * `vck190` adds the `zyxclmm_drm` (`xlnx,zocl-versal`) node under `&amba`.
  * `vek280` adds a `reserved-memory` region (PL DDR + LPDDR buffers) and the
    `zyxclmm_drm` node under `&amba_pl`.
  * `vhk158`, `vmk180`, `vpk120`, `vpk180` ship an empty placeholder
    `system-user.dtsi` (nothing to override beyond the SDT).

Kernel config fragments live in
`bsp/<board>/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`:

* **Zynq UltraScale+**: the boards enable the PHY drivers
  (`CONFIG_AMD_PHY`, `CONFIG_XILINX_PHY`) and/or the Xilinx DMA-engine configs
  (`CONFIG_XILINX_DMA_ENGINES`, `CONFIG_XILINX_DPDMA`,
  `CONFIG_XILINX_ZYNQMP_DMA`) the AXI Ethernet datapath needs; `zcu111`
  additionally enables `CONFIG_XILINX_SDFEC`.
* **Versal**: the fragment is empty — the Versal kernel defconfig already
  carries what the AXI Ethernet datapath needs.

## Flashing to SD card

The build produces a full wic disk image (`rootfs.wic.xz`). Flash it to the SD
card's raw device; per-partition file copies do **not** work because the boot
script boots from the device it finds itself on.

The EDF wks installs `BOOT.BIN` onto an ext4 `boot` partition (which the BootROM
cannot read) and leaves the first FAT partition (`esp`) empty. The BootROM reads
`BOOT.BIN` from the first FAT partition, so after flashing you must drop
`BOOT.BIN` onto `esp` by hand.

### 1. Identify the SD card device — carefully

`dd`-style writes to a block device cannot be undone. With the SD card
**un**plugged, run `lsblk -o NAME,SIZE,RM,TYPE,MOUNTPOINT`; insert the card and
re-run it. The new entry (typically `/dev/sdX`, `RM=1`, size matching your card)
is your target. Confirm with
`udevadm info --query=property --name=/dev/sdX | grep -E "ID_BUS|ID_MODEL"`
(`ID_BUS=usb`). **Do not proceed until you are certain `/dev/sdX` is your SD card
and not an internal disk.**

### 2. Unmount any auto-mounted partitions

```
for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
```

### 3. Flash the wic image to the raw device

```
sudo bmaptool copy \
    --bmap Yocto/<TARGET>/images/linux/rootfs.wic.bmap \
          Yocto/<TARGET>/images/linux/rootfs.wic.xz \
          /dev/sdX
```

Fallback (slower): `xzcat …/rootfs.wic.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync`.

### 4. Install BOOT.BIN on the esp partition

```
sudo partprobe /dev/sdX
sudo mkdir -p /mnt/sd_esp
sudo mount /dev/sdX1 /mnt/sd_esp
sudo cp Yocto/<TARGET>/images/linux/BOOT.BIN /mnt/sd_esp/BOOT.BIN
sync
sudo umount /mnt/sd_esp && sudo rmdir /mnt/sd_esp
```

### 5. Eject and boot

Eject the card cleanly (`sudo eject /dev/sdX`) so pending writes flush. Insert it
into the board, set the boot-mode switches to SD (see
[Boot PetaLinux](../docs/source/petalinux.md) for the per-board switch settings),
power-cycle, and attach a UART terminal at 115200 8N1.

> On the Zynq UltraScale+ boards the SD card is `mmcblk0` and the rootfs mounts
> on `mmcblk0p3` (set in `bsp/<board>/conf/local.conf.append`). On the Versal
> boards the boot script resolves `root=` dynamically from the device it booted
> from.

## Offline / faster builds

Place the absolute path to a directory containing an extracted AMD sstate-cache
mirror in `Yocto/offline.txt` — `configure-build.sh` auto-detects which
architecture subdirs exist under it and wires one `SSTATE_MIRRORS` entry per
arch (plus `SOURCE_MIRROR_URL` if a `downloads/` dir is present).

Expected layout under that path:

```
<sstate root>/
  aarch64/      (Zynq UltraScale+ and Versal Linux)
  microblaze/   (the ZynqMP PMU firmware multiconfig)
  downloads/    (optional — the source-mirror tarballs)
```

The sstate-cache and downloads archives are available behind login at the AMD
Embedded Design Tools download page under "sstate-cache & Downloads - 2025.2".

## Layout

```
Yocto/
  Makefile                  deprecated thin wrapper around ../build.sh
  README.md                 this file
  .gitignore                excludes per-target workspaces + local state
  offline.txt               (optional, gitignored) path to an extracted sstate mirror
  scripts/
    init-workspace.sh       repo init + sync
    configure-build.sh      sdtgen + gen-machineconf parse-sdt + apply BSP (+ overlay) + sstate
    build-image.sh          bitbake the image recipe
    package-output.sh       gather deploy artifacts into images/linux/
  bsp/
    <board>/                one per board (zcu102 is shared by hpc0 + hpc1)
      conf/local.conf.append   board overrides (hostname, kernel cmdline)
      meta-user/               Yocto layer: kernel cfg, system-user.dtsi, image bbappend
    port-configs/
      ports-0123/, ports-0---/ per-target AXI Ethernet PHY overlay layers
  <TARGET>/                 (gitignored) per-target workspace built by the runner
  logs/                     (gitignored) build logs
```

## Architectural notes

* **The four scripts are universal** — identical across all of our
  reference repos. The per-repo data (target list, `BD_NAME`, each target's
  template and optional port config) lives in `config/data.json`, which
  `build.py` reads at runtime — nothing is generated into this folder.

* **The MACHINE is generated from the XSA** by `gen-machineconf parse-sdt` (the
  flow AMD recommends; `parse-xsa` is deprecated). There is no pinned
  AMD-validated MACHINE and no per-target flow selection. The custom machine is
  named `${BD_NAME}-<target>` (i.e. `axieth-<target>`); `configure-build.sh`
  takes `BD_NAME` as an argument so the script stays repo-agnostic.

* **The bitstream lives in BOOT.BIN**, not loaded at runtime via FPGA manager.
  Because no PL overlay is requested, the bitstream/PDI `sdtgen` extracted from
  the XSA is embedded into `BOOT.BIN` and the FSBL/PLM programs the PL during
  boot.

* **`system-user.dtsi` and `port-config.dtsi` are scoped to the Linux device
  tree** (via a guard on `CONFIG_DTFILE`). The FSBL/PLM and PMU domain
  device-trees don't define the SoC peripheral / `axi_ethernet` labels the
  overrides reference, so including them there makes `dtc` fail with "Label or
  path … not found".

* **Adding a target**: set `"yocto": true` for the design in `config/data.json`
  and run `config/update.py` (regenerates the README table), then create
  `bsp/<board>/` following an existing board (start from `zcu102` for a stock
  AMD ZynqMP board, `vck190` / `vek280` for a Versal board, or `uzev` for a
  board needing a rich `system-user.dtsi`). If the target uses a port count not
  already covered, add a `bsp/port-configs/<ports-XXXX>/` overlay.
```
