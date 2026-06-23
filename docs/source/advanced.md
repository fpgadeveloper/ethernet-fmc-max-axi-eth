# Advanced: project structure and customization

This section is intended for users who want to modify the reference
designs — adding IP to the block design, changing constraints, modifying
the standalone application, or adding packages or drivers to the
PetaLinux project. It describes how the repository is laid out, how the
build flow works, how the Vitis and PetaLinux sides are
organised, and what modifications have been added on top of the stock
AMD BSPs.

The actual *build* instructions are in [build_instructions](build_instructions);
this section is about understanding the project well enough to modify
it.

## Repository layout

```
.
├── build.py                   <- Cross-platform build runner (the build logic)
├── build.sh / build.bat       <- Shims that invoke build.py (Linux/git bash, Windows)
├── Makefile                   <- Deprecated thin wrapper around build.sh (removed next version)
├── README.md
├── config/                    <- Source-of-truth design metadata and auto-generation
│   ├── data.json
│   └── update.py
├── docs/                      <- This documentation (Sphinx + Read the Docs)
├── EmbeddedSw/                <- Vendored AMD BSP libraries used by the Vitis build
├── PetaLinux/
│   └── bsp/                   <- Per-board and per-port-config BSP fragments
│       ├── uzev/, zcu102/, vck190/, …   <- board-specific overlays
│       └── ports-0123/, ports-0xxx/     <- port-config overlays
├── submodules/                <- Vendor board definition files (BDFs)
├── Vivado/
│   ├── scripts/
│   │   ├── build.tcl          <- Project creation + block design assembly
│   │   └── xsa.tcl            <- Synthesis, implementation, XSA export
│   └── src/
│       ├── bd/
│       │   ├── bd_mb.tcl      <- Block design for MicroBlaze targets
│       │   ├── bd_zynqmp.tcl  <- Block design for Zynq UltraScale+ targets
│       │   ├── bd_versal.tcl  <- Block design for Versal targets
│       │   └── gt_locs.tcl    <- Per-target GT-quad placement constants
│       └── constraints/
│           └── <target>.xdc   <- One XDC per target (pin assignments, timing)
└── Vitis/
    ├── py/
    │   ├── args.json          <- Repo-specific Vitis flow configuration
    │   ├── build-vitis.py     <- Universal Vitis Python build driver
    │   ├── make-boot.py       <- BOOT.BIN / .mcs packaging
    │   ├── pre_build.py       <- Per-build hook (e.g. constants generation)
    │   └── pre_platform_build.py
    ├── common/
    │   └── src/               <- Standalone application source (echo_server + VADJ)
    └── <target>_workspace/    <- Per-target Vitis workspace (generated)
```

Per-target build outputs are written to `Vivado/<target>/`,
`Vitis/<target>_workspace/`, and `PetaLinux/<target>/`; packaged
boot-image zips are written to `bootimages/`. None of these are
committed.

## Target naming

A *target label* is the canonical handle for a single design and is passed
to every build command via `--target`. It encodes the board and, for
boards with multiple FMC connectors, the connector:

```
<board>[_<connector>]
```

Examples: `uzev`, `vck190_fmcp1`, `zcu102_hpc0`, `kcu105_hpc`,
`vcu118_fmcp`. The first underscore-delimited token is taken as the
*target board* and is what the build runner uses to select the BSP
under `PetaLinux/bsp/<board>/`.

The complete list of valid targets comes from `config/data.json`; run
`./build.sh list` (or `./build.sh labels` for one per line) to print it.

## `config/data.json` and `config/update.py`

`config/data.json` is the canonical source of truth for the set of
supported designs and their per-target metadata (board name, processor
family, FMC connector, port lane mapping, baremetal-vs-PetaLinux
support, etc.). The `build.py` runner reads it directly at runtime, so
the target list is never hand-maintained.

`config/update.py` reads `data.json` and regenerates the auto-managed
documentation and metadata that is *not* read at runtime: the target
tables in the top-level `README.md`, the `.gitignore`, and the per-board
sections still embedded in `PetaLinux/Makefile` — each delimited by
`UPDATER START` / `UPDATER END` comment markers.

When adding or modifying a target, edit `data.json` and re-run
`update.py`. Do not hand-edit content between the `UPDATER START` /
`UPDATER END` markers; it will be overwritten on the next regeneration.

## Build runner

All build stages are driven by the cross-platform `build.py` runner at the
root of the repository, invoked through the `build.sh` shim on Linux / git
bash or `build.bat` on Windows (identical arguments). It reads the target
list and per-target attributes straight from `config/data.json`, builds
whatever a requested stage depends on automatically, skips anything already
built, and locates and sources the AMD tools itself — so there is no need to
source the Vivado / Vitis / PetaLinux settings scripts beforehand.

