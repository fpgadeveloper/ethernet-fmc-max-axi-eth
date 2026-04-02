################################################################
# Block diagram build script for MicroBlaze designs
################################################################

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

# Returns true if str contains substr
proc str_contains {str substr} {
  if {[string first $substr $str] == -1} {
    return 0
  } else {
    return 1
  }
}

# Target board checks
set is_auboard [str_contains $board_name "auboard"]
set is_kcu105 [str_contains $board_name "kcu105"]
set is_vcu108 [str_contains $board_name "vcu108"]
set is_vcu118 [str_contains $board_name "vcu118"]

# SGMII PHY addresses
set sgmii_phy_addr {2 4 13 14}

# Initialize the list of unused ports
set unused_ports {}

# Work out which ports of the Quad SFP28 FMC are not used in this design
foreach port {0 1 2 3} {
    # Check if the current port is not in the ports list
    if { [lsearch -exact $ports $port] == -1 } {
        # Add the port to the unused_ports list
        lappend unused_ports $port
    }
}

# AXI Lite ports
set periph_ports {}

# List of interrupt pins (AXI Intc)
set intr_list {}

# Add the Memory controller (MIG) for the DDR4
create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4 ddr4_0

# Connect MIG external interfaces
if {$is_kcu105} {
  apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {default_sysclk_300 ( 300 MHz System differential clock ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram_062 ( DDR4 SDRAM ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_DDR4]
  # Add the 50MHz additional clock output for Quad SPI clock
  set_property -dict [list CONFIG.ADDN_UI_CLKOUT2_FREQ_HZ {50}] [get_bd_cells ddr4_0]
}
if {$is_vcu108} {
  apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram_c1_062 ( DDR4 SDRAM C1 ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_DDR4]

  # DDR4 clock buffer (see https://www.xilinx.com/support/answers/65263.html)
  create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf util_ds_buf_0
  apply_board_connection -board_interface "default_sysclk1_300" -ip_intf "/util_ds_buf_0/CLK_IN_D" -diagram "$block_name"
  connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins ddr4_0/c0_sys_clk_i]
}
if {$is_vcu118} {
  apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {default_250mhz_clk1 ( 250 MHz System differential clock1 ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr4_sdram_c1_062 ( DDR4 SDRAM C1 ) } Manual_Source {Auto}}  [get_bd_intf_pins ddr4_0/C0_DDR4]
}

# Board FPGA reset
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {New External Port (ACTIVE_HIGH)}}  [get_bd_pins ddr4_0/sys_rst]

# Add the Microblaze
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze microblaze_0
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { axi_intc {1} axi_periph {Enabled} cache {64KB} clk {/ddr4_0/addn_ui_clkout1 (100 MHz)} cores {1} debug_module {Debug Only} ecc {None} local_mem {64KB} preset {None}}  [get_bd_cells microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/ddr4_0/addn_ui_clkout1 (100 MHz)} Clk_slave {/ddr4_0/c0_ddr4_ui_clk (300 MHz)} Clk_xbar {Auto} Master {/microblaze_0 (Cached)} Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]

# Configure MicroBlaze for Linux
set_property -dict [list CONFIG.G_TEMPLATE_LIST {4} \
CONFIG.G_USE_EXCEPTIONS {1} \
CONFIG.C_USE_MSR_INSTR {1} \
CONFIG.C_USE_PCMP_INSTR {1} \
CONFIG.C_USE_BARREL {1} \
CONFIG.C_USE_DIV {1} \
CONFIG.C_USE_HW_MUL {2} \
CONFIG.C_UNALIGNED_EXCEPTIONS {1} \
CONFIG.C_ILL_OPCODE_EXCEPTION {1} \
CONFIG.C_M_AXI_I_BUS_EXCEPTION {1} \
CONFIG.C_M_AXI_D_BUS_EXCEPTION {1} \
CONFIG.C_DIV_ZERO_EXCEPTION {1} \
CONFIG.C_PVR {2} \
CONFIG.C_OPCODE_0x0_ILLEGAL {1} \
CONFIG.C_ICACHE_LINE_LEN {8} \
CONFIG.C_ICACHE_VICTIMS {8} \
CONFIG.C_ICACHE_STREAMS {1} \
CONFIG.C_DCACHE_VICTIMS {8} \
CONFIG.C_USE_MMU {3} \
CONFIG.C_MMU_ZONES {2}] [get_bd_cells microblaze_0]

# Connect 100MHz processor system reset external reset to the reset port
connect_bd_net [get_bd_ports reset] [get_bd_pins rst_ddr4_0_100M/ext_reset_in]

# AXI Eth ref_clk 50MHz for SGMII UltraScale/UltraScale+/Versal
set ref_clk "ddr4_0/addn_ui_clkout2"

