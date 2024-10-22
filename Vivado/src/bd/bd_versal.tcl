################################################################
# Block design build script for Versal designs
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
set is_vck190 [str_contains $board_name "vck190"]
set is_vek280 [str_contains $board_name "vek280"]
set is_vhk158 [str_contains $board_name "vhk158"]
set is_vmk180 [str_contains $board_name "vmk180"]
set is_vpk120 [str_contains $board_name "vpk120"]
set is_vpk180 [str_contains $board_name "vpk180"]

# SGMII PHY addresses
set sgmii_phy_addr {2 4 13 14}

# Number of ports
set num_ports [llength $ports]

# List of interrupt pins
set intr_list {}

# Add the CIPS
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0

# Configure the CIPS using automation feature
if {$is_vpk120 || $is_vek280 || $is_vpk180} {
  apply_bd_automation -rule xilinx.com:bd_rule:cips -config { \
    board_preset {Yes} \
    boot_config {Custom} \
    configure_noc {Add new AXI NoC} \
    debug_config {JTAG} \
    design_flow {Full System} \
    mc_type {LPDDR} \
    num_mc_ddr {None} \
    num_mc_lpddr {1} \
    pl_clocks {None} \
    pl_resets {None} \
  }  [get_bd_cells versal_cips_0]
} else {
  apply_bd_automation -rule xilinx.com:bd_rule:cips -config { \
    board_preset {Yes} \
    boot_config {Custom} \
    configure_noc {Add new AXI NoC} \
    debug_config {JTAG} \
    design_flow {Full System} \
    mc_type {DDR} \
    num_mc_ddr {1} \
    num_mc_lpddr {None} \
    pl_clocks {None} \
    pl_resets {None} \
  }  [get_bd_cells versal_cips_0]
}

# Extra PS PMC config for this design
# -----------------------------------
# - Clocking -> Output clocks -> PMC domain clocks -> PL Fabric clocks -> PL CLK0: Enable 100MHz
# - Clocking -> Output clocks -> PMC domain clocks -> PL Fabric clocks -> PL CLK1: Enable 50MHz
# - PL resets: 1
# - M_AXI_LPD: enable
# - PL to PS interrupts: enable ALL (IRQ0-15)
if {$is_vpk120 || $is_vpk180} {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Sysmon temperature voltage and external IO monitoring} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {50} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_DATA_MODE {x4} \
      PMC_QSPI_PERIPHERAL_ENABLE {1} \
      PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_I2CSYSMON_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 39 .. 40}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PS_MIO 18} \
      PS_PCIE_EP_RESET2_IO {PS_MIO 19} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {1} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_INTERFACE_TO_USE {I2C} \
      SMON_PMBUS_ADDRESS {0x18} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
} elseif {$is_vek280} {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Sysmon temperature voltage and external IO monitoring} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {50} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_MIO12 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_I2CSYSMON_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 39 .. 40}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PS_MIO 18} \
      PS_PCIE_EP_RESET2_IO {PS_MIO 19} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {1} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      PS_USE_S_AXI_FPD {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_INTERFACE_TO_USE {I2C} \
      SMON_PMBUS_ADDRESS {0x18} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
} elseif {$is_vhk158} {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      DEVICE_INTEGRITY_MODE {Sysmon temperature voltage and external IO monitoring} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {50} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_MIO12 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_REF_CLK_FREQMHZ {33.333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x2A} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x25} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0 AUTODIR} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_I2CSYSMON_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 39 .. 40}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PS_MIO 18} \
      PS_PCIE_EP_RESET2_IO {PS_MIO 19} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {1} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_INTERFACE_TO_USE {I2C} \
      SMON_PMBUS_ADDRESS {0x18} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
} else {
  set_property -dict [list \
    CONFIG.CLOCK_MODE {Custom} \
    CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
    CONFIG.PS_PMC_CONFIG { \
      CLOCK_MODE {Custom} \
      DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
      DEBUG_MODE {JTAG} \
      DESIGN_MODE {1} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_PL1_REF_CTRL_FREQMHZ {50} \
      PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
      PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
      PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_OSPI_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
      PMC_QSPI_COHERENCY {0} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_DATA_MODE {x4} \
      PMC_QSPI_PERIPHERAL_ENABLE {1} \
      PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
      PMC_REF_CLK_FREQMHZ {33.3333} \
      PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_COHERENCY {0} \
      PMC_SD1_DATA_TRANSFER_MODE {8Bit} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
      PMC_SD1_SLOT_TYPE {SD 3.0} \
      PMC_USE_PMC_NOC_AXI0 {1} \
      PS_BOARD_INTERFACE {ps_pmc_fixed_io} \
      PS_CAN1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 40 .. 41}}} \
      PS_CRL_CAN1_REF_CTRL_FREQMHZ {160} \
      PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
      PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
      PS_ENET1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 12 .. 23}}} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI0_MASTER {A72} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_HSDP_EGRESS_TRAFFIC {JTAG} \
      PS_HSDP_INGRESS_TRAFFIC {JTAG} \
      PS_HSDP_MODE {NONE} \
      PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
      PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
      PS_MIO19 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO21 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO7 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_MIO9 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL disable} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_PCIE_EP_RESET1_IO {PMC_MIO 38} \
      PS_PCIE_EP_RESET2_IO {PMC_MIO 39} \
      PS_PCIE_RESET {ENABLE 1} \
      PS_PL_CONNECTIVITY_MODE {Custom} \
      PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
      PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
      PS_USE_FPD_CCI_NOC {1} \
      PS_USE_FPD_CCI_NOC0 {1} \
      PS_USE_M_AXI_LPD {1} \
      PS_USE_NOC_LPD_AXI0 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      PS_USE_PMCPL_CLK1 {1} \
      PS_USE_PMCPL_CLK2 {0} \
      PS_USE_PMCPL_CLK3 {0} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] [get_bd_cells versal_cips_0]
}

