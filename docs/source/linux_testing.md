# Using and testing the ports in Linux

This page applies to both Linux flows ([PetaLinux](petalinux) and [Yocto](yocto)). It shows how
to identify the Ethernet FMC Max ports, bring them up, check the link, and measure throughput
against a PC. The commands are shown for the Yocto image, which logs in as the non-root
`amd-edf` user and therefore uses `sudo`; in PetaLinux the same commands work (drop `sudo` when
logged in as root).

## What you need

* The board booted into Linux with the [Ethernet FMC Max] fitted (see [PetaLinux](petalinux)
  or [Yocto](yocto)).
* A UART terminal on the board's USB-UART (115200 baud, 8N1).
* One or more Ethernet cables from the FMC ports to a PC with a Gigabit Ethernet NIC, or to a
  switch/router on the same network as the PC.
* `iperf3` on the PC (`sudo apt install iperf3` on Ubuntu/Debian; Windows builds are available
  from the iperf3 project). `iperf3`, `ethtool` and `phytool` are already in the board images.

## Identify the ports

Linux renames the network interfaces to predictable `endN` names early in boot (`renamed from
ethN` in the kernel log). The `N` is assigned in probe order and **does not follow the FMC port
number**, and it differs between targets and between the PetaLinux and Yocto images. The
reliable way to identify a port is its MAC address, its controller base address, or its PHY
address in the kernel log:

```
ip -br link
dmesg | grep -E "axienet|macb" | grep -E "renamed|PHY \["
```

| Ethernet FMC Max port | MAC address         | PHY in the kernel log          |
|-----------------------|---------------------|--------------------------------|
| Port 0                | `00:0a:35:00:01:22` | `axienet-<base>:01`            |
| Port 1                | `00:0a:35:00:01:23` | `axienet-<base>:03`            |
| Port 2                | `00:0a:35:00:01:24` | `axienet-<base>:0c`            |
| Port 3                | `00:0a:35:00:01:25` | `axienet-<base>:0f`            |

`<base>` is the address of `axi_ethernet_0`, because all four PHYs sit on its MDIO bus. The
board's own RJ45 (a PS GEM, driver `macb`) also appears in the list.

Example from the Yocto image on a ZCU106 (`zcu106_hpc0`), cables on FMC ports 0 and 3 and on the
board's RJ45:

```
$ ip -br link | grep ^e
end4             UP             00:0a:35:06:21:07 <BROADCAST,MULTICAST,UP,LOWER_UP>
end3             UP             00:0a:35:00:01:22 <BROADCAST,MULTICAST,UP,LOWER_UP>
end0             DOWN           00:0a:35:00:01:23 <NO-CARRIER,BROADCAST,MULTICAST,UP>
end1             DOWN           00:0a:35:00:01:24 <NO-CARRIER,BROADCAST,MULTICAST,UP>
end2             UP             00:0a:35:00:01:25 <BROADCAST,MULTICAST,UP,LOWER_UP>
$ dmesg | grep "PHY \["
macb ff0e0000.ethernet end4: PHY [ff0e0000.ethernet-ffffffff:0c] driver [TI DP83867] (irq=POLL)
xilinx_axienet a0000000.ethernet end3: PHY [axienet-a0000000:01] driver [TI DP83867] (irq=POLL)
xilinx_axienet a0080000.ethernet end0: PHY [axienet-a0000000:03] driver [TI DP83867] (irq=POLL)
xilinx_axienet a00c0000.ethernet end1: PHY [axienet-a0000000:0c] driver [TI DP83867] (irq=POLL)
xilinx_axienet a0100000.ethernet end2: PHY [axienet-a0000000:0f] driver [TI DP83867] (irq=POLL)
```

With the Yocto images the four-port Zynq UltraScale+ targets (ZCU102 HPC0/HPC1, ZCU106) come up
with this mapping:

| Interface | Device                                     |
|-----------|--------------------------------------------|
| `end3`    | Ethernet FMC Max port 0 (`a0000000`)       |
| `end0`    | Ethernet FMC Max port 1 (`a0080000`)       |
| `end1`    | Ethernet FMC Max port 2 (`a00c0000`)       |
| `end2`    | Ethernet FMC Max port 3 (`a0100000`)       |
| `end4`    | Board RJ45 (PS GEM3, `ff0e0000`)           |

