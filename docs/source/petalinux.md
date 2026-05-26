# PetaLinux

PetaLinux can be built for these reference designs by using the Makefile in the `PetaLinux` directory
of the repository.

## Requirements

To build the PetaLinux projects, you will need a physical or virtual machine running one of the 
[supported Linux distributions] as well as the Vitis Core Development Kit installed.

```{attention} You cannot build the PetaLinux projects in the Windows operating system. Windows
users are advised to use a Linux virtual machine to build the PetaLinux projects.
```

## How to build

1. From a command terminal, clone the Git repository and `cd` into it.
   ```
   git clone https://github.com/fpgadeveloper/ethernet-fmc-max-axi-eth.git
   cd ethernet-fmc-max-axi-eth
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2025.2/settings.sh
   ```
3. Launch Vivado by sourcing the `settings64.sh` bash script, eg:
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   ```
4. Build the Vivado and PetaLinux project for your specific target platform by running the following
   commands and replacing `<target>` with one of the target labels listed in the target designs table
   in the build instructions.
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   
The last command will launch the build process for the corresponding Vivado project if that project
has not already been built and it's hardware exported.

## Boot a MicroBlaze design (auboard, kcu105_hpc, vcu118_fmcp)

The MicroBlaze designs do not boot from SD; instead the PetaLinux build
packages `images/linux/boot.mcs`, which is programmed into the board's QSPIx4
flash. The kernel uses an initramfs root, so no SD card is needed. See
`PetaLinux/Makefile` (flash-size column) for the per-board flash size
(32 MB on KCU105, 64 MB on AUBoard, 128 MB on VCU118).

The simplest way to bring one of these targets up the first time is via JTAG;
see [Boot via JTAG](#boot-via-jtag) below. For production flashing,
program `boot.mcs` into QSPI using Vivado's Hardware Manager.

## Boot from SD card (Zynq UltraScale+ and Versal)

### Prepare the SD card

Once the build process is complete, you must prepare the SD card for booting PetaLinux.

1. The SD card must first be prepared with two partitions: one for the boot files and another 
   for the root file system.

   * Plug the SD card into your computer and find it's device name using the `dmesg` command.
     The SD card should be found at the end of the log, and it's device name should be something
     like `/dev/sdX`, where `X` is a letter such as a,b,c,d, etc. Note that you should replace
     the `X` in the following instructions.
     
```{warning} Do not continue these steps until you are certain that you have found the correct
device name for the SD card. If you use the wrong device name in the following steps, you risk
losing data on one of your hard drives.
```
   * Run `fdisk` by typing the command `sudo fdisk /dev/sdX`
   * Make the `boot` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number and first sector. For the last sector, type 
     `+1G` to allocate 1GB to this partition.
   * Make the `boot` partition bootable by typing `a`
   * Make the `root` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number, first sector and last sector.
   * Save the partition table by typing `w`
   * Format the `boot` partition (FAT32) by typing `sudo mkfs.vfat -F 32 -n boot /dev/sdX1`
   * Format the `root` partition (ext4) by typing `sudo mkfs.ext4 -L root /dev/sdX2`

2. Copy the following files to the `boot` partition of the SD card:
   Assuming the `boot` partition was mounted to `/media/user/boot`, follow these instructions:
   ```
   $ cd /media/user/boot/
   $ sudo cp /<petalinux-project>/images/linux/BOOT.BIN .
   $ sudo cp /<petalinux-project>/images/linux/boot.scr .
   $ sudo cp /<petalinux-project>/images/linux/image.ub .
   ```

3. Create the root file system by extracting the `rootfs.tar.gz` file to the `root` partition.
   Assuming the `root` partition was mounted to `/media/user/root`, follow these instructions:
   ```
   $ cd /media/user/root/
   $ sudo cp /<petalinux-project>/images/linux/rootfs.tar.gz .
   $ sudo tar xvf rootfs.tar.gz -C .
   $ sync
   ```
   
   Once the `sync` command returns, you will be able to eject the SD card from the machine.

### Boot PetaLinux

1. Plug the SD card into your target board.
2. Ensure that the target board is configured to boot from SD card:
   * **VCK190, VMK180, VEK280, VPK120:** DIP switch SW1 is set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
   * **UltraZed-EV:** DIP switch SW2 (on the SoM) is set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
   * **ZCU102, ZCU104, ZCU106, ZCU111:** DIP switch SW6 must be set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
   * **ZCU208, ZCU216:** DIP switch SW2 must be set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
3. Connect the [Ethernet FMC Max] to the FMC connector of the target board.
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.
5. Connect and power your hardware.

## Boot via JTAG

```{tip} You need to install the cable drivers before being able to boot via JTAG.
Note that the Vitis installer does not automatically install the cable drivers, it must be done separately.
For instructions, read section 
[installing the cable drivers](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Installing-Cable-Drivers) 
from the Vivado release notes.
```

```{warning} If you boot the Zynq UltraScale+ or Zynq RFSoC designs via JTAG, you must still
first prepare the SD card. The reason is because these designs are configured to use the SD card to store
the root filesystem. If you boot these designs via JTAG without preparing and connecting the SD card, the
boot will hang at a message similar to this: `Waiting for root device /dev/mmcblk0p2...`
The Versal and MicroBlaze designs use an initramfs root and do not require the SD card to boot.
```

### Setup hardware

1. For Zynq UltraScale+ and RFSoC targets, prepare the SD card according to
   the [instructions above](#prepare-the-sd-card) and plug it into the
   target board. The Versal and MicroBlaze designs use an initramfs root
   and do not require an SD card for JTAG boot.
2. Ensure that the target board is configured to boot from JTAG:
   * **VCK190, VMK180, VEK280, VPK120:** DIP switch SW1 is set to 1111 (1=ON,2=ON,3=ON,4=ON)
   * **UltraZed-EV:** DIP switch SW2 (on the SoM) is set to 1111 (1=ON,2=ON,3=ON,4=ON)
   * **ZCU102, ZCU104, ZCU106, ZCU111:** DIP switch SW6 must be set to 1111 (1=ON,2=ON,3=ON,4=ON)
   * **ZCU208, ZCU216:** DIP switch SW2 must be set to 1111 (1=ON,2=ON,3=ON,4=ON)
   * **AUBoard, KCU105, VCU118:** MicroBlaze targets boot via JTAG by
     default once the bitstream is loaded; no boot-mode switch needs to
     change. (For long-term standalone operation, program `boot.mcs`
     into the on-board SPIx4 flash.)
3. Connect the [Ethernet FMC Max] to the FMC connector of the target board.
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.
5. Connect and power your hardware.

### Boot PetaLinux

To boot PetaLinux on hardware via JTAG, use the following commands in a Linux command terminal:

1. Change current directory to the PetaLinux project directory for your target design:
   ```
   cd <project-dir>/PetaLinux/<target>
   ```
2. Download bitstream to the FPGA:
   ```
   petalinux-boot --jtag --kernel --fpga
   ```

An explanation of the above command is provided by the `petalinux-boot` command:
```none
For microblaze, it will download the bitstream to target board, and
then boot the kernel image on target board.
For Zynq, it will download the bitstream and FSBL to target board,
and then boot the u-boot and then the kernel on target
board.
For Zynq UltraScale+, it will download the bitstream, PMUFW and FSBL,
and then boot the kernel with help of linux-boot.elf to set kernel
start and dtb addresses.
```

## UART terminal

You will need to setup a terminal emulator to use the PetaLinux command line over the USB-UART connection.
Connect with a baud rate of 115200.

### In Windows

You will need to find the comport for the USB-UART in Windows Device Manager. As a terminal emulator, you
can use the open source and free [Putty](https://www.putty.org/).

### In Linux

In Linux, you can find the USB-UART device by running `dmesg | grep tty`. Typically, the device will be
`/dev/ttyUSB0` or it could be followed by a different number. To open a terminal emulator, you can use
the following command:

```
sudo screen /dev/ttyUSB0 115200
```

## Port configurations

PetaLinux 2025.2 renames the network interfaces from the legacy `ethN` names to
predictable `endN` names early in boot (you'll see `renamed from ethN` lines in
the kernel log). The `endN` mapping is what `ifconfig` and `ip link` will show.

The default interfaces table (`/etc/network/interfaces`) brings up `end0` at
boot, so it is convenient to wire `end0` to a DHCP-enabled link before powering
the board.

### Zynq UltraScale+ designs (uzev, zcu102, zcu106, zcu111, zcu208, zcu216)

Four-port variants (`ports-0123`):

* `end0`: Ethernet FMC Max Port 1 (PHY @ MDIO addr 3)
* `end1`: Ethernet FMC Max Port 2 (PHY @ MDIO addr 12)
* `end2`: Ethernet FMC Max Port 3 (PHY @ MDIO addr 15)
* `end3`: GEM3 onboard Ethernet port of the dev board
* `end4`: Ethernet FMC Max Port 0 (PHY @ MDIO addr 1, master MDIO bus)

### Zynq UltraScale+ single-port design (zcu104)

The ZCU104 routes only one Ethernet lane through its LPC FMC slot, so the
`ports-0xxx` overlay enables only Port 0:

* `end0`: GEM3 onboard Ethernet port of the dev board
* `end1`: Ethernet FMC Max Port 0 (PHY @ MDIO addr 1)

### Versal designs (vck190, vmk180, vek280, vhk158, vpk120, vpk180)

* `end0`: Ethernet FMC Max Port 0 (PHY @ MDIO addr 1, master MDIO bus)
* `end1`: Ethernet FMC Max Port 1 (PHY @ MDIO addr 3)
* `end2`: Ethernet FMC Max Port 2 (PHY @ MDIO addr 12)
* `end3`: Ethernet FMC Max Port 3 (PHY @ MDIO addr 15)
* `end4`: GEM0 onboard Ethernet port of the dev board
* `end5`: GEM1 onboard Ethernet port of the dev board (when wired)

The four FMC ports share a single MDIO bus rooted at `axi_ethernet_0`; the
remaining `axi_ethernet_N` nodes have `xlnx,has-mdio = <0x1>` but an empty
local MDIO node (see `PetaLinux/bsp/ports-0123/.../port-config.dtsi`).

## Example Usage

The examples below are from a ZCU102 PetaLinux session. On Versal the
interface names map differently — see the [Port configurations](#port-configurations)
section above.

### Enable port

This example will bring up a port.

```
root@zcu102-axieth-sgmii-2025-2:~# sudo ifconfig end4 up
[  228.274146] xilinx_axienet a0000000.ethernet end4: Link is Up - 1Gbps/Full - flow control off
[  228.282753] IPv6: ADDRCONF(NETDEV_CHANGE): end4: link becomes ready
```

### Enable port with fixed IP address

This example sets a fixed IP address to a port.

```
root@zcu102-axieth-sgmii-2025-2:~# sudo ifconfig end4 192.168.2.30 up
[  390.080498] net end4: Promiscuous mode disabled.
[  390.085406] net end4: Promiscuous mode disabled.
[  390.091089] xilinx_axienet a0000000.ethernet end4: Link is Down
[  394.175238] xilinx_axienet a0000000.ethernet end4: Link is Up - 1Gbps/Full - flow control off
[  394.183769] IPv6: ADDRCONF(NETDEV_CHANGE): end4: link becomes ready
```

### Enable port using DHCP

This example enables a port and obtains an IP address for the port via DHCP. Note that the
port must be connected to a DHCP enabled router.

```
root@zcu102-axieth-sgmii-2025-2:~# sudo udhcpc -i end4
udhcpc: started, v1.36.1
[   68.814013] xilinx_axienet a0000000.ethernet end4: Link is Up - 1Gbps/Full - flow control off
[   68.822670] IPv6: ADDRCONF(NETDEV_CHANGE): end4: link becomes ready
udhcpc: sending discover
udhcpc: sending select for 192.168.2.72
udhcpc: lease of 192.168.2.72 obtained, lease time 259200
/etc/udhcpc.d/50default: Adding DNS 192.168.2.1
```

### Check port status

In this example, we use the ``ifconfig`` command with no arguments to check the port status.
Trimmed excerpt — `end3` is the onboard GEM3 (not enabled), `end4` is Ethernet FMC Max
port 0 brought up at 192.168.2.30:

```
root@zcu102-axieth-sgmii-2025-2:~# ifconfig
end3      Link encap:Ethernet  HWaddr A6:D3:33:F0:90:3B
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
          Interrupt:50

