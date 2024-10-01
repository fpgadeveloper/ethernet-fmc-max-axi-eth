################################################################
# Block diagram build script
################################################################

# Check if IP exists in design
proc ip_exists {ip_name} {
    set cells [get_bd_cells -quiet $ip_name]
    return [llength $cells]
}

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

create_bd_design $block_name

current_bd_design $block_name

set parentCell [get_bd_cells /]

# Get object for parentCell
set parentObj [get_bd_cells $parentCell]
if { $parentObj == "" } {
   puts "ERROR: Unable to find parent cell <$parentCell>!"
   return
}

# Make sure parentObj is hier blk
set parentType [get_property TYPE $parentObj]
if { $parentType ne "hier" } {
   puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
   return
}

# Save current instance; Restore later
set oldCurInst [current_bd_instance .]

# Set parent object as current
current_bd_instance $parentObj

# SGMII PHY addresses
set sgmii_phy_addr {2 4 13 14}

# Add the Processor System and apply board preset
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]

# Configure the PS
# Enable the PL1 CLK 50MHz for AXI Ethernet ref_clk
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP1 {0} \
CONFIG.PSU__USE__S_AXI_GP2 {1} \
CONFIG.PSU__USE__IRQ0 {1} \
CONFIG.PSU__USE__IRQ1 {1} \
CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
CONFIG.PSU__TTC0__PERIPHERAL__IO {EMIO} \
CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {50.000} \
CONFIG.PSU__FPGA_PL1_ENABLE {1} \
] [get_bd_cells zynq_ultra_ps_e_0]

# AXI Eth ref_clk
set ref_clk "zynq_ultra_ps_e_0/pl_clk1"

# UltraZed-EV Carrier: Must use IOPLL clock source for the 50MHz clock (ref_clk)
# For reasons unknown, we have needed to source the 50MHz ref_clk from IOPLL (instead of RPLL) for the Ethernet
# ports to function correctly in PetaLinux.
# We found that the PL1 clock would not be set to the correct frequency in PetaLinux when sourced from RPLL.
#   - Verified using command: sudo cat /sys/kernel/debug/clk/pl1_ref/clk_rate
# The incorrect clock frequency leads to the SGMII PHYs responding to all reads with 0xFFFF, and link-up never
# being reached.
#   - Verified using command: sudo phytool read eth0/0x02/0x0000
# This problem did not affect baremetal applications (ie. using RPLL is fine in baremetal).
# This problem does not affect the Xilinx boards (ZCU102, ZCU106, ...).
# It is likely that the UltraZed-EV BSP changes the RPLL configuration, but this requires further examination.
if {$board_name == "ultrazed_7ev_cc"} {
  set_property -dict [list CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {IOPLL} ] [get_bd_cells zynq_ultra_ps_e_0]
}

# Connect the FCLK_CLK0 to the PS GP0 and HP0
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]

# Add the concat for the interrupts
set num_ints [expr {4 * [llength $ports]}]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat xlconcat_0
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
if { $num_ints > 8 } {
  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat xlconcat_1
  connect_bd_net [get_bd_pins xlconcat_1/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq1]
  set_property -dict [list CONFIG.NUM_PORTS {8}] [get_bd_cells xlconcat_0]
  set_property -dict [list CONFIG.NUM_PORTS [expr {$num_ints - 8}]] [get_bd_cells xlconcat_1]
} else {
  set_property -dict [list CONFIG.NUM_PORTS $num_ints] [get_bd_cells xlconcat_0]
}

