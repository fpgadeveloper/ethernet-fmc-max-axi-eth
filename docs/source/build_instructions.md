# Build instructions

## Source code

The source code for the reference designs is managed on this Github repository:

* [https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth](https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth)

To get the code, you can follow the link and use the **Download ZIP** option, or you can clone it
using this command:
```
git clone https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth.git
```

## License requirements

Some of the designs in this repository target dev boards for which a license is required to generate a bitstream. 
Others can be built with the Vivado ML Standard Edition **without a license**. The table of target designs in the 
following section contains a column specifying which designs require a license, and which can be built without a 
license.

## Target designs

This repo contains several designs that target the various supported development boards and their
FMC connectors. The table below lists the target design name, the Ethernet ports supported by the design and 
the FMC connector on which to connect the mezzanine card.

| Target board        | Target design     | Ports   | FMC Slot    | License<br> required |
|---------------------|-------------------|---------|-------------|----------------------|
| [KCU105]            | `kcu105_hpc`      | 4x      | HPC         | YES |
| [UltraZed-EV carrier] | `uzev`          | 4x      | HPC         | NO  |
| [VCK190]            | `vck190_fmcp1`    | 4x      | FMCP1       | YES |
| [VCK190]            | `vck190_fmcp2`    | 4x      | FMCP2       | YES |
| [VEK280]            | `vek280`          | 4x      | FMCP        | YES |
| [VEK280] ES Rev-B   | `vek280_es_revb`  | 4x      | FMCP        | YES |
| [VMK180]            | `vmk180_fmcp1`    | 4x      | FMCP1       | YES |
| [VMK180]            | `vmk180_fmcp2`    | 4x      | FMCP2       | YES |
| [VPK120]            | `vpk120`          | 4x      | FMCP        | YES |
| [VCU118]            | `vcu118_fmcp`     | 4x      | FMCP        | YES |
| [ZCU102]            | `zcu102_hpc0`     | 4x      | HPC0        | YES |
| [ZCU102]            | `zcu102_hpc1`     | 4x      | HPC1        | YES |
| [ZCU104]            | `zcu104`          | 1x      | LPC         | NO  |
| [ZCU106]            | `zcu106_hpc0`     | 4x      | HPC0        | NO  |
| [ZCU111]            | `zcu111`          | 4x      | FMCP        | YES |
| [ZCU208]            | `zcu208`          | 4x      | FMCP        | YES |
| [ZCU216]            | `zcu216`          | 4x      | FMCP        | YES |

## Windows users

Windows users will be able to build the Vivado projects and compile the standalone applications,
however Linux is required to build the PetaLinux projects. 

```{tip} If you wish to build the PetaLinux projects,
we recommend that you build the entire project (including the Vivado project) on a machine (either 
physical or virtual) running one of the [supported Linux distributions].
```

### Build Vivado project in Windows

1. Download the repo as a zip file and extract the files to a directory
   on your hard drive --OR-- clone the repo to your hard drive
2. Open Windows Explorer, browse to the repo files on your hard drive.
3. In the `Vivado` directory, double click on the `build-vivado.bat` batch file.
   You will be prompted to select a target design to build. You will find the project in
   the folder `Vivado/<target>`.
4. Run Vivado and open the project that was just created.
5. Click Generate bitstream.
6. When the bitstream is successfully generated, select **File->Export->Export Hardware**.
   In the window that opens, tick **Include bitstream** and use the default name and location
   for the XSA file.

## Linux users

These projects can be built using a machine (either physical or virtual) with one of the 
[supported Linux distributions].

```{tip} The build steps can be completed in the order shown below, or
you can go directly to the [build PetaLinux](#build-petalinux-project-in-linux) instructions below
to build the Vivado and PetaLinux projects with a single command.
```

### Build Vivado project in Linux

1. Open a command terminal and launch the setup script for Vivado:
   ```
   source <path-to-vivado-install>/2024.1/settings64.sh
   ```
2. Clone the Git repository and `cd` into the `Vivado` folder of the repo:
   ```
   git clone https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth.git
   cd ethernet-fmc-max-axi-eth/Vivado
   ```
3. Run make to create the Vivado project for the target board. You must replace `<target>` with a valid
   target (alternatively, skip to step 5):
   ```
   make project TARGET=<target>
   ```
   Valid target labels are listed in the table of target designs above.
   That will create the Vivado project and block design without generating a bitstream or exporting to XSA.
4. Open the generated project in the Vivado GUI and click **Generate Bitstream**. Once the build is
   complete, select **File->Export->Export Hardware** and be sure to tick **Include bitstream** and use
   the default name and location for the XSA file.
5. Alternatively, you can create the Vivado project, generate the bitstream and export to XSA (steps 3 and 4),
   all from a single command:
   ```
   make xsa TARGET=<target>
   ```
   
### Build PetaLinux project in Linux

These steps will build the PetaLinux project for the target design. You are not required to have built the
Vivado design before following these steps, as the Makefile triggers the Vivado build for the corresponding
design if it has not already been done.

1. Launch the setup script for Vivado (only if you skipped the Vivado build steps above):
   ```
   source <path-to-vivado-install>/2024.1/settings64.sh
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2024.1/settings.sh
   ```
3. Build the PetaLinux project for your specific target platform by running the following
   command, replacing `<target>` with a valid value from below:
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   Valid target labels are listed in the table of target designs above.
   Note that if you skipped the Vivado build steps above, the Makefile will first generate and
   build the Vivado project, and then build the PetaLinux project.

### PetaLinux offline build

If you need to build the PetaLinux projects offline (without an internet connection), you can
follow these instructions.

1. Download the sstate-cache artefacts from the Xilinx downloads site (the same page where you downloaded
   PetaLinux tools). There are four of them:
   * aarch64 sstate-cache (for ZynqMP designs)
   * arm sstate-cache (for Zynq designs)
   * microblaze sstate-cache (for Microblaze designs)
   * Downloads (for all designs)
2. Extract the contents of those files to a single location on your hard drive, for this example
   we'll say `/home/user/petalinux-sstate`. That should leave you with the following directory 
   structure:
   ```
   /home/user/petalinux-sstate
                             +---  aarch64
                             +---  arm
                             +---  downloads
                             +---  microblaze
   ```
3. Create a text file called `offline.txt` that contains a single line of text. The single line of text
   should be the path where you extracted the sstate-cache files. In this example, the contents of 
   the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is written with NO TRAILING 
   FORWARD SLASH.

Now when you use `make` to build the PetaLinux projects, they will be configured for offline build.

[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[VCK190]: https://www.xilinx.com/vck190
[VEK280]: https://www.xilinx.com/vek280
[VMK180]: https://www.xilinx.com/vmk180
[VPK120]: https://www.xilinx.com/vpk120
[VCU108]: https://www.xilinx.com/vcu108
[VCU118]: https://www.xilinx.com/vcu118
[KCU105]: https://www.xilinx.com/kcu105
[ZCU111]: https://www.xilinx.com/zcu111
[ZCU208]: https://www.xilinx.com/zcu208
[UltraZed-EV carrier]: https://www.xilinx.com/products/boards-and-kits/1-y3n9v1.html
[ZCU102]: https://www.xilinx.com/zcu102
[ZCU104]: https://www.xilinx.com/zcu104
[ZCU106]: https://www.xilinx.com/zcu106
[ZCU216]: https://www.xilinx.com/zcu216