# AXI Eth ref_clk (50MHz)
set ref_clk "versal_cips_0/pl1_ref_clk"

# System clock (100MHz)
set sys_clk "versal_cips_0/pl0_ref_clk"

# Add system clock and 4x3 input ports for the AXI DMAs to the NOC MC
set_property -dict [list CONFIG.NUM_CLKS {7} CONFIG.NUM_SI {18}] [get_bd_cells axi_noc_0]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S00_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S01_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S02_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_1 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S03_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S04_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S05_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S06_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S07_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_0 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S08_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_1 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S09_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_1 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S10_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_1 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S11_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S12_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S13_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_2 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S14_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S15_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S16_AXI]
set_property -dict [list CONFIG.CONNECTIONS {MC_3 {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}}] [get_bd_intf_pins /axi_noc_0/S17_AXI]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_noc_0/aclk6]
set noc_port_index 6

# Connect the AXI interface clocks
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins versal_cips_0/m_axi_lpd_aclk]

# Proc system reset for main clock
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_pl0
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins rst_pl0/slowest_sync_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins rst_pl0/ext_reset_in]

# AXI SmartConnect for AXI Lite interfaces
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc
set_property CONFIG.NUM_MI {2} [get_bd_cells axi_smc]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins axi_smc/aresetn]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_LPD] [get_bd_intf_pins axi_smc/S00_AXI]

# GT ref clock and utility buffer
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_ports /gt_ref_clk]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf util_ds_buf_0
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells util_ds_buf_0]
connect_bd_intf_net [get_bd_intf_ports gt_ref_clk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]

# GT Quad base (Transceiver wizard)
create_bd_cell -type ip -vlnv xilinx.com:ip:gt_quad_base gt_quad_base_0
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins gt_quad_base_0/GT_REFCLK0]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins gt_quad_base_0/apb3clk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins gt_quad_base_0/apb3presetn]

