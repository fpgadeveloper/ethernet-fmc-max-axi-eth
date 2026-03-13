/*
 * Copyright (C) 2010 - 2022 Xilinx, Inc.
 * Copyright (C) 2022 - 2024 Advanced Micro Devices, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * This file is part of the lwIP TCP/IP stack.
 *
 * Opsero Electronic Design Inc. 2024
 * This code has been modified to work with the Opsero Ethernet FMC Max (OP080).
 */

#include "netif/xaxiemacif.h"
#include "lwipopts.h"
#include "sleep.h"
#include "xemac_ieee_reg.h"
#include "xparameters.h"

#define PHY_R0_ISOLATE  						0x0400
#define PHY_DETECT_REG  						1
#define PHY_IDENTIFIER_1_REG					2
#define PHY_IDENTIFIER_2_REG					3
#define PHY_DETECT_MASK 						0x1808
#define PHY_MARVELL_IDENTIFIER					0x0141
#define PHY_TI_IDENTIFIER					    0x2000

/* Marvel PHY flags */
#define MARVEL_PHY_IDENTIFIER 					0x141
#define MARVEL_PHY_MODEL_NUM_MASK				0x3F0
#define MARVEL_PHY_88E1111_MODEL				0xC0
#define MARVEL_PHY_88E1116R_MODEL				0x240
#define PHY_88E1111_RGMII_RX_CLOCK_DELAYED_MASK	0x0080

/* TI PHY Flags */
#define TI_PHY_DETECT_MASK 						0x796D
#define TI_PHY_IDENTIFIER 						0x2000
#define TI_PHY_DP83867_MODEL					0xA231
#define DP83867_RGMII_CLOCK_DELAY_CTRL_MASK		0x0003
#define DP83867_RGMII_TX_CLOCK_DELAY_MASK		0x0030
#define DP83867_RGMII_RX_CLOCK_DELAY_MASK		0x0003

/* TI DP83867 PHY Registers */
#define DP83867_R32_RGMIICTL1					0x32
#define DP83867_R86_RGMIIDCTL					0x86

#define TI_PHY_REGCR			0xD
#define TI_PHY_ADDDR			0xE
#define TI_PHY_PHYCTRL			0x10
#define TI_PHY_CFGR2			0x14
#define TI_PHY_SGMIITYPE		0xD3
#define TI_PHY_CFGR2_SGMII_AUTONEG_EN	0x0080
#define TI_PHY_SGMIICLK_EN		0x4000
#define TI_PHY_REGCR_DEVAD_EN		0x001F
#define TI_PHY_REGCR_DEVAD_DATAEN	0x4000
#define TI_PHY_CFGR2_MASK		0x003F
#define TI_PHY_REGCFG4			0x31
#define TI_PHY_REGCR_DATA		0x401F
#define TI_PHY_CFG4RESVDBIT7		0x80
#define TI_PHY_CFG4RESVDBIT8		0x100
#define TI_PHY_CFG4_AUTONEG_TIMER	0x60

#define TI_PHY_CFG2_SPEEDOPT_10EN          0x0040
#define TI_PHY_CFG2_SGMII_AUTONEGEN        0x0080
#define TI_PHY_CFG2_SPEEDOPT_ENH           0x0100
#define TI_PHY_CFG2_SPEEDOPT_CNT           0x0800
#define TI_PHY_CFG2_SPEEDOPT_INTLOW        0x2000

#define TI_PHY_CR_SGMII_EN		0x0800
#define TI_PHY_PORT_MIRROR_EN	0x0001

/* Loop counters to check for reset done
 */
#define RESET_TIMEOUT							0xFFFF
#define AUTO_NEG_TIMEOUT 						0x00FFFFFF

#define IEEE_CTRL_RESET                         0x9140
#define IEEE_CTRL_ISOLATE_DISABLE               0xFBFF

#define PHY_XILINX_PCS_PMA_ID1			0x0174
#define PHY_XILINX_PCS_PMA_ID2			0x0C00

#ifdef SDT
#define XPAR_AXIETHERNET_0_PHYADDR	XPAR_XAXIETHERNET_0_PHYADDR
#define XPAR_AXIETHERNET_0_BASEADDR	XPAR_XAXIETHERNET_0_BASEADDR
#endif

