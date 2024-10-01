#---------------------------------------------------------------------
# Constraints for Opsero Ethernet FMC Max ref design for VMK180-FMCP1
#---------------------------------------------------------------------

# Shared MDIO interface
set_property PACKAGE_PIN BB16 [get_ports mdio_io_mdc]; # MDC: LA17_CC_P
set_property PACKAGE_PIN BC16 [get_ports mdio_io_mdio_io]; # MDIO: LA17_CC_N
set_property IOSTANDARD LVCMOS15 [get_ports md*]

# Power good inputs (PG_1V0 and PG_2V5)
set_property PACKAGE_PIN BE21 [get_ports {gpio_tri_i[0]}]; # PG_1V0: LA13_P
set_property PACKAGE_PIN BE20 [get_ports {gpio_tri_i[1]}]; # PG_2V5: LA13_N

#####################
# GT reference clock
#####################

# GT ref clock from the Ethernet FMC Max Si511, 125MHz (GBTCLK0_M2C_P/N)
set_property PACKAGE_PIN M15 [get_ports gt_ref_clk_clk_p]; # GBTCLK0_M2C_P

###################
# Ethernet port P0
###################

# P0: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not required.
# set_property PACKAGE_PIN AB7 [get_ports sgmii_port_0_txp]; # DP0_C2M_P
# set_property PACKAGE_PIN AB6 [get_ports sgmii_port_0_txn]; # DP0_C2M_N
# set_property PACKAGE_PIN AB2 [get_ports sgmii_port_0_rxp]; # DP0_M2C_P
# set_property PACKAGE_PIN AB1 [get_ports sgmii_port_0_rxn]; # DP0_M2C_N

# P0: PHY GPIOs and RESET
set_property PACKAGE_PIN BC22 [get_ports {gpio_tri_i[2]}]; # PHY0 GPIO0: LA08_P
set_property PACKAGE_PIN BC21 [get_ports {gpio_tri_i[3]}]; # PHY0 GPIO1: LA08_N
set_property PACKAGE_PIN BG21 [get_ports {reset_port_0[0]}]; # PHY0 RESET: LA12_P

###################
# Ethernet port P1
###################

# P1: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not required.
# set_property PACKAGE_PIN AA9 [get_ports sgmii_port_1_txp]; # DP1_C2M_P
# set_property PACKAGE_PIN AA8 [get_ports sgmii_port_1_txn]; # DP1_C2M_N
# set_property PACKAGE_PIN AA4 [get_ports sgmii_port_1_rxp]; # DP1_M2C_P
# set_property PACKAGE_PIN AA3 [get_ports sgmii_port_1_rxn]; # DP1_M2C_N

# P1: PHY GPIOs and RESET
set_property PACKAGE_PIN BC25 [get_ports {gpio_tri_i[4]}]; # PHY1 GPIO0: LA07_P
set_property PACKAGE_PIN BD25 [get_ports {gpio_tri_i[5]}]; # PHY1 GPIO1: LA07_N
set_property PACKAGE_PIN BF22 [get_ports {reset_port_1[0]}]; # PHY1 RESET: LA12_N

###################
# Ethernet port P2
###################

# P2: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not required.
# set_property PACKAGE_PIN Y7 [get_ports sgmii_port_2_txp]; # DP2_C2M_P
# set_property PACKAGE_PIN Y6 [get_ports sgmii_port_2_txn]; # DP2_C2M_N
# set_property PACKAGE_PIN Y2 [get_ports sgmii_port_2_rxp]; # DP2_M2C_P
# set_property PACKAGE_PIN Y1 [get_ports sgmii_port_2_rxn]; # DP2_M2C_N

# P2: PHY GPIOs and RESET
set_property PACKAGE_PIN BF21 [get_ports {gpio_tri_i[6]}]; # PHY2 GPIO0: LA16_P
set_property PACKAGE_PIN BG20 [get_ports {gpio_tri_i[7]}]; # PHY2 GPIO1: LA16_N
set_property PACKAGE_PIN BF23 [get_ports {reset_port_2[0]}]; # PHY2 RESET: LA11_P

###################
# Ethernet port P3
###################

# P3: Gigabit transceivers
# GTs are assigned in the block design and Vivado generates LOC constraints, so the following are not required.
# set_property PACKAGE_PIN W9 [get_ports sgmii_port_3_txp]; # DP3_C2M_P
# set_property PACKAGE_PIN W8 [get_ports sgmii_port_3_txn]; # DP3_C2M_N
# set_property PACKAGE_PIN W4 [get_ports sgmii_port_3_rxp]; # DP3_M2C_P
# set_property PACKAGE_PIN W3 [get_ports sgmii_port_3_rxn]; # DP3_M2C_N

# P3: PHY GPIOs and RESET
set_property PACKAGE_PIN AY22 [get_ports {gpio_tri_i[8]}]; # PHY3 GPIO0: LA15_P
set_property PACKAGE_PIN AY23 [get_ports {gpio_tri_i[9]}]; # PHY3 GPIO1: LA15_N
set_property PACKAGE_PIN BE22 [get_ports {reset_port_3[0]}]; # PHY3 RESET: LA11_N

# IOSTANDARDs for the PHY I/O

set_property IOSTANDARD LVCMOS15 [get_ports gpio_tri_i*]
set_property IOSTANDARD LVCMOS15 [get_ports reset_port_*]