end4      Link encap:Ethernet  HWaddr 00:0A:35:00:01:22
          inet addr:192.168.2.30  Bcast:192.168.2.255  Mask:255.255.255.0
          inet6 addr: fe80::20a:35ff:fe00:122/64 Scope:Link
          UP BROADCAST RUNNING  MTU:1500  Metric:1
          RX packets:38 errors:0 dropped:0 overruns:0 frame:0
          TX packets:26 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:6033 (5.8 KiB)  TX bytes:3302 (3.2 KiB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          ...
```

We can also use ``ethtool`` to check the port status as follows.

```
root@zcu102-axieth-sgmii-2025-2:~# ethtool end4
Settings for end4:
        Supported ports: [ TP MII FIBRE ]
        Supported link modes:   10baseT/Half 10baseT/Full
                                100baseT/Half 100baseT/Full
                                1000baseT/Half 1000baseT/Full
        Supported pause frame use: Symmetric Receive-only
        Supports auto-negotiation: Yes
        Supported FEC modes: Not reported
        Advertised link modes:  10baseT/Half 10baseT/Full
                                100baseT/Half 100baseT/Full
                                1000baseT/Half 1000baseT/Full
        Advertised pause frame use: No
        Advertised auto-negotiation: Yes
        Advertised FEC modes: Not reported
        Link partner advertised link modes:  10baseT/Half 10baseT/Full
                                             100baseT/Half 100baseT/Full
                                             1000baseT/Full
        Link partner advertised pause frame use: No
        Link partner advertised auto-negotiation: Yes
        Link partner advertised FEC modes: Not reported
        Speed: 1000Mb/s
        Duplex: Full
        Port: MII
        PHYAD: 0
        Transceiver: internal
        Auto-negotiation: on
        Link detected: yes
```

### Ping link partner using specific port

In this example we ping the link partner at IP address 192.168.2.98 from interface end4.

```
root@zcu102-axieth-sgmii-2025-2:~# ping -I end4 192.168.2.98
PING 192.168.2.98 (192.168.2.98): 56 data bytes
64 bytes from 192.168.2.98: seq=0 ttl=64 time=0.359 ms
64 bytes from 192.168.2.98: seq=1 ttl=64 time=0.199 ms
64 bytes from 192.168.2.98: seq=2 ttl=64 time=0.231 ms
64 bytes from 192.168.2.98: seq=3 ttl=64 time=0.161 ms
```


[Ethernet FMC Max]: https://docs.opsero.com/op080/datasheet/overview/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment

