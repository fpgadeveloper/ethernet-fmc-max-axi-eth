/*
 * vadj.c — Enable VADJ 1.5V on Versal boards (vck190, vmk180, vpk120)
 *
 * Configures the power controller via LPD I2C0 (MIO 46/47) to set VADJ
 * to 1.5V, which powers the FMC+ I/Os needed by the Ethernet FMC Max card.
 */

#include "board.h"

#if defined(BOARD_VCK190) || defined(BOARD_VMK180) || defined(BOARD_VPK120) || \
    defined(BOARD_VEK280) || defined(BOARD_VHK158) || defined(BOARD_VPK180)

#include <stdio.h>
#include "xil_printf.h"
#include "xiicps.h"
#include "xparameters.h"
#include "vadj.h"

#if defined(BOARD_VCK190) || defined(BOARD_VMK180) || defined(BOARD_VPK120)

#define I2C_MUX_ADDR        0x74
#define I2C_MUX_CHANNEL     0x01

#define POWER_CTRL_ADDR     0x1E

#define IIC_SCLK_RATE       400000

static int iic_write(XIicPs *iic, u8 addr, u8 *buf, int len)
{
	int status;

	status = XIicPs_MasterSendPolled(iic, buf, len, addr);
	if (status != XST_SUCCESS)
		return status;

	while (XIicPs_BusIsBusy(iic))
		;

	return XST_SUCCESS;
}

static int iic_write_reg(XIicPs *iic, u8 addr, u8 reg, u8 val)
{
	u8 buf[2] = { reg, val };
	return iic_write(iic, addr, buf, 2);
}

int vadj_1v5_enable(void)
{
	XIicPs iic;
	XIicPs_Config *cfg;
	int status;

#if defined(SDT) && defined(XPAR_XIICPS_0_BASEADDR)
	cfg = XIicPs_LookupConfig(XPAR_XIICPS_0_BASEADDR);
#else
	cfg = XIicPs_LookupConfig(XPAR_XIICPS_0_DEVICE_ID);
#endif
	if (cfg == NULL) {
		xil_printf("VADJ: I2C0 config lookup failed\r\n");
		return XST_FAILURE;
	}

	status = XIicPs_CfgInitialize(&iic, cfg, cfg->BaseAddress);
	if (status != XST_SUCCESS) {
		xil_printf("VADJ: I2C0 init failed\r\n");
		return XST_FAILURE;
	}

	XIicPs_SetSClk(&iic, IIC_SCLK_RATE);

	/* Select I2C mux channel */
	u8 mux_ch = I2C_MUX_CHANNEL;
	status = iic_write(&iic, I2C_MUX_ADDR, &mux_ch, 1);
	if (status != XST_SUCCESS) {
		xil_printf("VADJ: I2C mux select failed\r\n");
		return XST_FAILURE;
	}

	/* Configure VADJ to 1.5V via power controller at 0x1E */
	struct { u8 reg; u8 val; } writes[] = {
		{ 0x24, 0x01 },
		{ 0x25, 0x80 },
		{ 0x3A, 0x01 },
		{ 0x3B, 0xF3 },
		{ 0x3D, 0x01 },
		{ 0x3E, 0xF3 },
		{ 0x3F, 0x00 },
		{ 0x40, 0x00 },
		{ 0x41, 0x00 },
		{ 0x42, 0x00 },
		{ 0x22, 0x80 },
	};

	for (int i = 0; i < sizeof(writes) / sizeof(writes[0]); i++) {
		status = iic_write_reg(&iic, POWER_CTRL_ADDR,
				       writes[i].reg, writes[i].val);
		if (status != XST_SUCCESS) {
			xil_printf("VADJ: write to reg 0x%02x failed\r\n",
				   writes[i].reg);
			return XST_FAILURE;
		}
	}

	xil_printf("VADJ: 1.5V enabled successfully\r\n");
	return XST_SUCCESS;
}

#else /* Other Versal boards (vek280, vhk158, vpk180) */

int vadj_1v5_enable(void)
{
	xil_printf("WARNING: VADJ for this board has not been enabled!\r\n");
	return XST_SUCCESS;
}

#endif /* BOARD_VCK190 || BOARD_VMK180 || BOARD_VPK120 */

#else /* Non-Versal boards */

#include "vadj.h"

int vadj_1v5_enable(void)
{
	return 0;
}

#endif