extern u32_t phyaddrforemac;

#define NUM_PORTS XPAR_XAXIETHERNET_NUM_INSTANCES

// Array to store base addresses
uint32_t base_addresses[NUM_PORTS] = {
#if NUM_PORTS > 0
    XPAR_AXI_ETHERNET_0_BASEADDR,
#endif
#if NUM_PORTS > 1
    XPAR_AXI_ETHERNET_1_BASEADDR,
#endif
#if NUM_PORTS > 2
    XPAR_AXI_ETHERNET_2_BASEADDR,
#endif
#if NUM_PORTS > 3
    XPAR_AXI_ETHERNET_3_BASEADDR
#endif
};

// AXI Ethernet instance with MDIO bus
XAxiEthernet axieth_mdio_inst;
XAxiEthernet *axieth_mdio = &axieth_mdio_inst;
// External PHY addresses on Ethernet FMC Max
const u16 extphyaddr[] = {0x1,0x3,0xC,0xF};
// SGMII PHY addresses determined in Vivado design
const u16 sgmiiphyaddr[] = {0x2,0x4,0xD,0xE};


static void __attribute__ ((noinline)) AxiEthernetUtilPhyDelay(unsigned int Seconds);

static int detect_phy(XAxiEthernet *xaxiemacp)
{
	u16 phy_reg;
	u16 phy_id;
	u32 phy_addr;

	for (phy_addr = 31; phy_addr > 0; phy_addr--) {
		XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_DETECT_REG,
								&phy_reg);

		if ((phy_reg != 0xFFFF) &&
			((phy_reg & PHY_DETECT_MASK) == PHY_DETECT_MASK)) {
			/* Found a valid PHY address */
			LWIP_DEBUGF(NETIF_DEBUG, ("XAxiEthernet detect_phy: PHY detected at address %d.\r\n", phy_addr));
			LWIP_DEBUGF(NETIF_DEBUG, ("XAxiEthernet detect_phy: PHY detected.\r\n"));
			XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_IDENTIFIER_1_REG,
										&phy_reg);
			if ((phy_reg != PHY_MARVELL_IDENTIFIER) &&
                (phy_reg != TI_PHY_IDENTIFIER)){
				xil_printf("WARNING: Not a Marvell or TI Ethernet PHY. Please verify the initialization sequence\r\n");
			}
			phyaddrforemac = phy_addr;
			return phy_addr;
		}

		XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_IDENTIFIER_1_REG,
				&phy_id);

		if (phy_id == PHY_XILINX_PCS_PMA_ID1) {
			XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_IDENTIFIER_2_REG,
					&phy_id);
			if (phy_id == PHY_XILINX_PCS_PMA_ID2) {
				/* Found a valid PHY address */
				LWIP_DEBUGF(NETIF_DEBUG, ("XAxiEthernet detect_phy: PHY detected at address %d.\r\n",
							phy_addr));
				phyaddrforemac = phy_addr;
				return phy_addr;
			}
		}
	}

	LWIP_DEBUGF(NETIF_DEBUG, ("XAxiEthernet detect_phy: No PHY detected.  Assuming a PHY at address 0\r\n"));

        /* default to zero */
	return 0;
}

static int isphy_pcspma(XAxiEthernet *xaxiemacp, u32 phy_addr)
{
	u16 phy_id;

	XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_IDENTIFIER_1_REG,
			    &phy_id);
	if (phy_id == PHY_XILINX_PCS_PMA_ID1) {
		XAxiEthernet_PhyRead(xaxiemacp, phy_addr, PHY_IDENTIFIER_2_REG,
				&phy_id);
		if (phy_id == PHY_XILINX_PCS_PMA_ID2) {
			return 1;
		}
	}

	return 0;
}

void XAxiEthernet_PhyReadExtended(XAxiEthernet *InstancePtr, u32 PhyAddress,
		u32 RegisterNum, u16 *PhyDataPtr)
{
	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_CONTROL_REG, IEEE_MMD_ACCESS_CTRL_DEVAD_MASK);

	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_ADDRESS_DATA_REG, RegisterNum);

	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_CONTROL_REG, IEEE_MMD_ACCESS_CTRL_NOPIDEVAD_MASK);

	XAxiEthernet_PhyRead(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_ADDRESS_DATA_REG, PhyDataPtr);

}

