# linux-zen-atomisp

Kernel Arch `linux-zen-atomisp`: linux-zen + atomISP enabled
and camera MT9M114 fixes for HP Pavilion x2 (board 813E).

The fixes are made by GLM-5.3

Install:
```bash
sudo pacman -U linux-zen-atomisp-*.pkg.tar.zst linux-zen-atomisp-headers-*.pkg.tar.zst

sudo cp shisp_2401a0_v21.bin /lib/firmware/

reboot
```
