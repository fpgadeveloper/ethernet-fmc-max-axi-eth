#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
"""
Generate the block diagrams for the Opsero Ethernet FMC Max (OP080) AXI Ethernet
reference design docs.

The design connects each of the four 1G SGMII ports of the Ethernet FMC Max to an
AXI 1G/2.5G Ethernet Subsystem (tri-mode MAC + SGMII PCS/PMA, configured for SGMII)
and an AXI DMA. Per port: RJ45 -> TI DP83867 PHY on the FMC -> SGMII over one FMC
gigabit lane (DPn) -> FPGA transceiver -> AXI Ethernet -> AXI-Stream -> AXI DMA ->
system memory. The four PHYs share one MDIO bus, driven by axi_ethernet_0. A 125 MHz
Si511 on the FMC supplies the transceiver reference clock (GBTCLK0_M2C).

Four PNGs are written next to this script (i.e. into docs/source/images/):
    axi-eth-block-diagram.png      family-neutral overview (description page)
    axi-eth-bd-zynqmp.png          Vivado view, Zynq UltraScale+ (bd_zynqmp.tcl)
    axi-eth-bd-versal.png          Vivado view, Versal (bd_versal.tcl)
    axi-eth-bd-microblaze.png      Vivado view, MicroBlaze (bd_mb.tcl)

The content follows Vivado/src/bd/bd_*.tcl and the per-target XDC files; update
this script when the block design changes.

Usage (from anywhere):
    python3 docs/source/images/gen_block_diagram.py
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, FancyArrowPatch
from matplotlib.lines import Line2D

# ---- palette (shared with the other Opsero reference-design block diagrams) --
C_PS_FILL      = "#D9D9D9"; C_PS_EDGE      = "#7F7F7F"   # processor / DDR column
C_FAB_FILL     = "#F2F2F2"; C_FAB_EDGE     = "#BFBFBF"   # FPGA fabric container
C_DMA_FILL     = "#808080"; C_DMA_EDGE     = "#404040"   # AXI DMA (dark grey)
C_MAC_FILL     = "#E8E8F2"; C_MAC_EDGE     = "#8C8CC0"   # MAC / PCS logic (lavender)
C_GT_FILL      = "#F3EFE2"; C_GT_EDGE      = "#BFB585"   # hard blocks: GT (cream)
C_FMC_FILL     = "#DCE6F2"; C_FMC_EDGE     = "#9DB7D4"   # external FMC (blue-grey)
C_PHY_FILL     = "#FFFFFF"                                # PHYs / RJ45 (white on FMC)
C_CLK_FILL     = "#FDE9D9"; C_CLK_EDGE     = "#E0B090"   # clocking (peach)
C_CTRL_FILL    = "#ECECEC"; C_CTRL_EDGE    = "#BFBFBF"   # control plane
C_AXARR_FILL   = "#EDF3D4"; C_AXARR_EDGE   = "#A6B85A"   # data arrows (pale green)
C_LINKARR_FILL = "#DAE8F5"; C_LINKARR_EDGE = "#6F9FCF"   # link arrows (pale blue)
C_REFCLK_LINE  = "#C8823C"                                # refclk arrows (orange)
C_MDIO         = "#5E8C1E"                                # MDIO bus (green)
C_RST          = "#B04A4A"                                # PHY resets (red)
C_MUTED        = "#606060"
TXT = "#1A1A1A"


def box(ax, x, y, w, h, fc, ec, label, fs=10, rot=0, lw=1.2, weight="normal",
        txtcolor=None, ls="-", z=2):
    ax.add_patch(plt.Rectangle((x, y), w, h, fc=fc, ec=ec, lw=lw, ls=ls, zorder=z))
    if label:
        ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
                fontsize=fs, rotation=rot, color=txtcolor or TXT, weight=weight,
                zorder=z + 1, linespacing=1.25)


def titled_box(ax, x, y, w, h, fc, ec, title, body, title_fs=9.5, body_fs=7.6,
               lw=1.2, txtcolor=None, title_dy=2.6, ls="-"):
    """A box() with a bold title line at the top and a smaller body below it."""
    box(ax, x, y, w, h, fc, ec, "", lw=lw, ls=ls)
    cx = x + w / 2
    ax.text(cx, y + h - title_dy, title, ha="center", va="center",
            fontsize=title_fs, weight="bold", color=txtcolor or TXT, zorder=3,
            linespacing=1.15)
    ax.text(cx, y + (h - title_dy * 1.9) / 2, body, ha="center", va="center",
            fontsize=body_fs, color=txtcolor or TXT, zorder=3, linespacing=1.3)


def harrow(ax, x0, x1, yc, label, fc, ec, double=True, bh=1.4, hh=2.5, hl=1.8,
           fs=8.0, lw=1.1, lab_dy=0.0):
    """Horizontal block arrow from x0 to x1 (double-headed, or head at x1)."""
    if double:
        pts = [(x0, yc), (x0 + hl, yc + hh), (x0 + hl, yc + bh),
               (x1 - hl, yc + bh), (x1 - hl, yc + hh), (x1, yc),
               (x1 - hl, yc - hh), (x1 - hl, yc - bh),
               (x0 + hl, yc - bh), (x0 + hl, yc - hh)]
    else:
        s = 1.0 if x1 >= x0 else -1.0
        neck = x1 - s * hl
        pts = [(x0, yc + bh), (neck, yc + bh), (neck, yc + hh),
               (x1, yc), (neck, yc - hh), (neck, yc - bh), (x0, yc - bh)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=2))
    if label:
        ax.text((x0 + x1) / 2, yc + lab_dy, label, ha="center", va="center",
                fontsize=fs, color=TXT, zorder=3, linespacing=1.15)


def line_arrow(ax, pts, color, lw=1.6, head=True, ls="-"):
    """Thin poly-line through pts, with an arrow head at the last point."""
    xs, ys = zip(*pts[:-1] if head else pts)
    ax.add_line(Line2D(xs, ys, color=color, lw=lw, zorder=4, ls=ls,
                       solid_capstyle="butt", solid_joinstyle="miter"))
    if head:
        ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle="-|>",
                                     mutation_scale=11, lw=lw, color=color,
                                     zorder=4, shrinkA=0, shrinkB=0))


def label(ax, x, y, s, fs=7.2, color=C_MUTED, ha="center", weight="normal", rot=0):
    ax.text(x, y, s, ha=ha, va="center", fontsize=fs, color=color, zorder=5,
            linespacing=1.2, weight=weight, rotation=rot)


# -----------------------------------------------------------------------------
# Per-family content (from Vivado/src/bd/bd_*.tcl)
# -----------------------------------------------------------------------------
PHY_ADDR = [1, 3, 12, 15]      # external TI DP83867 PHYs on the shared MDIO bus
PCS_ADDR = [2, 4, 13, 14]      # internal SGMII PCS/PMA PHYs (CONFIG.PHYADDR)

FAMILIES = {
    "overview": dict(
        out="axi-eth-block-diagram.png",
        fabric="FPGA fabric (PL)",
        ps_title="Processor\nsystem",
        ps_body="Zynq UltraScale+ PS\n(Arm Cortex-A53)\n\nor\n\nVersal CIPS\n(Arm Cortex-A72)\n\nor\n\nMicroBlaze\n(UltraScale /\nUltraScale+ FPGA)\n\n"
                "Linux (PetaLinux,\nYocto) or bare-metal\nlwIP echo server",
        mem="System memory\n(DDR)",
        xbar="Memory path:  AXI SmartConnect (ZynqMP, MicroBlaze)  /  NoC (Versal)",
        ctrl_title="Control plane: AXI-Lite",
        ctrl_body="AXI Ethernet + AXI DMA registers per port\n"
                  "AXI GPIO (in): FMC power good + PHY GPIOs\n"
                  "interrupts: 4 per port (MAC, Ethernet, MM2S, S2MM)",
        clk_title="Clocking",
        clk_body="125 MHz GT reference: Si511 on the FMC (GBTCLK0)\n"
                 "50 MHz ref_clk (AXI Ethernet)\n"
                 "100 MHz AXI / AXIS / DMA clock",
        gt="GT\n\nSGMII\n1.25 Gb/s",
        gt_shared=False,
        port_note="",
    ),
    "zynqmp": dict(
        out="axi-eth-bd-zynqmp.png",
        fabric="Zynq UltraScale+ PL  (bd_zynqmp.tcl)",
        ps_title="zynq_ultra_\nps_e_0",
        ps_body="Zynq UltraScale+ PS\n(board preset)\n\nM_AXI_HPM0_FPD\n→ AXI-Lite control\n\nS_AXI_HP0_FPD\n← DMA memory path\n\n"
                "pl_clk0: 100 MHz\npl_clk1: 50 MHz\n(IOPLL on UZ-EV)\n\npl_ps_irq0 / irq1\n← xlconcat_0 / _1",
        mem="PS DDR4",
        xbar="axi_smc  (AXI SmartConnect)  →  S_AXI_HP0_FPD   ·   SG / MM2S / S2MM of every DMA",
        ctrl_title="Control plane (from M_AXI_HPM0_FPD)",
        ctrl_body="axi_ethernet_N/s_axi, axi_ethernet_N_dma/S_AXI_LITE, axi_gpio_0 (10 inputs:\n"
                  "PG_1V0, PG_2V5, PHY GPIO0/1 x4)  ·  rst_100m (proc_sys_reset)\n"
                  "interrupts: mac_irq, interrupt, mm2s_introut, s2mm_introut per port",
        clk_title="Clocking",
        clk_body="gt_ref_clk 125 MHz (FMC Si511, GBTCLK0) → axi_ethernet_0/mgt_clk\n"
                 "pl_clk1 50 MHz → ref_clk of every port\n"
                 "pl_clk0 100 MHz → AXI-Lite, AXIS, DMAs, SmartConnect",
        gt="GTH / GTY\nin the\nAXI Eth.\ncore",
        gt_shared=False,
        port_note="port 0: SupportLevel 1 (shared logic in core);\n"
                  "ports 1-3: SupportLevel 0, clocks from port 0\n"
                  "PHY reset: axi_ethernet_N/phy_rst_n (unused ports held in reset)\n"
                  "zcu104 (LPC): port 0 only",
    ),
    "versal": dict(
        out="axi-eth-bd-versal.png",
        fabric="Versal PL  (bd_versal.tcl)",
        ps_title="versal_\ncips_0",
        ps_body="Versal CIPS\n\nM_AXI_LPD\n→ AXI-Lite control\n\npl0_ref_clk: 100 MHz\npl1_ref_clk: 50 MHz\n\n"
                "PMC_GPIO_o[3:0]\n→ PHY resets\n(EMIO, released by\nU-Boot / app)\n\npl_ps_irqN\n← 4 per port",
        mem="DDR4 / LPDDR4\n(via NoC)",
        xbar="axi_noc_0  (NoC, 18 slave ports)  →  DDR memory controller   ·   3 ports per DMA (SG / MM2S / S2MM)",
        ctrl_title="Control plane (M_AXI_LPD → axi_smc / automation)",
        ctrl_body="axi_ethernet_N/s_axi, axi_ethernet_N_dma/S_AXI_LITE, axi_gpio_0 (10 inputs)\n"
                  "axi_apb_bridge_0 → gt_quad_base_0 APB3 (transceiver DRP)\n"
                  "xlslice_phyN: PMC_GPIO_o bit N → reset_port_N",
        clk_title="Clocking",
        clk_body="gt_ref_clk 125 MHz (FMC Si511, GBTCLK0)\n"
                 "→ util_ds_buf_0 (IBUFDSGTE) → gt_quad_base_0 GT_REFCLK0/1\n"
                 "4 BUFG_GT per port\n"
                 "(rxuserclk/rxuserclk2/userclk 62.5 MHz, userclk2 125 MHz)",
        gt="gt_quad_base_0\n\nGTY / GTYP\nquad\n\nEthernet_1G\npreset,\n4 channels\n\n"
           "RXn/TXn_GT_IP_\nInterface\n→ axi_ethernet_N\n(IS_GT_WIZ_OLD)",
        gt_shared=True,
        port_note="per port: 4x bufg_gt;\npma_reset from rst_pl0;\nsignal_detect + mmcm_locked tied high",
    ),
    "microblaze": dict(
        out="axi-eth-bd-microblaze.png",
        fabric="UltraScale / UltraScale+ FPGA  (bd_mb.tcl)",
        ps_title="microblaze_0",
        ps_body="MicroBlaze\n(MMU, 64 KB I/D cache,\n64 KB local memory)\n\nmicroblaze_0_axi_intc\naxi_uartlite_0\n(115200 baud)\naxi_timer_0\n\n"
                "ddr4_0 (MIG):\naddn_ui_clkout1\n100 MHz\naddn_ui_clkout2\n50 MHz",
        mem="DDR4\n(ddr4_0 MIG)",
        xbar="axi_smc  (AXI SmartConnect)  →  ddr4_0/C0_DDR4_S_AXI   ·   SG / MM2S / S2MM of every DMA",
        ctrl_title="Control plane (microblaze_0_axi_periph)",
        ctrl_body="axi_ethernet_N/s_axi, axi_ethernet_N_dma/S_AXI_LITE, axi_gpio_0 (10 inputs),\n"
                  "axi_timer_0, axi_uartlite_0  ·  all interrupts → microblaze_0_xlconcat\n"
                  "→ microblaze_0_axi_intc",
        clk_title="Clocking",
        clk_body="gt_ref_clk 125 MHz (FMC Si511, GBTCLK0) → axi_ethernet_0/mgt_clk\n"
                 "ddr4_0 addn_ui_clkout2 50 MHz → ref_clk of every port\n"
                 "ddr4_0 addn_ui_clkout1 100 MHz → AXI, AXIS, DMAs",
        gt="GTH / GTY\nin the\nAXI Eth.\ncore",
        gt_shared=False,
        port_note="port 0: SupportLevel 1 (shared logic in core);\n"
                  "ports 1-3: SupportLevel 0, clocks from port 0\n"
                  "PHY reset: axi_ethernet_N/phy_rst_n",
    ),
}


def draw(fam):
    spec = FAMILIES[fam]
    overview = fam == "overview"
    fig, ax = plt.subplots(figsize=(17.0, 11.6), dpi=120)
    ax.set_xlim(0, 170)
    ax.set_ylim(0, 116)
    ax.axis("off")

    # rows: port 0 at the top
    row_h = 13.0
    row_y = [83.0, 67.0, 51.0, 35.0]
    row_c = [y + row_h / 2 for y in row_y]
    rows_top, rows_bot = row_y[0] + row_h, row_y[-1]

    # ---- processor column ----------------------------------------------------
    ps_x, ps_w = 2.0, 19.0
    titled_box(ax, ps_x, 99.0, ps_w, 12.0, C_PS_FILL, C_PS_EDGE, "Memory",
               spec["mem"], title_fs=10, body_fs=7.6, title_dy=3.0, lw=1.3)
    titled_box(ax, ps_x, 4.0, ps_w, 92.0, C_PS_FILL, C_PS_EDGE, spec["ps_title"],
               spec["ps_body"], title_fs=11, body_fs=7.6, title_dy=5.0, lw=1.3)

    # ---- fabric container ----------------------------------------------------
    fab_x0, fab_x1 = 25.0, 124.0
    ax.add_patch(plt.Rectangle((fab_x0, 2.0), fab_x1 - fab_x0, 109.5,
                               fc=C_FAB_FILL, ec=C_FAB_EDGE, lw=1.3, zorder=1))
    ax.text((fab_x0 + fab_x1) / 2, 112.2, spec["fabric"], ha="center", va="bottom",
            fontsize=13, weight="bold", color=TXT)

    # memory interconnect (horizontal bar above the rows)
    xb_y0, xb_h = 101.0, 7.0
    box(ax, 28.0, xb_y0, 93.0, xb_h, C_PS_FILL, C_PS_EDGE, spec["xbar"], fs=8.0,
        weight="bold", lw=1.2)
    harrow(ax, ps_x + ps_w, 28.0, xb_y0 + xb_h / 2, "", C_AXARR_FILL, C_AXARR_EDGE,
           bh=1.4, hh=2.5, hl=1.2)

    # ---- per-port rows ---------------------------------------------------------
    # vertical AXI MM bus from the DMAs up to the memory interconnect
    box(ax, 26.0, row_c[-1] - 1.5, 1.6, xb_y0 - row_c[-1] + 1.5, C_AXARR_FILL,
        C_AXARR_EDGE, "", lw=1.0)
    label(ax, 30.0, row_y[0] + row_h + 4.0, "AXI MM: SG, MM2S, S2MM per DMA",
          fs=6.6, ha="left")
    dma_x, dma_w = 32.0, 20.0
    mac_x, mac_w = 61.0, 29.0
    gt_x, gt_w = 99.0, 15.0 if spec["gt_shared"] else 11.0
    for p in range(4):
        y0, yc = row_y[p], row_c[p]
        titled_box(ax, dma_x, y0, dma_w, row_h, C_DMA_FILL, C_DMA_EDGE,
                   f"axi_ethernet_{p}_dma",
                   "AXI DMA\nscatter-gather\nMM2S = TX, S2MM = RX\nunaligned (DRE)",
                   title_fs=7.6, body_fs=6.8, txtcolor="#FFFFFF", title_dy=2.4)
        # DMA -> memory interconnect: AXI MM masters onto the vertical bus
        harrow(ax, 27.6, dma_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE, double=False,
               bh=0.9, hh=1.8, hl=1.2)
        titled_box(ax, mac_x, y0, mac_w, row_h, C_MAC_FILL, C_MAC_EDGE,
                   f"axi_ethernet_{p}",
                   "AXI 1G/2.5G Ethernet Subsystem\ntri-mode MAC + SGMII PCS/PMA\n"
                   f"PCS/PMA (internal PHY) @ MDIO {PCS_ADDR[p]}\nfull TX/RX checksum offload",
                   title_fs=8.6, body_fs=6.8, title_dy=2.4)
        harrow(ax, dma_x + dma_w, mac_x, yc + 2.6, "", C_AXARR_FILL, C_AXARR_EDGE,
               double=False, bh=1.1, hh=2.0, hl=1.6)
        harrow(ax, mac_x, dma_x + dma_w, yc - 2.6, "", C_AXARR_FILL, C_AXARR_EDGE,
               double=False, bh=1.1, hh=2.0, hl=1.6)
        label(ax, (dma_x + dma_w + mac_x) / 2, yc + 5.6, "AXIS TX\n(txd + txc)", fs=6.4)
        label(ax, (dma_x + dma_w + mac_x) / 2, yc - 5.6, "AXIS RX\n(rxd + rxs)", fs=6.4)
        if not spec["gt_shared"]:
            box(ax, gt_x, y0 + 1.0, gt_w, row_h - 2.0, C_GT_FILL, C_GT_EDGE,
                spec["gt"], fs=7.0)
            harrow(ax, mac_x + mac_w, gt_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
                   bh=1.1, hh=2.0, hl=1.2)
        else:
            harrow(ax, mac_x + mac_w, gt_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
                   bh=1.1, hh=2.0, hl=1.2)
    if spec["gt_shared"]:
        box(ax, gt_x, rows_bot + 1.0, gt_w, rows_top - rows_bot - 2.0, C_GT_FILL,
            C_GT_EDGE, spec["gt"], fs=7.2)

    # shared-logic note
    if spec["port_note"]:
        label(ax, mac_x + mac_w / 2, rows_bot - 3.6, spec["port_note"], fs=6.8,
              color=C_MUTED)
    # MDIO master: axi_ethernet_0 only
    mdio_y = row_y[0] + row_h - 1.5

    # ---- bottom strip: control plane + clocking ------------------------------------
    titled_box(ax, 28.0, 4.0, 52.0, 18.0, C_CTRL_FILL, C_CTRL_EDGE,
               spec["ctrl_title"], spec["ctrl_body"], title_fs=8.4, body_fs=6.9,
               title_dy=2.8)
    harrow(ax, ps_x + ps_w, 28.0, 13.0, "", C_CTRL_FILL, C_PS_EDGE, double=False,
           bh=1.4, hh=2.5, hl=1.4)
    titled_box(ax, 82.0, 4.0, 40.0, 18.0, C_CLK_FILL, C_CLK_EDGE,
               spec["clk_title"], spec["clk_body"], title_fs=8.4, body_fs=6.7,
               title_dy=2.8)

    # ---- external: Ethernet FMC Max ----------------------------------------------
    fmc_x0, fmc_x1 = 128.0, 168.0
    ax.add_patch(plt.Rectangle((fmc_x0, 2.0), fmc_x1 - fmc_x0, 109.5,
                               fc=C_FMC_FILL, ec=C_FMC_EDGE, lw=1.3, zorder=1))
    ax.text((fmc_x0 + fmc_x1) / 2, 112.2, "External to FPGA", ha="center",
            va="bottom", fontsize=12, weight="bold", color=TXT)
    ax.text((fmc_x0 + fmc_x1) / 2, 105.0, "Ethernet FMC Max (OP080)\nVADJ = 1.5 V",
            ha="center", va="center", fontsize=9.6, weight="bold", color=TXT,
            linespacing=1.3)
    phy_x, phy_w = 136.0, 17.0
    rj_x, rj_w = 156.0, 9.5
    for p in range(4):
        y0, yc = row_y[p], row_c[p]
        titled_box(ax, phy_x, y0 + 0.5, phy_w, row_h - 1.0, C_PHY_FILL, C_FMC_EDGE,
                   f"PHY {p}", f"TI DP83867\nSGMII, 10/100/1000\nMDIO addr {PHY_ADDR[p]}",
                   title_fs=8.4, body_fs=6.8, title_dy=2.2)
        box(ax, rj_x, y0 + 3.0, rj_w, row_h - 6.0, C_PHY_FILL, C_FMC_EDGE,
            f"RJ45\nport {p}", fs=7.2, weight="bold")
        ax.add_line(Line2D([phy_x + phy_w, rj_x], [yc, yc], color=C_FMC_EDGE,
                           lw=2.2, zorder=3))
        # SGMII lane over the FMC
        harrow(ax, gt_x + gt_w, phy_x, yc, "", C_LINKARR_FILL, C_LINKARR_EDGE,
               bh=1.6, hh=2.8, hl=1.4)
        label(ax, (gt_x + gt_w + phy_x) / 2, yc + 4.4, f"FMC DP{p}\nSGMII", fs=6.6,
              color=TXT)

    # Si511 reference clock
    si_y0, si_y1 = 24.0, 31.5
    titled_box(ax, phy_x, si_y0, phy_w + 12.0, si_y1 - si_y0, C_CLK_FILL, C_CLK_EDGE,
               "Si511 oscillator", "125 MHz → GBTCLK0_M2C", title_fs=8.0,
               body_fs=6.8, title_dy=2.0)
    line_arrow(ax, [(phy_x, si_y0 + 2.0), (gt_x + gt_w / 2, si_y0 + 2.0),
                    (gt_x + gt_w / 2, rows_bot + (1.0 if spec["gt_shared"] else 1.0))],
               C_REFCLK_LINE, lw=1.8)
    label(ax, 126.0, si_y0 + 4.0, "GT refclk", fs=6.8, color=C_REFCLK_LINE,
          weight="bold")

    # power-good / PHY GPIO / reset signals
    titled_box(ax, phy_x, 4.0, phy_w + 12.0, 17.0, C_PHY_FILL, C_FMC_EDGE,
               "Sideband (FMC LA pins)",
               "PG_1V0, PG_2V5 → axi_gpio_0\nPHY GPIO0/1 (x4) → axi_gpio_0\n"
               "PHY RESET_N (x4) ← FPGA\nMDC / MDIO (shared bus)",
               title_fs=8.0, body_fs=6.8, title_dy=2.4)

    # shared MDIO bus from axi_ethernet_0 to all four PHYs
    bus_x = 126.0
    line_arrow(ax, [(mac_x + mac_w - 4.0, row_y[0] + row_h),
                    (mac_x + mac_w - 4.0, row_y[0] + row_h + 1.6),
                    (bus_x, row_y[0] + row_h + 1.6),
                    (bus_x, row_c[3] - 3.6)], C_MDIO, lw=1.6, head=False)
    for p in range(4):
        line_arrow(ax, [(bus_x, row_c[p] - 3.6), (phy_x, row_c[p] - 3.6)], C_MDIO,
                   lw=1.4)
    label(ax, (mac_x + mac_w + bus_x) / 2 + 3.0, row_y[0] + row_h + 3.2,
          "MDIO (one shared bus, mastered by axi_ethernet_0)", fs=6.8,
          color=C_MDIO, weight="bold")

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), spec["out"])
    fig.savefig(out, bbox_inches="tight", pad_inches=0.15, facecolor="white")
    plt.close(fig)
    print("wrote", out)


def main():
    for fam in FAMILIES:
        draw(fam)


if __name__ == "__main__":
    main()