# APB Bridge
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge axi_apb_bridge_0
set_property CONFIG.C_APB_NUM_SLAVES {1} [get_bd_cells axi_apb_bridge_0]
connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_0/APB_M] [get_bd_intf_pins gt_quad_base_0/APB3_INTF]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_apb_bridge_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins axi_apb_bridge_0/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_apb_bridge_0/AXI4_LITE]

# Timer
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer axi_timer_0
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]
lappend intr_list "axi_timer_0/interrupt"

# SGMII (GT) interface
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 sgmii_port
connect_bd_intf_net [get_bd_intf_pins gt_quad_base_0/GT_Serial] [get_bd_intf_ports sgmii_port]

# Add and configure AXI Ethernet IPs with AXI DMAs
foreach port $ports {
  # BUFG GTs
  # rxuserclk
  create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_rxoutclk_${port}
  set_property CONFIG.FREQ_HZ {62500000} [get_bd_cells bufg_gt_rxoutclk_${port}]
  connect_bd_net [get_bd_pins bufg_gt_rxoutclk_${port}/usrclk] [get_bd_pins gt_quad_base_0/ch${port}_rxusrclk]
  connect_bd_net [get_bd_pins gt_quad_base_0/ch${port}_rxoutclk] [get_bd_pins bufg_gt_rxoutclk_${port}/outclk]
  # userclk
  create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_txoutclk_div2_${port}
  set_property CONFIG.FREQ_HZ {62500000} [get_bd_cells bufg_gt_txoutclk_div2_${port}]
  connect_bd_net [get_bd_pins bufg_gt_txoutclk_div2_${port}/usrclk] [get_bd_pins gt_quad_base_0/ch${port}_txusrclk]
  connect_bd_net [get_bd_pins gt_quad_base_0/ch${port}_txoutclk] [get_bd_pins bufg_gt_txoutclk_div2_${port}/outclk]
  # userclk2
  create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_txoutclk_${port}
  set_property CONFIG.FREQ_HZ {125000000} [get_bd_cells bufg_gt_txoutclk_${port}]
  connect_bd_net [get_bd_pins gt_quad_base_0/ch${port}_txoutclk] [get_bd_pins bufg_gt_txoutclk_${port}/outclk]

  # Add the AXI Ethernet IPs
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet axi_ethernet_$port
  
  # Get the SGMII PHY address
  set phy_addr [lindex $sgmii_phy_addr $port]

  # Configure the AXI Ethernet IP
  set_property -dict [list \
    CONFIG.PHYADDR $phy_addr \
    CONFIG.PHY_TYPE {SGMII} \
  ] [get_bd_cells axi_ethernet_${port}]

  # Connect the ref_clk
  connect_bd_net [get_bd_pins $ref_clk] [get_bd_pins axi_ethernet_${port}/ref_clk]

  if {$port == 0} {
    # MDIO (only one shared MDIO bus)
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 mdio_io
    connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}/mdio] [get_bd_intf_ports mdio_io]
  }

  # AXI Eth Interrupts
  lappend intr_list "axi_ethernet_${port}/interrupt"
  #lappend intr_list "axi_ethernet_${port}/mac_irq"
  
  # Connect clocks
  connect_bd_net [get_bd_pins bufg_gt_rxoutclk_${port}/usrclk] [get_bd_pins axi_ethernet_${port}/rxuserclk]
  connect_bd_net [get_bd_pins bufg_gt_rxoutclk_${port}/usrclk] [get_bd_pins axi_ethernet_${port}/rxuserclk2]
  connect_bd_net [get_bd_pins bufg_gt_txoutclk_div2_${port}/usrclk] [get_bd_pins axi_ethernet_${port}/userclk]
  connect_bd_net [get_bd_pins bufg_gt_txoutclk_${port}/usrclk] [get_bd_pins axi_ethernet_${port}/userclk2]

  # Resets
  connect_bd_net [get_bd_pins rst_pl0/peripheral_reset] [get_bd_pins axi_ethernet_${port}/pma_reset]

  # Connect Quad to AXI Eth
  connect_bd_net [get_bd_pins gt_quad_base_0/ch${port}_rxprogdivresetdone] [get_bd_pins axi_ethernet_${port}/gtwiz_reset_rx_done_in]
  connect_bd_net [get_bd_pins gt_quad_base_0/ch${port}_txprogdivresetdone] [get_bd_pins axi_ethernet_${port}/gtwiz_reset_tx_done_in]
  connect_bd_net [get_bd_pins gt_quad_base_0/gtpowergood] [get_bd_pins axi_ethernet_${port}/gtpowergood_in]
  connect_bd_intf_net [get_bd_intf_pins gt_quad_base_0/RX${port}_GT_IP_Interface] [get_bd_intf_pins axi_ethernet_${port}/gt_rx_interface]
  connect_bd_intf_net [get_bd_intf_pins gt_quad_base_0/TX${port}_GT_IP_Interface] [get_bd_intf_pins axi_ethernet_${port}/gt_tx_interface]
  connect_bd_net [get_bd_pins gt_quad_base_0/hsclk0_lcplllock] [get_bd_pins axi_ethernet_${port}/cplllock_in]

  # Add the DMA for the AXI Ethernet Subsystem
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma axi_ethernet_${port}_dma
  
  # Must enable unaligned transfers in the DMAs or we get this error in Echo server: "Error set buf addr 201116 with 4 and 3, 2"
  set_property -dict [list CONFIG.c_include_mm2s_dre {1} \
                            CONFIG.c_include_s2mm_dre {1} \
                            CONFIG.c_sg_length_width {16} \
                            CONFIG.c_sg_use_stsapp_length {1} \
                            ] [get_bd_cells axi_ethernet_${port}_dma]
  
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

  # AXI Eth Interrupts
  lappend intr_list "axi_ethernet_${port}_dma/mm2s_introut"
  lappend intr_list "axi_ethernet_${port}_dma/s2mm_introut"

  # Use connection automation to connect AXI lite interfaces
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/versal_cips_0/M_AXI_LPD} Slave "/axi_ethernet_${port}/s_axi" ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}/s_axi]
  apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/versal_cips_0/M_AXI_LPD} Slave "/axi_ethernet_${port}_dma/S_AXI_LITE" ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_ethernet_${port}_dma/S_AXI_LITE]
  
  # Connect the DMA AXI interfaces
  set index_padded [format "%02d" $noc_port_index]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_SG] [get_bd_intf_pins axi_noc_0/S${index_padded}_AXI]
  set noc_port_index [expr {$noc_port_index + 1}]
  set index_padded [format "%02d" $noc_port_index]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_MM2S] [get_bd_intf_pins axi_noc_0/S${index_padded}_AXI]
  set noc_port_index [expr {$noc_port_index + 1}]
  set index_padded [format "%02d" $noc_port_index]
  connect_bd_intf_net [get_bd_intf_pins axi_ethernet_${port}_dma/M_AXI_S2MM] [get_bd_intf_pins axi_noc_0/S${index_padded}_AXI]
  set noc_port_index [expr {$noc_port_index + 1}]

  # External PHY RESET
  create_bd_port -dir O -type rst reset_port_${port}
  connect_bd_net [get_bd_pins /axi_ethernet_${port}/phy_rst_n] [get_bd_ports reset_port_${port}]
}

