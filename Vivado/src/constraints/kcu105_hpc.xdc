#---------------------------------------------------------------------
# Constraints for Opsero Ethernet FMC Max ref design for KCU105-HPC
#---------------------------------------------------------------------

# Shared MDIO interface
set_property PACKAGE_PIN D24 [get_ports mdio_io_mdc]; # MDC: LA17_CC_P
set_property PACKAGE_PIN C24 [get_ports mdio_io_mdio_io]; # MDIO: LA17_CC_N
set_property IOSTANDARD LVCMOS18 [get_ports md*]

# Power good inputs (PG_1V0 and PG_2V5)
set_property PACKAGE_PIN D9 [get_ports {gpio_tri_i[0]}]; # PG_1V0: LA13_P
set_property PACKAGE_PIN C9 [get_ports {gpio_tri_i[1]}]; # PG_2V5: LA13_N

#####################
# GT reference clock
#####################

# GT ref clock from the Ethernet FMC Max Si511, 125MHz (GBTCLK0_M2C_P/N)
set_property PACKAGE_PIN K6 [get_ports gt_ref_clk_clk_p]; # GBTCLK0_M2C_P

###################
# Ethernet port P0
###################

# P0: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not necessary
# but we leave them here to add redundancy in case the block design goes out of sync.
set_property PACKAGE_PIN F6 [get_ports sgmii_port_0_txp]; # DP0_C2M_P
set_property PACKAGE_PIN F5 [get_ports sgmii_port_0_txn]; # DP0_C2M_N
set_property PACKAGE_PIN E4 [get_ports sgmii_port_0_rxp]; # DP0_M2C_P
set_property PACKAGE_PIN E3 [get_ports sgmii_port_0_rxn]; # DP0_M2C_N

# P0: PHY GPIOs and RESET
set_property PACKAGE_PIN J8 [get_ports {gpio_tri_i[2]}]; # PHY0 GPIO0: LA08_P
set_property PACKAGE_PIN H8 [get_ports {gpio_tri_i[3]}]; # PHY0 GPIO1: LA08_N
set_property PACKAGE_PIN E10 [get_ports {reset_port_0[0]}]; # PHY0 RESET: LA12_P

###################
# Ethernet port P1
###################

# P1: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not necessary
# but we leave them here to add redundancy in case the block design goes out of sync.
set_property PACKAGE_PIN D6 [get_ports sgmii_port_1_txp]; # DP1_C2M_P
set_property PACKAGE_PIN D5 [get_ports sgmii_port_1_txn]; # DP1_C2M_N
set_property PACKAGE_PIN D2 [get_ports sgmii_port_1_rxp]; # DP1_M2C_P
set_property PACKAGE_PIN D1 [get_ports sgmii_port_1_rxn]; # DP1_M2C_N

# P1: PHY GPIOs and RESET
set_property PACKAGE_PIN F8 [get_ports {gpio_tri_i[4]}]; # PHY1 GPIO0: LA07_P
set_property PACKAGE_PIN E8 [get_ports {gpio_tri_i[5]}]; # PHY1 GPIO1: LA07_N
set_property PACKAGE_PIN D10 [get_ports {reset_port_1[0]}]; # PHY1 RESET: LA12_N

###################
# Ethernet port P2
###################

# P2: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not necessary
# but we leave them here to add redundancy in case the block design goes out of sync.
set_property PACKAGE_PIN C4 [get_ports sgmii_port_2_txp]; # DP2_C2M_P
set_property PACKAGE_PIN C3 [get_ports sgmii_port_2_txn]; # DP2_C2M_N
set_property PACKAGE_PIN B2 [get_ports sgmii_port_2_rxp]; # DP2_M2C_P
set_property PACKAGE_PIN B1 [get_ports sgmii_port_2_rxn]; # DP2_M2C_N

# P2: PHY GPIOs and RESET
set_property PACKAGE_PIN B9 [get_ports {gpio_tri_i[6]}]; # PHY2 GPIO0: LA16_P
set_property PACKAGE_PIN A9 [get_ports {gpio_tri_i[7]}]; # PHY2 GPIO1: LA16_N
set_property PACKAGE_PIN K11 [get_ports {reset_port_2[0]}]; # PHY2 RESET: LA11_P

###################
# Ethernet port P3
###################

# P3: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not necessary
# but we leave them here to add redundancy in case the block design goes out of sync.
set_property PACKAGE_PIN B6 [get_ports sgmii_port_3_txp]; # DP3_C2M_P
set_property PACKAGE_PIN B5 [get_ports sgmii_port_3_txn]; # DP3_C2M_N
set_property PACKAGE_PIN A4 [get_ports sgmii_port_3_rxp]; # DP3_M2C_P
set_property PACKAGE_PIN A3 [get_ports sgmii_port_3_rxn]; # DP3_M2C_N

# P3: PHY GPIOs and RESET
set_property PACKAGE_PIN D8 [get_ports {gpio_tri_i[8]}]; # PHY3 GPIO0: LA15_P
set_property PACKAGE_PIN C8 [get_ports {gpio_tri_i[9]}]; # PHY3 GPIO1: LA15_N
set_property PACKAGE_PIN J11 [get_ports {reset_port_3[0]}]; # PHY3 RESET: LA11_N

# IOSTANDARDs for the PHY I/O

set_property IOSTANDARD LVCMOS18 [get_ports gpio_tri_i*]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_*]
# Configuration via Dual Quad SPI settings for KCU105
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