void XAxiEthernet_PhyWriteExtended(XAxiEthernet *InstancePtr, u32 PhyAddress,
		u32 RegisterNum, u16 PhyDataPtr)
{
	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_CONTROL_REG, IEEE_MMD_ACCESS_CTRL_DEVAD_MASK);

	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_ADDRESS_DATA_REG, RegisterNum);

	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_CONTROL_REG, IEEE_MMD_ACCESS_CTRL_NOPIDEVAD_MASK);

	XAxiEthernet_PhyWrite(InstancePtr, PhyAddress,
			IEEE_MMD_ACCESS_ADDRESS_DATA_REG, PhyDataPtr);

}

unsigned int get_phy_negotiated_speed (XAxiEthernet *xaxiemacp, XAxiEthernet *xaxiemacp_mdio, u32 phy_addr)
{
	u16 control;
	u16 status;
	u16 partner_capabilities;
	u16 partner_capabilities_1000;
	u16 phylinkspeed;
	u16 temp;

	xil_printf("Start PHY autonegotiation \r\n");
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET,
																	&control);

	control |= IEEE_CTRL_AUTONEGOTIATE_ENABLE;
	control |= IEEE_STAT_AUTONEGOTIATE_RESTART;

	if (isphy_pcspma(xaxiemacp_mdio, phy_addr)) {
	    control &= IEEE_CTRL_ISOLATE_DISABLE;
	}

	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET,
														control);
	if (isphy_pcspma(xaxiemacp_mdio, phy_addr)) {
		XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_STATUS_REG_OFFSET, &status);
		xil_printf("Waiting for PHY to  complete autonegotiation \r\n");
		while ( !(status & IEEE_STAT_AUTONEGOTIATE_COMPLETE) ) {
			AxiEthernetUtilPhyDelay(1);
			XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_STATUS_REG_OFFSET,
									&status);

		}

		xil_printf("Autonegotiation complete \r\n");

		if (xaxiemacp->Config.Speed == XAE_SPEED_2500_MBPS)
			return XAE_SPEED_2500_MBPS;

#ifndef SDT
		if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) == XAE_PHY_TYPE_1000BASE_X) {
#else
		if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) == XAE_PHY_TYPE_1000BASE_X) {
#endif
			XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_PAGE_ADDRESS_REGISTER, 1);
			XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_PARTNER_ABILITIES_1_REG_OFFSET, &temp);
			if ((temp & 0x0020) == 0x0020) {
				XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_PAGE_ADDRESS_REGISTER, 0);
				return 1000;
			}
			else {
				XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_PAGE_ADDRESS_REGISTER, 0);
				xil_printf("Link error, temp = %x\r\n", temp);
				return 0;
			}