# Connect constant values to BUFG GTs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant xlconstant
set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {3}] [get_bd_cells xlconstant]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant xlconstant_0
set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] [get_bd_cells xlconstant_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant xlconstant_1
set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] [get_bd_cells xlconstant_1]
foreach port $ports {
  connect_bd_net [get_bd_pins xlconstant/dout] [get_bd_pins bufg_gt_txoutclk_div2_${port}/gt_bufgtdiv]
  foreach i {"rxoutclk" "txoutclk_div2" "txoutclk"} {
    connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins bufg_gt_${i}_${port}/gt_bufgtce]
    connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins bufg_gt_${i}_${port}/gt_bufgtcemask]
    connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins bufg_gt_${i}_${port}/gt_bufgtclrmask]
    connect_bd_net [get_bd_pins xlconstant_1/dout] [get_bd_pins bufg_gt_${i}_${port}/gt_bufgtclr]
  }
}

# Configure the GT quad protocols
set_property -dict [list \
  CONFIG.PROT1_ENABLE.VALUE_MODE MANUAL \
  CONFIG.PROT3_ENABLE.VALUE_MODE MANUAL \
  CONFIG.PROT2_ENABLE.VALUE_MODE MANUAL \
  CONFIG.PROT0_NO_OF_LANES.VALUE_MODE MANUAL \
  ] [get_bd_cells gt_quad_base_0]
