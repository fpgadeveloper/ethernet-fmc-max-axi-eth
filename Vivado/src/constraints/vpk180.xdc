#---------------------------------------------------------------------
# Constraints for Opsero Ethernet FMC Max ref design for VPK180
#---------------------------------------------------------------------

# Shared MDIO interface
set_property PACKAGE_PIN BU41 [get_ports mdio_io_mdc]; # MDC: LA17_CC_P
set_property PACKAGE_PIN BU42 [get_ports mdio_io_mdio_io]; # MDIO: LA17_CC_N
set_property IOSTANDARD LVCMOS15 [get_ports md*]

# Power good inputs (PG_1V0 and PG_2V5)
set_property PACKAGE_PIN CC49 [get_ports {gpio_tri_i[0]}]; # PG_1V0: LA13_P
set_property PACKAGE_PIN CD50 [get_ports {gpio_tri_i[1]}]; # PG_2V5: LA13_N

#####################
# GT reference clock
#####################

# GT ref clock from the Ethernet FMC Max Si511, 125MHz (GBTCLK0_M2C_P/N)
set_property PACKAGE_PIN AT48 [get_ports gt_ref_clk_clk_p]; # GBTCLK0_M2C_P

###################
# Ethernet port P0
###################

# P0: Gigabit transceivers
set_property PACKAGE_PIN CD54 [get_ports {sgmii_port_gtx_p[0]}]; # DP0_C2M_P
set_property PACKAGE_PIN CD55 [get_ports {sgmii_port_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN CB61 [get_ports {sgmii_port_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN CB62 [get_ports {sgmii_port_grx_n[0]}]; # DP0_M2C_N

# P0: PHY GPIOs and RESET
set_property PACKAGE_PIN BY49 [get_ports {gpio_tri_i[2]}]; # PHY0 GPIO0: LA08_P
set_property PACKAGE_PIN BY50 [get_ports {gpio_tri_i[3]}]; # PHY0 GPIO1: LA08_N
set_property PACKAGE_PIN BW49 [get_ports {reset_port_0[0]}]; # PHY0 RESET: LA12_P

###################
# Ethernet port P1
###################

# P1: Gigabit transceivers
set_property PACKAGE_PIN CD58 [get_ports {sgmii_port_gtx_p[1]}]; # DP1_C2M_P
set_property PACKAGE_PIN CD59 [get_ports {sgmii_port_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN BY61 [get_ports {sgmii_port_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN BY62 [get_ports {sgmii_port_grx_n[1]}]; # DP1_M2C_N

# P1: PHY GPIOs and RESET
set_property PACKAGE_PIN CB49 [get_ports {gpio_tri_i[4]}]; # PHY1 GPIO0: LA07_P
set_property PACKAGE_PIN CC50 [get_ports {gpio_tri_i[5]}]; # PHY1 GPIO1: LA07_N
set_property PACKAGE_PIN BW50 [get_ports {reset_port_1[0]}]; # PHY1 RESET: LA12_N

###################
# Ethernet port P2
###################

# P2: Gigabit transceivers
set_property PACKAGE_PIN CC56 [get_ports {sgmii_port_gtx_p[2]}]; # DP2_C2M_P
set_property PACKAGE_PIN CC57 [get_ports {sgmii_port_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN BW63 [get_ports {sgmii_port_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN BW64 [get_ports {sgmii_port_grx_n[2]}]; # DP2_M2C_N

# P2: PHY GPIOs and RESET
set_property PACKAGE_PIN CA51 [get_ports {gpio_tri_i[6]}]; # PHY2 GPIO0: LA16_P
set_property PACKAGE_PIN CB52 [get_ports {gpio_tri_i[7]}]; # PHY2 GPIO1: LA16_N
set_property PACKAGE_PIN CB51 [get_ports {reset_port_2[0]}]; # PHY2 RESET: LA11_P

###################
# Ethernet port P3
###################

# P3: Gigabit transceivers
set_property PACKAGE_PIN CB58 [get_ports {sgmii_port_gtx_p[3]}]; # DP3_C2M_P
set_property PACKAGE_PIN CB59 [get_ports {sgmii_port_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN BV61 [get_ports {sgmii_port_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN BV62 [get_ports {sgmii_port_grx_n[3]}]; # DP3_M2C_N

# P3: PHY GPIOs and RESET
set_property PACKAGE_PIN CD51 [get_ports {gpio_tri_i[8]}]; # PHY3 GPIO0: LA15_P
set_property PACKAGE_PIN CD52 [get_ports {gpio_tri_i[9]}]; # PHY3 GPIO1: LA15_N
set_property PACKAGE_PIN CC52 [get_ports {reset_port_3[0]}]; # PHY3 RESET: LA11_N

# IOSTANDARDs for the PHY I/O

set_property IOSTANDARD LVCMOS15 [get_ports gpio_tri_i*]
set_property IOSTANDARD LVCMOS15 [get_ports reset_port_*]
