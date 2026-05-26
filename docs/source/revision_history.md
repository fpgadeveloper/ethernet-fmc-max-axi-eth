# Revision History

## 2025.2

* Updated reference designs and PetaLinux BSPs for Vivado/Vitis/PetaLinux 2025.2.
* Vitis flow switched to the universal Python-based build driver
  (`Vitis/py/build-vitis.py` + `args.json`); `lwip_echo_server` template
  with patched `lwip220` and `xiltimer` BSP libraries.
* Versal targets: standalone application now programs VADJ to 1.5V via I2C0
  (PMBus power controller) at startup; VEK280 is exempt as it enables
  VADJ from the platform.
* ZCU104 FSBL patch rewritten for the 2025.2 FSBL source layout — fixes
  the EEPROM address, TCA9548A mux channel, and read length so the FSBL
  can detect the FMC VADJ requirement on this board.
* PetaLinux 2025.2 renames network interfaces to predictable `endN`
  names — see [petalinux](petalinux) for the per-target mapping.

## 2024.1

* First revision