The build is organised into stages, each available as a sub-command:

| Command      | Stage                                                                                          |
|--------------|------------------------------------------------------------------------------------------------|
| `project`    | Create the Vivado project (`.xpr`) and block design.                                           |
| `xsa`        | Synthesise, implement and export the hardware (`.xsa`).                                         |
| `standalone` | Create the Vitis workspace, build the baremetal app, package `BOOT.BIN` / `.mcs`.              |
| `petalinux`  | Create the PetaLinux project from the XSA, apply the BSP overlays, build and package.          |
| `package`    | Gather the built boot artifacts into `bootimages/*.zip`.                                        |
| `all`        | Build every stage the target supports, then `package`.                                         |

Run `./build.sh list` to see the targets and their attributes, `./build.sh
status --target <t>` for per-stage artifact state, and `./build.sh --help`
for the full command list.

Each target is flagged in `config/data.json` for the stages it supports —
the MicroBlaze targets are baremetal-only (no PetaLinux), the rest support
the embedded-Linux flow as well. Because each stage builds its
prerequisites first, a single `./build.sh all --target <t>` cascades the
whole pipeline:

```
./build.sh all --target t
  -> xsa         : vivado creates the project (build.tcl), then synth/impl/XSA export (xsa.tcl)
  -> standalone  : vitis builds the platform + app, packages BOOT.BIN / .mcs
  -> petalinux   : petalinux-create -> -config --get-hw-description <XSA>
                   -> copy bsp/<board>/project-spec/* + bsp/<port-config>/project-spec/*
                   -> petalinux-build -> petalinux-package
  -> package     : zip the boot files into bootimages/
```

Build a single stage on its own with `./build.sh <stage> --target <t>`; the
runner still builds any missing prerequisite stages first.

Per-target lock files (`.<target>.lock` at the repository root) prevent two
concurrent builds of the same target from clobbering each other — so two
terminals can safely both run `./build.sh all --target all`.

## Vivado side

### Block design

The block-design scripts live under `Vivado/src/bd/`, one per
processor family, plus a shared GT-placement helper:

* `bd_mb.tcl`     — MicroBlaze targets (auboard, kcu105_hpc, vcu118_fmcp).
* `bd_zynqmp.tcl` — Zynq UltraScale+ targets.
* `bd_versal.tcl` — Versal targets.
* `gt_locs.tcl`   — Tcl dictionary mapping each target to its per-port
  GT coordinates (e.g. `dict get $gt_loc_dict uzev 0` returns `X0Y8`),
  sourced from `bd_mb.tcl` to drive the AXI Ethernet Subsystem IP
  configuration. Edit this dictionary when adding a new MicroBlaze
  target or changing its GT-quad placement.

Each script contains per-board conditional blocks where a target needs
to deviate from the family defaults — typically for clock-source
selection, PS configuration, or FMC connector routing.

After sourcing the BD script, `scripts/build.tcl` runs
`validate_bd_design -force`, which triggers parameter propagation and
fills in connection-automation rules. As a result the final
implemented design may contain nets that aren't visible in the BD TCL
source — to see the actual netlist as built, inspect the saved `.bd`
file under `Vivado/<target>/<target>.srcs/sources_1/bd/<bd_name>/` or
use `write_bd_tcl` to export a complete script from an open project.

### Constraints

`Vivado/src/constraints/<target>.xdc` contains pin assignments and any
target-specific timing constraints. Constraints common to all targets
of a given family are not factored out — each target's XDC is
self-contained.

### Build scripts

* `Vivado/scripts/build.tcl` creates the Vivado project, adds the
  target's XDC, sources the appropriate `bd_*.tcl`, and validates the
  block design. Invoked via `./build.sh project --target <t>`.
* `Vivado/scripts/xsa.tcl` opens the existing project, runs synthesis
  and implementation, exports the XSA, and writes the bitstream into
  the implementation run directory. Invoked via `./build.sh xsa --target <t>`.

Both scripts check `XILINX_VIVADO` to confirm the installed Vivado
version matches the `version_required` constant at the top of the
file. Bumping the project to a new Vivado release means changing those
constants and re-testing — the BD TCL APIs are not stable across major
releases.

### Modifying the block design

Edit the block-design script for the appropriate processor family
directly. If the change applies only to some targets in the family,
wrap the additions in the appropriate per-board conditional block.