# System clock 100MHz (AXI4 and AXIS interfaces)
set sys_clk "ddr4_0/addn_ui_clkout1"

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
  # SGMII and Full checksum offload in all cases
  if {$port == $port_with_shared_logic} {
    set_property -dict [list CONFIG.PHYADDR $phy_addr \
                              CONFIG.PHY_TYPE {SGMII} \
                              CONFIG.RXCSUM {Full} CONFIG.TXCSUM {Full} \
                              CONFIG.gtlocation $gt_loc \
                              CONFIG.SupportLevel {1} \
                              CONFIG.USE_BOARD_FLOW {false} \
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
            CONFIG.RXCSUM {Full} CONFIG.TXCSUM {Full} \
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
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}/axis_clk]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}/s_axi_lite_clk]

  # Connect clocks for AXI DMA
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}_dma/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}_dma/m_axi_sg_aclk]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}_dma/m_axi_mm2s_aclk]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_ethernet_${port}_dma/m_axi_s2mm_aclk]

  # Connect resets between AXI DMA and Ethernet
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/mm2s_prmry_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_txd_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/mm2s_cntrl_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_txc_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/s2mm_prmry_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_rxd_arstn]
  connect_bd_net [get_bd_pins axi_ethernet_${port}_dma/s2mm_sts_reset_out_n] [get_bd_pins axi_ethernet_${port}/axi_rxs_arstn]

  # Use connection automation to connect AXI lite interfaces
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master "/${sys_clk} (100 MHz)" Clk_slave "/${sys_clk} (100 MHz)" Clk_xbar "/${sys_clk} (100 MHz)" Master {/microblaze_0 (Periph)} Slave "/axi_ethernet_${port}/s_axi" ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}/s_axi]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master "/${sys_clk} (100 MHz)" Clk_slave "/${sys_clk} (100 MHz)" Clk_xbar "/${sys_clk} (100 MHz)" Master {/microblaze_0 (Periph)} Slave "/axi_ethernet_${port}_dma/S_AXI_LITE" ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/S_AXI_LITE]
  
  # Use connection automation to connect AXI MM interfaces of the DMA
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_MM2S" Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_MM2S]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_S2MM" Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_S2MM]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master "/axi_ethernet_${port}_dma/M_AXI_SG" Slave {/ddr4_0/C0_DDR4_S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_SG]

  # Make AXI Ethernet ports external: SGMII and RESET
  # SGMII
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:sgmii_rtl:1.0 sgmii_port_${port}
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/sgmii] [get_bd_intf_ports sgmii_port_${port}]
  # RESET
  create_bd_port -dir O -type rst reset_port_${port}
  connect_bd_net [get_bd_pins /axi_ethernet_${port}/phy_rst_n] [get_bd_ports reset_port_${port}]

  # Append Interrupts to the intr list
  lappend intr_list "axi_ethernet_${port}/interrupt"
  lappend intr_list "axi_ethernet_${port}/mac_irq"
  lappend intr_list "axi_ethernet_${port}_dma/mm2s_introut"
  lappend intr_list "axi_ethernet_${port}_dma/s2mm_introut"
}

# Correctly tie off the unused ports
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_low
set_property CONFIG.CONST_VAL {0} [get_bd_cells const_low]
foreach port $unused_ports {
  # PHY RESET - hold LOW - keep unused PHYs in reset
  create_bd_port -dir O -type rst reset_port_${port}
  connect_bd_net [get_bd_pins const_low/dout] [get_bd_ports reset_port_${port}]
}

# signal_detect tied HIGH
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_signal_detect
set_property CONFIG.CONST_VAL {1} [get_bd_cells const_signal_detect]
foreach port $ports {
  connect_bd_net [get_bd_pins const_signal_detect/dout] [get_bd_pins axi_ethernet_${port}/signal_detect]
}

# Connect the interrupts to AXI Intc(max 32 interrupts)
set n_interrupts [llength $intr_list]
set intr_concat [get_bd_cells "microblaze_0_xlconcat"]
set_property -dict [list CONFIG.NUM_PORTS $n_interrupts] $intr_concat
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins ${intr_concat}/In$intr_index]
  set intr_index [expr {$intr_index+1}]
}

# Add the AXI GPIO for the power good and PHY GPIO signals
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0
set_property -dict [list \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_GPIO_WIDTH {10} \
] [get_bd_cells axi_gpio_0]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_ddr4_0_100M/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/microblaze_0 (Periph)} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 gpio
connect_bd_intf_net [get_bd_intf_pins axi_gpio_0/GPIO] [get_bd_intf_ports gpio]

# Assign addresses
assign_bd_address

# Restore current instance
current_bd_instance $oldCurInst

save_bd_design
