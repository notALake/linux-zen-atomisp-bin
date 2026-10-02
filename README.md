# linux-zen-atomisp

Kernel Arch co-installabile `linux-zen-atomisp`: linux-zen ufficiale
+ `CONFIG_INTEL_ATOMISP=m` + `CONFIG_VIDEO_ATOMISP=m` + sensori (OV8835 per HP Pavilion x2) - `CONFIG_INTEL_ATOMISP2_PDX86`.

Build automatica con GitHub Actions: ogni giorno controlla la versione
ufficiale di `linux-zen` e se e nuova compila e pubblica in Releases.

Installazione (dalla pagina Releases):
```bash
sudo pacman -U linux-zen-atomisp-*.pkg.tar.zst linux-zen-atomisp-headers-*.pkg.tar.zst
sudo grub-mkconfig -o /boot/grub/grub.cfg
# firmware CherryTrail ISP2401 manuale:
sudo cp shisp_2401a0_v21.bin /lib/firmware/
sudo modprobe atomisp
ls /dev/video*
```