Once the script is edited, delete any existing per-target Vivado
project directory (`rm -rf Vivado/<target>`) and re-run the Vivado
build:

```
./build.sh xsa --target <target>
```

This re-creates the project, sources the modified BD script, runs
`validate_bd_design`, synthesises, implements, and re-exports the XSA.
Downstream Vitis / PetaLinux / boot-image steps will pick up the new
XSA on the next build.

### Adding or modifying constraints

Edit `Vivado/src/constraints/<target>.xdc` directly. If a constraint
applies to all targets in a family, it still needs to be replicated to
each target's XDC — there is no shared XDC.

## Vitis side

The standalone (baremetal) build runs the lwIP echo-server example on
the target, exercising the AXI Ethernet ports. The application source
is shared across all targets; per-target specialisation is handled by
the build driver, not by per-target source.

The Ethernet FMC Max requires the FMC adjustable I/O voltage rail (VADJ)
to be programmed to 1.5V before the on-board PHYs come out of reset. On
Versal targets that do not enable VADJ from the platform itself, the
standalone application performs that programming at startup via the
`vadj.c` / `vadj.h` files in `common/src` (the entry point in `main.c`
calls `vadj_enable(VADJ_1V5)`). VEK280 already enables VADJ by default
and this call is a no-op. Non-Versal boards rely on the FSBL (ZCU102/
ZCU106) or board-default rails to bring VADJ up; the ZCU104 FSBL needs
the patch listed under the ZCU104 BSP section below.

### Layout

```
Vitis/
├── py/
│   ├── args.json
│   ├── build-vitis.py        <- Universal Vitis Python build driver
│   ├── make-boot.py          <- BOOT.BIN / .mcs packaging
│   ├── pre_build.py          <- Hook run before each app build
│   └── pre_platform_build.py <- Hook run before each platform build
├── common/
│   └── src/                  <- Application source: main.c + vadj.c/h
├── boot/<target>/            <- Per-target packaged boot files
└── <target>_workspace/       <- Generated Vitis workspace per target
```

### `args.json`

`Vitis/py/args.json` is the repo-specific configuration that drives
the universal `build-vitis.py` driver. The key fields are:

* `bd_name` — block-design name (`axieth`).
* `app_name` — name of the Vitis application (`echo_server`).
* `app_template` — the Vitis app template the build driver uses to
  scaffold the application (`lwip_echo_server`).
* `bsp_libs` — BSP libraries to add and configure (`lwip220` with
  DHCP + ACD check + an enlarged pbuf pool, and `xiltimer` with the
  interval timer enabled).
* `src` — application source mapping. `"all": "common/src"` means
  every target uses the same source directory.
* `pre_platform_build_script` / `pre_build_script` — hooks invoked at
  the appropriate point in the workspace build.

### Modifying the standalone application

Edit `Vitis/common/src/*.c` directly. The next `./build.sh standalone
--target <t>` rebuilds the application against the existing platform; if
you've changed the hardware (XSA) you'll need a fresh workspace
(`./build.sh clean --target <t> --stage standalone` first).

### Modifying BSP libraries or build hooks

Adjust the corresponding entry in `Vitis/py/args.json`. Configuration
changes propagate through the next `pre_platform_build` run. The two
hook scripts in `py/` are repo-specific Python; edit them when the
change is more elaborate than a `bsp_libs` config tweak.

## PetaLinux side

### BSP composition

The PetaLinux project for a given target is composed at build time
from up to two BSP fragments copied into the target's project
directory:

1. A **board BSP** at `PetaLinux/bsp/<board>/` (for example `uzev/`,
   `zcu102/`, `vck190/`). Provides board-specific kernel and U-Boot
   configuration, the system device-tree fragment for the board, and
   any board-specific patches. **MicroBlaze targets (auboard,
   kcu105_hpc, vcu118_fmcp) do not have a board BSP**; only the
   port-config overlay is applied to them.
2. A **port-config overlay** at `PetaLinux/bsp/<port-config>/` (one
   of `ports-0123/` or `ports-0xxx/`). Provides `port-config.dtsi` —
   the device-tree fragment that wires up the AXI Ethernet ports
   active on this target.

The mapping from target to (board BSP, port-config overlay) is encoded
in `PetaLinux/Makefile`'s `UPDATER` block. The last column names the
port-config overlay; the board BSP is derived from the first token of
the target name.

The two port-config variants are:

* `ports-0123` — four-port designs (all multi-port targets).
* `ports-0xxx` — single-port designs (currently `zcu104`). Configures
  only port 0, and overrides the AXI Ethernet PHY to SGMII with an
  explicit MDIO PHY node (the ZCU104 routes only one Ethernet lane
  through the FMC).

