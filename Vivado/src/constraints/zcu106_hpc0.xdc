#---------------------------------------------------------------------
# Constraints for Opsero Ethernet FMC Max ref design for ZCU106-HPC0
#---------------------------------------------------------------------

# Shared MDIO interface
set_property PACKAGE_PIN F11 [get_ports mdio_io_mdc]; # MDC: LA17_CC_P
set_property PACKAGE_PIN E10 [get_ports mdio_io_mdio_io]; # MDIO: LA17_CC_N
set_property IOSTANDARD LVCMOS18 [get_ports md*]

# Power good inputs (PG_1V0 and PG_2V5)
set_property PACKAGE_PIN G15 [get_ports {gpio_tri_i[0]}]; # PG_1V0: LA13_P
set_property PACKAGE_PIN F15 [get_ports {gpio_tri_i[1]}]; # PG_2V5: LA13_N

#####################
# GT reference clock
#####################

# GT ref clock from the Ethernet FMC Max Si511, 125MHz (GBTCLK0_M2C_P/N)
set_property PACKAGE_PIN V8 [get_ports gt_ref_clk_clk_p]; # GBTCLK0_M2C_P

###################
# Ethernet port P0
###################

# P0: Gigabit transceivers
set_property PACKAGE_PIN R6 [get_ports sgmii_port_0_txp]; # DP0_C2M_P
set_property PACKAGE_PIN R5 [get_ports sgmii_port_0_txn]; # DP0_C2M_N
set_property PACKAGE_PIN R2 [get_ports sgmii_port_0_rxp]; # DP0_M2C_P
set_property PACKAGE_PIN R1 [get_ports sgmii_port_0_rxn]; # DP0_M2C_N

# P0: PHY GPIOs and RESET
set_property PACKAGE_PIN E18 [get_ports {gpio_tri_i[2]}]; # PHY0 GPIO0: LA08_P
set_property PACKAGE_PIN E17 [get_ports {gpio_tri_i[3]}]; # PHY0 GPIO1: LA08_N
set_property PACKAGE_PIN G18 [get_ports {reset_port_0[0]}]; # PHY0 RESET: LA12_P

###################
# Ethernet port P1
###################

# P1: Gigabit transceivers
set_property PACKAGE_PIN T4 [get_ports sgmii_port_1_txp]; # DP1_C2M_P
set_property PACKAGE_PIN T3 [get_ports sgmii_port_1_txn]; # DP1_C2M_N
set_property PACKAGE_PIN U2 [get_ports sgmii_port_1_rxp]; # DP1_M2C_P
set_property PACKAGE_PIN U1 [get_ports sgmii_port_1_rxn]; # DP1_M2C_N

# P1: PHY GPIOs and RESET
set_property PACKAGE_PIN J16 [get_ports {gpio_tri_i[4]}]; # PHY1 GPIO0: LA07_P
set_property PACKAGE_PIN J15 [get_ports {gpio_tri_i[5]}]; # PHY1 GPIO1: LA07_N
set_property PACKAGE_PIN F18 [get_ports {reset_port_1[0]}]; # PHY1 RESET: LA12_N

###################
# Ethernet port P2
###################

# P2: Gigabit transceivers
set_property PACKAGE_PIN N6 [get_ports sgmii_port_2_txp]; # DP2_C2M_P
set_property PACKAGE_PIN N5 [get_ports sgmii_port_2_txn]; # DP2_C2M_N
set_property PACKAGE_PIN P4 [get_ports sgmii_port_2_rxp]; # DP2_M2C_P
set_property PACKAGE_PIN P3 [get_ports sgmii_port_2_rxn]; # DP2_M2C_N

# P2: PHY GPIOs and RESET
set_property PACKAGE_PIN D17 [get_ports {gpio_tri_i[6]}]; # PHY2 GPIO0: LA16_P
set_property PACKAGE_PIN C17 [get_ports {gpio_tri_i[7]}]; # PHY2 GPIO1: LA16_N
set_property PACKAGE_PIN A13 [get_ports {reset_port_2[0]}]; # PHY2 RESET: LA11_P

###################
# Ethernet port P3
###################

# P3: Gigabit transceivers
set_property PACKAGE_PIN U6 [get_ports sgmii_port_3_txp]; # DP3_C2M_P
set_property PACKAGE_PIN U5 [get_ports sgmii_port_3_txn]; # DP3_C2M_N
set_property PACKAGE_PIN V4 [get_ports sgmii_port_3_rxp]; # DP3_M2C_P
set_property PACKAGE_PIN V3 [get_ports sgmii_port_3_rxn]; # DP3_M2C_N

# P3: PHY GPIOs and RESET
set_property PACKAGE_PIN D16 [get_ports {gpio_tri_i[8]}]; # PHY3 GPIO0: LA15_P
set_property PACKAGE_PIN C16 [get_ports {gpio_tri_i[9]}]; # PHY3 GPIO1: LA15_N
set_property PACKAGE_PIN A12 [get_ports {reset_port_3[0]}]; # PHY3 RESET: LA11_N

# IOSTANDARDs for the PHY I/O

set_property IOSTANDARD LVCMOS18 [get_ports gpio_tri_i*]
set_property IOSTANDARD LVCMOS18 [get_ports reset_port_*]
