#if defined(CONFIG_MICROBLAZE)
#include <configs/microblaze-generic.h>
#define CONFIG_SYS_BOOTM_LEN 0xF000000
#endif
#if defined(CONFIG_ARCH_ZYNQ)
#include <configs/zynq-common.h>
#endif
#if defined(CONFIG_ARCH_ZYNQMP)
#include <configs/xilinx_zynqmp.h>
#endif
#if defined(CONFIG_ARCH_VERSAL)
#include <configs/xilinx_versal.h>

/*
 * Opsero Inc. 2024 Jeff Johnson
 * 
 * The following adds a U-boot environment variable: phy_reset.
 * This variable contains a set of U-boot commands that will configure 4x PMC GPIOs that
 * are connected to the Ethernet FMC Max PHY active-low resets. The commands configure 
 * those GPIOs as outputs, then drives them LOW for 0.2s before driving them HIGH
 * (deassert reset). This is necessary on the Versal boards that have a ZynqMP system 
 * controller (VCK190, VMK180, VHK158, VPK120 and VPK180). The ZU4 based system controller
 * is too slow to enable VADJ before the Versal device has begun its boot sequence. Since
 * the reset signals are driven by FMC I/Os, they are not effective before VADJ is enabled.
 * Hence the need to perform the reset in U-boot, after enabling VADJ.
 *
 * The boot command is overwritten such that it runs this environment variable 
 * before running distro_bootcmd.
 *
 */

#define PHY_RESET_SETTINGS \
	"phy_reset=" \
		"mw 0xf10202c4 0x0000000f;" \
		"mw 0xf10202c8 0x0000000f;" \
		"mw 0xf102004c 0x00000000;" \
		"sleep 0.2;" \
		"mw 0xf102004c 0x0000000f\0" \
	
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	PHY_RESET_SETTINGS \
	BOOTENV

#define CONFIG_BOOTCOMMAND "run phy_reset; run distro_bootcmd"
#endif
#if defined(CONFIG_ARCH_VERSAL_NET)
#include <configs/xilinx_versal_net.h>
#endif