### Layout of a board BSP

```
PetaLinux/bsp/<board>/project-spec/
├── configs/
│   ├── config                <- petalinux-config: bootargs, rootfs, hostname
│   ├── rootfs_config         <- petalinux-config -c rootfs: included packages
│   ├── init-ifupdown/
│   │   └── interfaces        <- /etc/network/interfaces
│   └── busybox/
│       └── inetd.conf
└── meta-user/
    ├── conf/
    │   ├── user-rootfsconfig <- declares additional rootfs config options
    │   ├── petalinuxbsp.conf
    │   └── layer.conf
    ├── recipes-bsp/
    │   ├── device-tree/
    │   │   ├── device-tree.bbappend
    │   │   └── files/
    │   │       └── system-user.dtsi    <- board-specific DT additions
    │   ├── u-boot/
    │   │   ├── u-boot-xlnx_%.bbappend
    │   │   └── files/
    │   │       ├── bsp.cfg             <- U-Boot Kconfig additions
    │   │       ├── platform-top.h
    │   │       └── *.patch             <- U-Boot source patches
    │   └── embeddedsw/                 <- (zcu104 only)
    │       ├── fsbl-firmware_%.bbappend
    │       └── files/
    │           └── zcu104_vadj_fsbl.patch
    └── recipes-kernel/
        └── linux/
            ├── linux-xlnx_%.bbappend
            └── linux-xlnx/
                └── bsp.cfg             <- kernel Kconfig additions
```

### Adding a package to the root filesystem

1. Append the new option to `bsp/<board>/project-spec/configs/rootfs_config`:

   ```
   CONFIG_<package>=y
   ```

2. If the package is not in the default `petalinux-config -c rootfs`
   menu, also append a declaration line to
   `bsp/<board>/project-spec/meta-user/conf/user-rootfsconfig`.

3. If the package is not provided by an existing meta-layer, add a
   recipe under
   `bsp/<board>/project-spec/meta-user/recipes-apps/<package>/<package>.bb`.

### Adding a kernel config option

Append the option to
`bsp/<board>/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`:

```
CONFIG_<name>=y
```

The corresponding bbappend at `recipes-kernel/linux/linux-xlnx_%.bbappend`
registers `bsp.cfg` as a kernel configuration fragment.

### Adding a device-tree fragment

For per-board fragments, edit
`bsp/<board>/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`.
For per-port-config fragments, edit the corresponding
`bsp/<port-config>/project-spec/meta-user/recipes-bsp/device-tree/files/port-config.dtsi`.

If you add new files, ensure they are listed in `SRC_URI:append` in
`device-tree.bbappend`.

### Adding a kernel patch or out-of-tree driver

1. Drop the patch file into
   `bsp/<board>/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/`.
2. Add a line to `recipes-kernel/linux/linux-xlnx_%.bbappend`:

   ```
   SRC_URI:append = " file://<your-patch>.patch"
   ```

### Modifying U-Boot

The same pattern as the kernel, under
`bsp/<board>/project-spec/meta-user/recipes-bsp/u-boot/`. `bsp.cfg`
adds U-Boot Kconfig options; `platform-top.h` overrides the U-Boot
platform header; patches are listed in `SRC_URI:append` in
`u-boot-xlnx_%.bbappend`.

## Modifications layered on the stock BSPs

The board BSPs in this repository started as the corresponding stock
AMD reference BSPs and have been modified in the following ways. This
list is the answer to *"what would I lose if I overwrote the BSP with
the stock one?"* — it is what to re-apply if you ever do that.

### All BSPs

* **Root filesystem additions** in `configs/rootfs_config`:
  `ethtool`, `iperf3`, `phytool` (plus `ethtool-dev` and `ethtool-dbg`
  on ZynqMP).
* **Hostname / product name** set in `configs/config` via
  `CONFIG_SUBSYSTEM_HOSTNAME` and `CONFIG_SUBSYSTEM_PRODUCT`.
* **`system-user.dtsi`** includes `port-config.dtsi`. The matching
  `device-tree.bbappend` adds both files to `SRC_URI:append`.
* **Kernel configs** in `linux-xlnx/bsp.cfg`:
  `CONFIG_AMD_PHY`, `CONFIG_XILINX_PHY` (needed for the PHYs used by
  the AXI Ethernet ports).

### ZynqMP BSPs