#ifndef SDT
		} else if(XAxiEthernet_GetPhysicalInterface(xaxiemacp) == XAE_PHY_TYPE_SGMII) {
#else
		} else if(XAxiEthernet_Get_Phy_Interface(xaxiemacp) == XAE_PHY_TYPE_SGMII) {

#endif
			xil_printf("Waiting for Link to be up; Polling for SGMII core Reg \r\n");
			XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_PARTNER_ABILITIES_1_REG_OFFSET, &temp);
			while(!(temp & 0x8000)) {
				XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_PARTNER_ABILITIES_1_REG_OFFSET, &temp);
			}
			if((temp & 0x0C00) == 0x0800) {
				return 1000;
			}
			else if((temp & 0x0C00) == 0x0400) {
				return 100;
			}
			else if((temp & 0x0C00) == 0x0000) {
				return 10;
			} else {
				xil_printf("get_IEEE_phy_speed(): Invalid speed bit value, Defaulting to Speed = 10 Mbps\r\n");
				XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET, &temp);
				XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET, 0x0100);
				return 10;
			}
		}
	}

	/* Read PHY control and status registers is successful. */
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET,
														&control);
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_STATUS_REG_OFFSET,
														&status);
	if ((control & IEEE_CTRL_AUTONEGOTIATE_ENABLE) && (status &
					IEEE_STAT_AUTONEGOTIATE_CAPABLE)) {
		xil_printf("Waiting for PHY to complete autonegotiation.\r\n");
		while ( !(status & IEEE_STAT_AUTONEGOTIATE_COMPLETE) ) {
							XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
									IEEE_STATUS_REG_OFFSET,
									&status);
	    }

		xil_printf("autonegotiation complete \r\n");

		XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
										IEEE_PARTNER_ABILITIES_1_REG_OFFSET,
										&partner_capabilities);
		if (status & IEEE_STAT_1GBPS_EXTENSIONS) {
			XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
					IEEE_PARTNER_ABILITIES_3_REG_OFFSET,
					&partner_capabilities_1000);
			if (partner_capabilities_1000 &
					IEEE_AN3_ABILITY_MASK_1GBPS)
				return 1000;
		}

		if (partner_capabilities & IEEE_AN1_ABILITY_MASK_100MBPS)
			return 100;
		if (partner_capabilities & IEEE_AN1_ABILITY_MASK_10MBPS)
			return 10;

		xil_printf("%s: unknown PHY link speed, setting TEMAC speed to be 10 Mbps\r\n",
				__FUNCTION__);
		return 10;
	} else {
		/* Update TEMAC speed accordingly */
		if (status & IEEE_STAT_1GBPS_EXTENSIONS) {

			/* Get commanded link speed */
			phylinkspeed = control &
				IEEE_CTRL_1GBPS_LINKSPEED_MASK;

			switch (phylinkspeed) {
				case (IEEE_CTRL_LINKSPEED_1000M):
					return 1000;
				case (IEEE_CTRL_LINKSPEED_100M):
					return 100;
				case (IEEE_CTRL_LINKSPEED_10M):
					return 10;
				default:
					xil_printf("%s: unknown PHY link speed (%d), setting TEMAC speed to be 10 Mbps\r\n",
						__FUNCTION__, phylinkspeed);
					return 10;
			}
		} else {
			return (control & IEEE_CTRL_LINKSPEED_MASK) ? 100 : 10;
		}
	}
}

unsigned int get_phy_speed_TI_DP83867_SGMII(XAxiEthernet *xaxiemacp, XAxiEthernet *xaxiemacp_mdio, u32 phy_addr)
{
	u16 control;
	u16 temp;
	u16 phyregtemp;

	xil_printf("Start TI PHY autonegotiation\r\n");

	/* Enable Mirror mode for Ethernet FMC Max */
	XAxiEthernet_PhyReadExtended(xaxiemacp_mdio, phy_addr, TI_PHY_REGCFG4, &temp);
	temp |= TI_PHY_PORT_MIRROR_EN;
	XAxiEthernet_PhyWriteExtended(xaxiemacp_mdio, phy_addr, TI_PHY_REGCFG4, temp);

	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET,
			     &control);
	control |= (IEEE_CTRL_AUTONEGOTIATE_ENABLE | IEEE_CTRL_LINKSPEED_1000M |
		    IEEE_CTRL_FULL_DUPLEX);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_OFFSET,
			      control);

	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, TI_PHY_CFGR2, &control);
	control &= TI_PHY_CFGR2_MASK;
	control |= (TI_PHY_CFG2_SPEEDOPT_10EN   |
		    TI_PHY_CFG2_SGMII_AUTONEGEN |
		    TI_PHY_CFG2_SPEEDOPT_ENH    |
		    TI_PHY_CFG2_SPEEDOPT_CNT    |
		    TI_PHY_CFG2_SPEEDOPT_INTLOW);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_CFGR2, control);

	/* Disable RGMII */
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR,
			      TI_PHY_REGCR_DEVAD_EN);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR,
			      DP83867_R32_RGMIICTL1);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR,
			      TI_PHY_REGCR_DEVAD_EN | TI_PHY_REGCR_DEVAD_DATAEN);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR, 0);

	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_PHYCTRL,
			      TI_PHY_CR_SGMII_EN);

	xil_printf("Waiting for Link to be up \r\n");
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
			     IEEE_PARTNER_ABILITIES_1_REG_OFFSET, &temp);
	while(!(temp & 0x4000)) {
		XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
				IEEE_PARTNER_ABILITIES_1_REG_OFFSET, &temp);
	}
	xil_printf("Auto negotiation completed for TI PHY\n\r");

	/* SW workaround for unstable link when RX_CTRL is not STRAP MODE 3 or 4 */
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR, TI_PHY_REGCR_DEVAD_EN);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR, TI_PHY_REGCFG4);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR, TI_PHY_REGCR_DATA);
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR, (u16_t *)&phyregtemp);
	phyregtemp &= ~(TI_PHY_CFG4RESVDBIT7);
	phyregtemp |= TI_PHY_CFG4RESVDBIT8;
	phyregtemp &= ~(TI_PHY_CFG4_AUTONEG_TIMER);
	phyregtemp |= TI_PHY_CFG4_AUTONEG_TIMER;
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR, TI_PHY_REGCR_DEVAD_EN);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR, TI_PHY_REGCFG4);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_REGCR, TI_PHY_REGCR_DATA);
	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, TI_PHY_ADDDR, phyregtemp);

	return get_phy_negotiated_speed(xaxiemacp, xaxiemacp_mdio, phy_addr);
}