set_property -dict [list \
  CONFIG.PROT0_NO_OF_LANES {1} \
  CONFIG.PROT1_ENABLE {true} \
  CONFIG.PROT2_ENABLE {true} \
  CONFIG.PROT3_ENABLE {true} \
] [get_bd_cells gt_quad_base_0]
set_property -dict [list \
  CONFIG.PROT0_LR0_SETTINGS.VALUE_MODE MANUAL \
  CONFIG.PROT1_LR0_SETTINGS.VALUE_MODE MANUAL \
  CONFIG.PROT2_LR0_SETTINGS.VALUE_MODE MANUAL \
  CONFIG.PROT3_LR0_SETTINGS.VALUE_MODE MANUAL \
  ] [get_bd_cells gt_quad_base_0]
set protocol [list \
  PRESET GTYP-Ethernet_1G \
  RX_PAM_SEL NRZ \
  TX_PAM_SEL NRZ \
  TX_HD_EN 0 \
  RX_HD_EN 0 \
  RX_GRAY_BYP true \
  TX_GRAY_BYP true \
  RX_GRAY_LITTLEENDIAN true \
  TX_GRAY_LITTLEENDIAN true \
  RX_PRECODE_BYP true \
  TX_PRECODE_BYP true \
  RX_PRECODE_LITTLEENDIAN false \
  TX_PRECODE_LITTLEENDIAN false \
  INTERNAL_PRESET Ethernet_1G \
  GT_TYPE GTYP \
  GT_DIRECTION DUPLEX \
  TX_LINE_RATE 1.25 \
  TX_PLL_TYPE RPLL \
  TX_REFCLK_FREQUENCY 125 \
  TX_ACTUAL_REFCLK_FREQUENCY 125.000000000000 \
  TX_FRACN_ENABLED false \
  TX_FRACN_OVRD false \
  TX_FRACN_NUMERATOR 0 \
  TX_REFCLK_SOURCE R0 \
  TX_DATA_ENCODING 8B10B \
  TX_USER_DATA_WIDTH 16 \
  TX_INT_DATA_WIDTH 20 \
  TX_BUFFER_MODE 1 \
  TX_BUFFER_BYPASS_MODE Fast_Sync \
  TX_PIPM_ENABLE false \
  TX_OUTCLK_SOURCE TXPROGDIVCLK \
  TXPROGDIV_FREQ_ENABLE true \
  TXPROGDIV_FREQ_SOURCE RPLL \
  TXPROGDIV_FREQ_VAL 125.000 \
  TX_DIFF_SWING_EMPH_MODE CUSTOM \
  TX_64B66B_SCRAMBLER false \
  TX_64B66B_ENCODER false \
  TX_64B66B_CRC false \
  TX_RATE_GROUP A \
  RX_LINE_RATE 1.25 \
  RX_PLL_TYPE RPLL \
  RX_REFCLK_FREQUENCY 125 \
  RX_ACTUAL_REFCLK_FREQUENCY 125.000000000000 \
  RX_FRACN_ENABLED false \
  RX_FRACN_OVRD false \
  RX_FRACN_NUMERATOR 0 \
  RX_REFCLK_SOURCE R0 \
  RX_DATA_DECODING 8B10B \
  RX_USER_DATA_WIDTH 16 \
  RX_INT_DATA_WIDTH 20 \
  RX_BUFFER_MODE 1 \
  RX_OUTCLK_SOURCE RXPROGDIVCLK \
  RXPROGDIV_FREQ_ENABLE true \
  RXPROGDIV_FREQ_SOURCE RPLL \
  RXPROGDIV_FREQ_VAL 62.500 \
  RXRECCLK_FREQ_ENABLE true \
  RXRECCLK_FREQ_VAL 500.000 \
  INS_LOSS_NYQ 14 \
  RX_EQ_MODE LPM \
  RX_COUPLING AC \
  RX_TERMINATION PROGRAMMABLE \
  RX_RATE_GROUP A \
  RX_TERMINATION_PROG_VALUE 800 \
  RX_PPM_OFFSET 200 \
  RX_64B66B_DESCRAMBLER false \
  RX_64B66B_DECODER false \
  RX_64B66B_CRC false \
  OOB_ENABLE false \
  RX_COMMA_ALIGN_WORD 2 \
  RX_COMMA_SHOW_REALIGN_ENABLE true \
  PCIE_ENABLE false \
  TX_LANE_DESKEW_HDMI_ENABLE false \
  RX_COMMA_P_ENABLE true \
  RX_COMMA_M_ENABLE true \
  RX_COMMA_DOUBLE_ENABLE false \
  RX_COMMA_P_VAL 0101111100 \
  RX_COMMA_M_VAL 1010000011 \
  RX_COMMA_MASK 1111111111 \
  RX_SLIDE_MODE OFF \
  RX_SSC_PPM 0 \
  RX_CB_NUM_SEQ 0 \
  RX_CB_LEN_SEQ 1 \
  RX_CB_MAX_SKEW 1 \
  RX_CB_MAX_LEVEL 1 \
  RX_CB_MASK_0_0 false \
  RX_CB_VAL_0_0 00000000 \
  RX_CB_K_0_0 false \
  RX_CB_DISP_0_0 false \
  RX_CB_MASK_0_1 false \
  RX_CB_VAL_0_1 00000000 \
  RX_CB_K_0_1 false \
  RX_CB_DISP_0_1 false \
  RX_CB_MASK_0_2 false \
  RX_CB_VAL_0_2 00000000 \
  RX_CB_K_0_2 false \
  RX_CB_DISP_0_2 false \
  RX_CB_MASK_0_3 false \
  RX_CB_VAL_0_3 00000000 \
  RX_CB_K_0_3 false \
  RX_CB_DISP_0_3 false \
  RX_CB_MASK_1_0 false \
  RX_CB_VAL_1_0 00000000 \
  RX_CB_K_1_0 false \
  RX_CB_DISP_1_0 false \
  RX_CB_MASK_1_1 false \
  RX_CB_VAL_1_1 00000000 \
  RX_CB_K_1_1 false \
  RX_CB_DISP_1_1 false \
  RX_CB_MASK_1_2 false \
  RX_CB_VAL_1_2 00000000 \
  RX_CB_K_1_2 false \
  RX_CB_DISP_1_2 false \
  RX_CB_MASK_1_3 false \
  RX_CB_VAL_1_3 00000000 \
  RX_CB_K_1_3 false \
  RX_CB_DISP_1_3 false \
  RX_CC_NUM_SEQ 0 \
  RX_CC_LEN_SEQ 1 \
  RX_CC_PERIODICITY 5000 \
  RX_CC_KEEP_IDLE DISABLE \
  RX_CC_PRECEDENCE ENABLE \
  RX_CC_REPEAT_WAIT 0 \
  RX_CC_VAL 00000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  RX_CC_MASK_0_0 false \
  RX_CC_VAL_0_0 00000000 \
  RX_CC_K_0_0 false \
  RX_CC_DISP_0_0 false \
  RX_CC_MASK_0_1 false \
  RX_CC_VAL_0_1 00000000 \
  RX_CC_K_0_1 false \
  RX_CC_DISP_0_1 false \
  RX_CC_MASK_0_2 false \
  RX_CC_VAL_0_2 00000000 \
  RX_CC_K_0_2 false \
  RX_CC_DISP_0_2 false \
  RX_CC_MASK_0_3 false \
  RX_CC_VAL_0_3 00000000 \
  RX_CC_K_0_3 false \
  RX_CC_DISP_0_3 false \
  RX_CC_MASK_1_0 false \
  RX_CC_VAL_1_0 00000000 \
  RX_CC_K_1_0 false \
  RX_CC_DISP_1_0 false \
  RX_CC_MASK_1_1 false \
  RX_CC_VAL_1_1 00000000 \
  RX_CC_K_1_1 false \
  RX_CC_DISP_1_1 false \
  RX_CC_MASK_1_2 false \
  RX_CC_VAL_1_2 00000000 \
  RX_CC_K_1_2 false \
  RX_CC_DISP_1_2 false \
  RX_CC_MASK_1_3 false \
  RX_CC_VAL_1_3 00000000 \
  RX_CC_K_1_3 false \
  RX_CC_DISP_1_3 false \
  PCIE_USERCLK2_FREQ 250 \
  PCIE_USERCLK_FREQ 250 \
  RX_JTOL_FC 0.74985 \
  RX_JTOL_LF_SLOPE -20 \
  RX_BUFFER_BYPASS_MODE Fast_Sync \
  RX_BUFFER_BYPASS_MODE_LANE MULTI \
  RX_BUFFER_RESET_ON_CB_CHANGE ENABLE \
  RX_BUFFER_RESET_ON_COMMAALIGN DISABLE \
  RX_BUFFER_RESET_ON_RATE_CHANGE ENABLE \
  TX_BUFFER_RESET_ON_RATE_CHANGE ENABLE \
  RESET_SEQUENCE_INTERVAL 0 \
  RX_COMMA_PRESET K28.5 \
  RX_COMMA_VALID_ONLY 0]