and on the ZCU104 (one FMC port) `end0` is FMC port 0 and `end1` is the board RJ45. For the
PetaLinux mapping see [Port configurations](petalinux.md#port-configurations). On other targets,
use the commands above.

## Bring a port up

### DHCP

In the **Yocto** image every Ethernet interface is managed by `systemd-networkd` and requests a
DHCP address as soon as it has a link: plug the cable into a network with a DHCP server and the
address appears in `ip -br addr`. In **PetaLinux**, request an address by hand:

```
sudo udhcpc -i end3
```

### Static IP address

For a direct cable to a PC (no DHCP server), give the board port and the PC NIC addresses on the
same subnet, for example board `192.168.10.10/24`, PC `192.168.10.1/24`:

```
sudo ip link set end3 up
sudo ip addr add 192.168.10.10/24 dev end3
ip -br addr show end3
```

If you use several ports at the same time, see
[Multiple ports on one network](#multiple-ports-on-one-network) below.

## Check the link

`ethtool` shows the negotiated speed and the link state:

```
$ sudo ethtool end3 | grep -E 'Speed|Duplex|Auto-negotiation|Link detected'
	Speed: 1000Mb/s
	Duplex: Full
	Auto-negotiation: on
	Link detected: yes
```

The kernel also logs every link change:

```
xilinx_axienet a0000000.ethernet end3: Link is Up - 1Gbps/Full - flow control off
```

`phytool` reads the PHY registers directly over MDIO. Pass the interface name and the PHY's MDIO
address (1, 3, 12 or 15 for ports 0 to 3); for example, to decode the IEEE registers of the
port 0 PHY:

```
sudo phytool print end3/1
```

## Speed negotiation

The DP83867 PHYs and the tri-mode MACs support 10, 100 and 1000 Mb/s, full and half duplex, and
negotiate the speed with the link partner automatically (the AXI Ethernet core follows the speed
the PHY reports over SGMII). To test a lower speed, restrict what the port advertises and let it
re-negotiate:

```
sudo ethtool -s end3 speed 100 duplex full autoneg on    # advertise 100 Mb/s only
sudo ethtool end3 | grep Speed
sudo ethtool -s end3 speed 1000 duplex full autoneg on   # back to 1 Gb/s
```

The link partner must support the speed you select; the result is visible in the `Link is Up`
kernel message and in `ethtool`.

## Ping

```
ping -c 5 -I end3 192.168.10.1
```

`-I` makes the ping leave through that interface, which matters when several ports are up.

## Throughput with iperf3

Start an iperf3 server on the PC:

```
iperf3 -s
```

Then, on the board, run a 10 second test in each direction through the port under test
(`--bind-dev` forces the traffic through that interface):

```
iperf3 -c <pc-ip> --bind-dev end3 -t 10        # board transmits
iperf3 -c <pc-ip> --bind-dev end3 -t 10 -R     # board receives
```

The relevant figure is the `receiver` line at the end of each run. The table below lists
results measured with the Yocto images: one TCP stream, MTU 1500, link partner a PC with a
Gigabit Ethernet NIC.

| Target        | Port                      | Board transmits (Mbit/s) | Board receives (Mbit/s) |
|---------------|---------------------------|--------------------------|-------------------------|
| `zcu102_hpc0` | FMC port 0                | 941                      | 886                     |
| `zcu102_hpc0` | FMC port 3                | 941                      | 919                     |
| `zcu102_hpc1` | FMC port 0                | 941                      | 934                     |
| `zcu102_hpc1` | FMC port 3                | 941                      | 923                     |
| `zcu104`      | FMC port 0                | 941                      | 851                     |
| `zcu106_hpc0` | FMC port 0                | 941                      | 914                     |
| `zcu106_hpc0` | FMC port 3                | 941                      | 864                     |
| all of these  | Board RJ45 (PS GEM3)      | 941                      | 934                     |

941 Mbit/s is the maximum TCP throughput of Gigabit Ethernet at MTU 1500, so transmit runs at
line rate. The receive figure varies more from board to board and run to run; expect roughly
850 to 935 Mbit/s for a single stream. Pings showed no packet loss on any port. Lower results
usually come from the PC side (NIC, power saving, other traffic) or from a link that
negotiated below 1 Gb/s.

## Multiple ports on one network

When two or more ports are connected to the **same** subnet, Linux may answer ARP requests and
send replies through whichever interface it prefers, so traffic does not necessarily use the
port you intend. Either:

* bind each test to its interface (`ping -I endN`, `iperf3 --bind-dev endN`) and check the
  per-interface counters (`ip -s link show endN`) to confirm the traffic went through the port; or
* give each port its own subnet, e.g. `end3` = 192.168.1.10/24, `end0` = 192.168.2.10/24,
  `end1` = 192.168.3.10/24, `end2` = 192.168.4.10/24, with a matching PC NIC on each.

## If a port does not work

See [Troubleshooting](troubleshooting.md#ports-not-working).

[Ethernet FMC Max]: https://docs.opsero.com/op080/datasheet/overview/