unsigned get_IEEE_phy_speed(XAxiEthernet *xaxiemacp, XAxiEthernet *xaxiemacp_mdio, u32 ext_phy_addr)
{
	u16 phy_identifier;
	u16 phy_model;
	u8 phytype;

	u32 phy_addr = ext_phy_addr;

	/* Get the PHY Identifier and Model number */
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, PHY_IDENTIFIER_1_REG, &phy_identifier);
	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, PHY_IDENTIFIER_2_REG, &phy_model);

/* Depending upon what manufacturer PHY is connected, a different mask is
 * needed to determine the specific model number of the PHY. */
	if (phy_identifier == TI_PHY_IDENTIFIER) {
		phy_model = phy_model & TI_PHY_DP83867_MODEL;
#ifndef SDT
		phytype = XAxiEthernet_GetPhysicalInterface(xaxiemacp);
#else
		phytype = XAxiEthernet_Get_Phy_Interface(xaxiemacp);
#endif
		if (phy_model == TI_PHY_DP83867_MODEL && phytype == XAE_PHY_TYPE_SGMII) {
			return get_phy_speed_TI_DP83867_SGMII(xaxiemacp, xaxiemacp_mdio, phy_addr);
		}

	}
	else {
	    LWIP_DEBUGF(NETIF_DEBUG, ("XAxiEthernet get_IEEE_phy_speed: Detected PHY with unknown identifier/model.\r\n"));
	}
	if (isphy_pcspma(xaxiemacp_mdio, phy_addr)) {
		return get_phy_negotiated_speed(xaxiemacp, xaxiemacp_mdio, phy_addr);
	}
}

unsigned configure_IEEE_phy_speed(XAxiEthernet *xaxiemacp, XAxiEthernet *xaxiemacp_mdio, u32 phy_addr, unsigned speed)
{
	u16 control;
	u16 phy_val;

#ifndef SDT
	if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
				XAE_PHY_TYPE_RGMII_2_0) {
		/* Setting Tx and Rx Delays for RGMII mode */
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_PAGE_ADDRESS_REGISTER, 0x2);

		XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_MAC, &phy_val);
		phy_val |= IEEE_RGMII_TXRX_CLOCK_DELAYED_MASK;
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_CONTROL_REG_MAC, phy_val);

		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr, IEEE_PAGE_ADDRESS_REGISTER, 0x0);
	}

	XAxiEthernet_PhyRead(xaxiemacp_mdio, phy_addr,
				IEEE_CONTROL_REG_OFFSET,
				&control);
	control &= ~IEEE_CTRL_LINKSPEED_1000M;
	control &= ~IEEE_CTRL_LINKSPEED_100M;
	control &= ~IEEE_CTRL_LINKSPEED_10M;

	if (speed == 1000) {
		control |= IEEE_CTRL_LINKSPEED_1000M;
	}

	else if (speed == 100) {
		control |= IEEE_CTRL_LINKSPEED_100M;
		/* Don't advertise PHY speed of 1000 Mbps */
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr,
					IEEE_1000_ADVERTISE_REG_OFFSET,
					0);
		/* Don't advertise PHY speed of 10 Mbps */
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr,
				IEEE_AUTONEGO_ADVERTISE_REG,
				ADVERTISE_100);

	}
	else if (speed == 10) {
		control |= IEEE_CTRL_LINKSPEED_10M;
		/* Don't advertise PHY speed of 1000 Mbps */
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr,
				IEEE_1000_ADVERTISE_REG_OFFSET,
					0);
		/* Don't advertise PHY speed of 100 Mbps */
		XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr,
				IEEE_AUTONEGO_ADVERTISE_REG,
				ADVERTISE_10);
	}

	XAxiEthernet_PhyWrite(xaxiemacp_mdio, phy_addr,
				IEEE_CONTROL_REG_OFFSET,
				control | IEEE_CTRL_RESET_MASK);