# Add and configure AXI Ethernet IPs with AXI DMAs
set port_with_shared_logic [lindex $ports 0]
foreach port $ports {
  # Add the AXI Ethernet IPs
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet axi_ethernet_$port
  
  # Get the GT location
  set gt_loc [dict get $gt_loc_dict $target $port]

  # Get the SGMII PHY address
  set phy_addr [lindex $sgmii_phy_addr $port]

  # Configure the AXI Ethernet IP
  if {$port == $port_with_shared_logic} {
    set_property -dict [list CONFIG.PHYADDR $phy_addr \
                              CONFIG.PHY_TYPE {SGMII} \
                              CONFIG.gtlocation $gt_loc \
                              CONFIG.SupportLevel {1} \
                              ] [get_bd_cells axi_ethernet_$port]
    connect_bd_net [get_bd_pins $ref_clk] [get_bd_pins axi_ethernet_$port/ref_clk]
    # GT ref clock
    create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk
    set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_ports /gt_ref_clk]
    connect_bd_intf_net [get_bd_intf_pins axi_ethernet_$port/mgt_clk] [get_bd_intf_ports gt_ref_clk]
    # MDIO (only one shared MDIO bus)
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 mdio_io
    connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/mdio] [get_bd_intf_ports mdio_io]
  } else {
    set_property -dict [list CONFIG.PHYADDR $phy_addr \
                              CONFIG.PHY_TYPE {SGMII} \
                              CONFIG.gtlocation $gt_loc \
                              CONFIG.SupportLevel {0} \
                              ] [get_bd_cells axi_ethernet_$port]
    connect_bd_net [get_bd_pins $ref_clk] [get_bd_pins axi_ethernet_$port/ref_clk]
    # Shared clocks
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/gtref_clk_out] [get_bd_pins axi_ethernet_$port/gtref_clk]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/rxuserclk_out] [get_bd_pins axi_ethernet_$port/rxuserclk]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/rxuserclk2_out] [get_bd_pins axi_ethernet_$port/rxuserclk2]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/userclk_out] [get_bd_pins axi_ethernet_$port/userclk]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/userclk2_out] [get_bd_pins axi_ethernet_$port/userclk2]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/pma_reset_out] [get_bd_pins axi_ethernet_$port/pma_reset]
    connect_bd_net [get_bd_pins axi_ethernet_$port_with_shared_logic/mmcm_locked_out] [get_bd_pins axi_ethernet_$port/mmcm_locked]
  }
  
  # Add the DMA for the AXI Ethernet Subsystem
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma axi_ethernet_${port}_dma
  
  # Must enable unaligned transfers in the DMAs or we get this error in Echo server: "Error set buf addr 201116 with 4 and 3, 2"
  set_property -dict [list CONFIG.c_include_mm2s_dre {1} CONFIG.c_include_s2mm_dre {1}] [get_bd_cells axi_ethernet_${port}_dma]
  
  # Connect AXI streaming interfaces
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/m_axis_rxd] [get_bd_intf_pins axi_ethernet_${port}_dma/S_AXIS_S2MM]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/m_axis_rxs] [get_bd_intf_pins axi_ethernet_${port}_dma/S_AXIS_STS]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/s_axis_txd] [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXIS_MM2S]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/s_axis_txc] [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXIS_CNTRL]

  # Connect clocks for AXI Ethernet Subsystem
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}/axis_clk]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}/s_axi_lite_clk]

  # Connect clocks for AXI DMA
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}_dma/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}_dma/m_axi_sg_aclk]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}_dma/m_axi_mm2s_aclk]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_ethernet_${port}_dma/m_axi_s2mm_aclk]

  # Connect resets between AXI DMA and Ethernet
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/mm2s_prmry_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_txd_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/mm2s_cntrl_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_txc_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/s2mm_prmry_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_rxd_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/s2mm_sts_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_rxs_arstn]

  # Use connection automation to connect AXI lite interfaces
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave "/axi_ethernet_${port}/s_axi" ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}/s_axi]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave "/axi_ethernet_${port}_dma/S_AXI_LITE" ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/S_AXI_LITE]
  
  # Use connection automation to connect AXI MM interfaces of the DMA
  if { [ip_exists "axi_smc"] == 0 } {
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc
    connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
    connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc/aclk]
    connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] [get_bd_pins axi_smc/aresetn]
  }
  
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_MM2S" Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_MM2S]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_S2MM" Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_S2MM]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_SG" Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_SG]

  # Make AXI Ethernet ports external: SGMII and RESET
  # SGMII
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:sgmii_rtl:1.0 sgmii_port_${port}
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/sgmii] [get_bd_intf_ports sgmii_port_${port}]
  # RESET
  create_bd_port -dir O -type rst reset_port_${port}
  connect_bd_net [get_bd_pins /axi_ethernet_${port}/phy_rst_n] [get_bd_ports reset_port_${port}]

  # Include segment HP0_FPS_OCM
  include_bd_addr_seg [get_bd_addr_segs -excluded axi_ethernet_${port}_dma/Data_SG/SEG_zynq_ultra_ps_e_0_HP0_LPS_OCM]
  include_bd_addr_seg [get_bd_addr_segs -excluded axi_ethernet_${port}_dma/Data_MM2S/SEG_zynq_ultra_ps_e_0_HP0_LPS_OCM]
  include_bd_addr_seg [get_bd_addr_segs -excluded axi_ethernet_${port}_dma/Data_S2MM/SEG_zynq_ultra_ps_e_0_HP0_LPS_OCM]
}

# signal_detect tied HIGH
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_signal_detect
set_property CONFIG.CONST_VAL {1} [get_bd_cells const_signal_detect]
foreach port $ports {
  connect_bd_net [get_bd_pins const_signal_detect/dout] [get_bd_pins axi_ethernet_${port}/signal_detect]
}

# Connect AXI DMA and AXI Ethernet interrupts
set int_index 0
set concat_index 0
foreach port $ports {
  connect_bd_net [get_bd_pins axi_ethernet_${port}/mac_irq] [get_bd_pins xlconcat_${concat_index}/In${int_index}]
  incr int_index
  connect_bd_net [get_bd_pins axi_ethernet_${port}/interrupt] [get_bd_pins xlconcat_${concat_index}/In${int_index}]
  incr int_index
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/mm2s_introut] [get_bd_pins xlconcat_${concat_index}/In${int_index}]
  incr int_index
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/s2mm_introut] [get_bd_pins xlconcat_${concat_index}/In${int_index}]
  incr int_index
  if { $int_index == 8 } {
    set int_index 0
    incr concat_index
  }
}

# Add the AXI GPIO for the power good and PHY GPIO signals
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0
set_property -dict [list \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_GPIO_WIDTH {10} \
] [get_bd_cells axi_gpio_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Clk_slave {Auto} Clk_xbar {/zynq_ultra_ps_e_0/pl_clk0 (99 MHz)} Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {/ps8_0_axi_periph} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 gpio
connect_bd_intf_net [get_bd_intf_pins axi_gpio_0/GPIO] [get_bd_intf_ports gpio]

# Restore current instance
current_bd_instance $oldCurInst

save_bd_design
