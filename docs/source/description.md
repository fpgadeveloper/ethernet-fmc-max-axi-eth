# Description

In this reference design, each of the four Gigabit Ethernet ports of the [Ethernet FMC Max]
is connected to an AXI 1G/2.5G Ethernet Subsystem IP (tri-mode MAC with SGMII PCS/PMA,
operating at 10/100/1000 Mb/s), which is connected to the system memory via an AXI DMA IP.
The PHYs on the Ethernet FMC Max (TI DP83867) connect to the FPGA over SGMII, one FMC gigabit
transceiver lane per port.

![AXI Ethernet design block diagram](images/axi-eth-block-diagram.png)

The [Hardware design](design) page describes the block design of each device family
(Zynq UltraScale+, Versal, MicroBlaze) in detail: clocks, shared logic, MDIO and PHY
addresses, resets and interrupts.

## Hardware Platforms

The hardware designs provided in this reference are based on Vivado and support a range of FPGA, MPSoC and ACAP evaluation
boards. The repository contains all necessary scripts and code to build these designs for the supported platforms listed below:

{% for group in data.groups %}
    {% set designs_in_group = [] %}
    {% for design in data.designs %}
        {% if design.group == group.label and design.publish %}
            {% set _ = designs_in_group.append(design.label) %}
        {% endif %}
    {% endfor %}
    {% if designs_in_group | length > 0 %}
### {{ group.name }} platforms

| Target board        | FMC Slot Used | Supported<br>Num. Ports   | Standalone<br> Echo Server | PetaLinux | Yocto |
|---------------------|---------------|---------|-----|-----|-----|
{% for design in data.designs %}{% if design.group == group.label and design.publish %}| [{{ design.board }}]({{ design.link }}) | {{ design.connector }} | {{ design.lanes | length }}x | {% if design.baremetal %} ✅ {% else %} ❌ {% endif %} | {% if design.petalinux %} ✅ {% else %} ❌ {% endif %} | {% if design.yocto %} ✅ {% else %} ❌ {% endif %} |
{% endif %}{% endfor %}
{% endif %}
{% endfor %}

## Software

These reference designs can be driven by a standalone (bare-metal) application or by embedded
Linux, built with either PetaLinux or Yocto (the AMD Embedded Development Framework, EDF). The
repository includes all necessary scripts and code to build each of them. The table below
outlines the applications available in each environment:

| Environment      | Available Applications  | Guide |
|------------------|-------------------------|-------|
| Standalone       | lwIP Echo Server (one port at a time) | [Stand-alone lwIP Echo Server](echo_server) |
| PetaLinux        | Built-in Linux commands<br>Additional tools: ethtool, phytool, iperf3 | [PetaLinux](petalinux) |
| Yocto (EDF)      | Built-in Linux commands, OpenSSH server<br>Additional tools: ethtool, phytool, iperf3, mtd-utils, can-utils, nfs-utils, pciutils | [Yocto](yocto) |

How to bring the ports up and measure them under Linux (either flow) is described in
[Using and testing the ports in Linux](linux_testing).

[Ethernet FMC Max]: https://docs.opsero.com/op080/datasheet/overview/