#ifndef SDT
	if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
			XAE_PHY_TYPE_SGMII) {
		control &= (~PHY_R0_ISOLATE);
		XAxiEthernet_PhyWrite(xaxiemacp_mdio,
				XPAR_AXIETHERNET_0_PHYADDR,
				IEEE_CONTROL_REG_OFFSET,
				control | IEEE_CTRL_AUTONEGOTIATE_ENABLE);
	}

	{
		volatile int wait;
		for (wait=0; wait < 100000; wait++);
		for (wait=0; wait < 100000; wait++);
	}
	return 0;
}

/*
 * The purpose of this function is to instantiate the AXI Ethernet for PORT0 of
 * the Ethernet FMC Max in the case that we are running the echo server on
 * ONE OF THE OTHER PORTS (1,2 or 3, hence it has not already been instantiated).
 * We need the AXI Ethernet instance of PORT0 because it is the one that is
 * physically connected to the external MDIO bus and we need to make all PHY reads
 * and writes through this instance.
 */
void init_axiemac_port0(unsigned char *mac_eth_addr)
{
	unsigned options;
	XAxiEthernet_Config *mac_config;
	extern XAxiEthernet_Config XAxiEthernet_ConfigTable[];

	/* obtain config of this emac */
	mac_config = &XAxiEthernet_ConfigTable[0];

	XAxiEthernet_CfgInitialize(axieth_mdio, mac_config, mac_config->BaseAddress);

	options = XAxiEthernet_GetOptions(axieth_mdio);
	// Disable recognize flow control frames
	options &= ~XAE_FLOW_CONTROL_OPTION;
	//options |= XAE_FLOW_CONTROL_OPTION;
#ifdef USE_JUMBO_FRAMES
	options |= XAE_JUMBO_OPTION;
#endif
	options |= XAE_TRANSMITTER_ENABLE_OPTION;
	options |= XAE_RECEIVER_ENABLE_OPTION;
	// Disable FCS strip
	options &= ~XAE_FCS_STRIP_OPTION;
	// Disable FCS insert (we have included it in the frame)
	options &= ~XAE_FCS_INSERT_OPTION;
	//options |= XAE_FCS_INSERT_OPTION;
	options |= XAE_MULTICAST_OPTION;
	// Using promiscuous option to disable mac address filtering
	// and allow the loopback to function.
	options |= XAE_PROMISC_OPTION;
	XAxiEthernet_SetOptions(axieth_mdio, options);
	XAxiEthernet_ClearOptions(axieth_mdio, ~options);

	/* set mac address */
	XAxiEthernet_SetMacAddress(axieth_mdio, mac_eth_addr);

	XAxiEthernet_PhySetMdioDivisor(axieth_mdio, XAE_MDIO_DIV_DFT);
}