set_property -dict [list \
  CONFIG.PROT0_LR0_SETTINGS $protocol \
  CONFIG.PROT1_LR0_SETTINGS $protocol \
  CONFIG.PROT2_LR0_SETTINGS $protocol \
  CONFIG.PROT3_LR0_SETTINGS $protocol \
] [get_bd_cells gt_quad_base_0]

connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins gt_quad_base_0/GT_REFCLK1]

# signal_detect and MMCM locked tied HIGH
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant const_high
set_property CONFIG.CONST_VAL {1} [get_bd_cells const_high]
foreach port $ports {
  connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins axi_ethernet_${port}/signal_detect]
  connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins axi_ethernet_${port}/mmcm_locked]
}

# Add the AXI GPIO for the power good and PHY GPIO signals
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0
set_property -dict [list \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_GPIO_WIDTH {10} \
] [get_bd_cells axi_gpio_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/versal_cips_0/M_AXI_LPD} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 gpio
connect_bd_intf_net [get_bd_intf_pins axi_gpio_0/GPIO] [get_bd_intf_ports gpio]

# Connect the interrupts
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins versal_cips_0/pl_ps_irq$intr_index]
  set intr_index [expr {$intr_index+1}]
}

# Assign any addresses that haven't already been assigned
assign_bd_address

validate_bd_design
save_bd_design