* **SD-card root filesystem** configured in `configs/config`:
  `CONFIG_SUBSYSTEM_ROOTFS_EXT4`, `CONFIG_SUBSYSTEM_SDROOT_DEV`,
  `CONFIG_SUBSYSTEM_USER_CMDLINE` (with `cma=1536M` for the AXI DMA
  buffers — except the UZ-EV, which overrides this to `cma=1000M` to fit
  the smaller SoM DDR budget; see the UZ-EV section below).
* **DMA-engine kernel configs**:
  `CONFIG_XILINX_DMA_ENGINES`, `CONFIG_XILINX_DPDMA`,
  `CONFIG_XILINX_ZYNQMP_DMA`.
* **U-Boot patch `0001-ubifs-distroboot-support.patch`** (one copy lives in
  each ZynqMP board BSP under `recipes-bsp/u-boot/files/`).

### UltraZed-EV (uzev) BSP

* **`CONFIG_YOCTO_MACHINE_NAME="zynqmp-generic"`** in `configs/config`
  (the UZ-EV is not a stock Xilinx eval board).
* **SD-card device set to `/dev/mmcblk1p2`** rather than the ZynqMP
  default `mmcblk0p2`.
* **`PRIMARY_SD_PSU_SD_1_SELECT=y`** to route the boot SD interface
  through PSU SD1 instead of SD0.
* **Custom `system-user.dtsi`** with UZ-EV-specific peripheral
  configuration (overwrites the file copied in from a stock UZ-EV BSP).
* **`meta-xilinx-tools/recipes-bsp/uboot-device-tree/`** overlay that
  overrides the U-Boot device tree.

### ZCU104 BSP

* **FSBL patch `zcu104_vadj_fsbl.patch`** in
  `recipes-bsp/embeddedsw/files/`, registered via
  `fsbl-firmware_%.bbappend`. The stock 2025.2 ZCU104 FSBL reads the wrong
  EEPROM (the board EEPROM at I2C address 0x54 on TCA9548A channel 1
  instead of the FMC EEPROM at 0x50 on channel 6) and only reads 32 bytes,
  which is not enough to reach the VADJ voltage record. The patch fixes
  the EEPROM address (0x50), the mux channel (channel 6 = 0x20), the
  buffer size (256 bytes), and adds the missing "set read address to zero"
  write, so the FSBL can correctly detect the FMC's VADJ requirement and
  program the on-board IRPS5401 PMBus regulator accordingly.
* Standard ZynqMP SD-root configs and U-Boot ubifs patch as above.

### Versal BSPs (vck190, vmk180, vpk120, vpk180, vhk158, vek280)

* **`meta-xilinx-tools/recipes-bsp/uboot-device-tree/`** overlay that
  overrides the U-Boot device tree — required because the stock U-Boot
  device tree does not describe the FMC-side AXI Ethernet ports.
* **U-Boot patch `0001-xilinx_versal.h-ubifs-distroboot-support.patch`**.

### Port-config overlays

The two overlays in `PetaLinux/bsp/ports-*/` are not derived from any
stock BSP — they exist solely to add the device-tree fragment that
wires up the AXI Ethernet ports. Each contains a single
`port-config.dtsi` (the surrounding directory structure is needed so
that Yocto picks it up via the `SRC_URI:append = " file://port-config.dtsi"`
line in `device-tree.bbappend`).

## Where build outputs land

| Path                                | Contents                                                                       |
|-------------------------------------|--------------------------------------------------------------------------------|
| `Vivado/<target>/`                  | Vivado project. `<bd_name>_wrapper.xsa` is the export.                          |
| `Vivado/<target>/<target>.runs/impl_1/<bd_name>_wrapper.bit` | Bitstream.                                              |
| `Vivado/logs/`                      | Per-target Vivado build logs (xpr + xsa).                                       |
| `Vitis/<target>_workspace/`         | Per-target Vitis workspace (platform + application + BSP).                      |
| `Vitis/boot/<target>/`              | Packaged Vitis boot files (`BOOT.BIN` for Zynq/ZynqMP/Versal, `.mcs` for MicroBlaze). |
| `PetaLinux/<target>/`               | PetaLinux project. All Yocto build state lives here.                            |
| `PetaLinux/<target>/images/linux/`  | `BOOT.BIN`, `image.ub`, `boot.scr`, `rootfs.tar.gz`, etc.                       |
| `PetaLinux/<target>/build/build.log`| PetaLinux build log.                                                            |
| `bootimages/`                       | Per-target zipped boot files (`<prj>_<target>_petalinux-<ver>.zip` and `<prj>_<target>_standalone-<ver>.zip`). |

None of these directories are committed to the repository.