unsigned phy_setup_axiemac (XAxiEthernet *xaxiemacp)
{
	unsigned link_speed = 1000;
	u32 port_num;
	u32 phy_addr;
	unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

	// Determine the enabled port number
	port_num = 0;  // Default port number
	for (int i = 0; i < NUM_PORTS; i++) {
	    if (xaxiemacp->Config.BaseAddress == base_addresses[i]) {
	        port_num = i;
	        break;
	    }
	}

	phy_addr = extphyaddr[port_num];

	xil_printf("Targeting PORT%d of the Ethernet FMC Max, External PHY address %d\r\n", port_num, phy_addr);

	// If enabled port is not 0, then we need to initialize the XAxiEthernet instance
	// for PORT0, so that we can use it to access the MDIO bus
	if(port_num != 0)
		init_axiemac_port0(mac_ethernet_address);
	else
		axieth_mdio = xaxiemacp;

#ifndef SDT
	if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
						XAE_PHY_TYPE_RGMII_1_3) {
		; /* Add PHY initialization code for RGMII 1.3 */
#ifndef SDT
	} else if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	} else if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
						XAE_PHY_TYPE_RGMII_2_0) {
		; /* Add PHY initialization code for RGMII 2.0 */
#ifndef SDT
	} else if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	} else if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
						XAE_PHY_TYPE_SGMII) {
#ifdef  CONFIG_LINKSPEED_AUTODETECT
		u32 phy_wr_data = IEEE_CTRL_AUTONEGOTIATE_ENABLE |
					IEEE_CTRL_LINKSPEED_1000M;
		phy_wr_data &= (~PHY_R0_ISOLATE);

		XAxiEthernet_PhyWrite(axieth_mdio,
				XPAR_AXIETHERNET_0_PHYADDR,
				IEEE_CONTROL_REG_OFFSET,
				phy_wr_data);
#endif
#ifndef SDT
	} else if (XAxiEthernet_GetPhysicalInterface(xaxiemacp) ==
#else
	} else if (XAxiEthernet_Get_Phy_Interface(xaxiemacp) ==
#endif
						XAE_PHY_TYPE_1000BASE_X) {
		; /* Add PHY initialization code for 1000 Base-X */
	}
/* set PHY <--> MAC data clock */
#ifdef  CONFIG_LINKSPEED_AUTODETECT
	link_speed = get_IEEE_phy_speed(xaxiemacp, axieth_mdio, phy_addr);
	xil_printf("auto-negotiated link speed: %d\r\n", link_speed);
#elif	defined(CONFIG_LINKSPEED1000)
	link_speed = 1000;
	configure_IEEE_phy_speed(xaxiemacp, axieth_mdio, phy_addr, link_speed);
	xil_printf("link speed: %d\r\n", link_speed);
#elif	defined(CONFIG_LINKSPEED100)
	link_speed = 100;
	configure_IEEE_phy_speed(xaxiemacp, axieth_mdio, phy_addr, link_speed);
	xil_printf("link speed: %d\r\n", link_speed);
#elif	defined(CONFIG_LINKSPEED10)
	link_speed = 10;
	configure_IEEE_phy_speed(xaxiemacp, axieth_mdio, phy_addr, link_speed);
	xil_printf("link speed: %d\r\n", link_speed);
#endif
	return link_speed;
}

static void __attribute__ ((noinline)) AxiEthernetUtilPhyDelay(unsigned int Seconds)
{
#if defined (__MICROBLAZE__)
	static int WarningFlag = 0;

	/* If MB caches are disabled or do not exist, this delay loop could
	 * take minutes instead of seconds (e.g., 30x longer).  Print a warning
	 * message for the user (once).  If only MB had a built-in timer!
	 */
	if (((mfmsr() & 0x20) == 0) && (!WarningFlag)) {
		WarningFlag = 1;
	}

#define ITERS_PER_SEC   (XPAR_CPU_CORE_CLOCK_FREQ_HZ / 6)
    __asm volatile ("\n"
			"1:               \n\t"
			"addik r7, r0, %0 \n\t"
			"2:               \n\t"
			"addik r7, r7, -1 \n\t"
			"bneid  r7, 2b    \n\t"
			"or  r0, r0, r0   \n\t"
			"bneid %1, 1b     \n\t"
			"addik %1, %1, -1 \n\t"
			:: "i"(ITERS_PER_SEC), "d" (Seconds));
#else
    sleep(Seconds);
#endif
}

