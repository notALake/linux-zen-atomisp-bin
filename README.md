# linux-zen-atomisp

Kernel Arch co-installabile `linux-zen-atomisp`: linux-zen ufficiale
con supporto AtomISP (Cherry Trail / Bay Trail) e i patch di fix per la
camera MT9M114 dell'HP Pavilion x2 (board 813E).

Cosa contiene (vedi `atomisp.conf` e `patches/`):
- `CONFIG_INTEL_ATOMISP=y` (menuconfig *bool*: mai `=m`!) + `CONFIG_VIDEO_ATOMISP=m`
- patch 0001: mt9m114 attende 20ms la stabilizzazione del modulo prima
  del reset (la probe falliva ~70% delle volte con -EREMOTEIO)
- patch 0002: atomisp csi2 bridge: camera HP 813E montata capovolta
  (rotation 180; il firmware non lo dichiara, _PLD = 0)
- patch 0003: mt9m114 default hflip/vflip=1 se rotation==180

Build automatica con GitHub Actions: ogni giorno (06:00 UTC) controlla
la versione ufficiale di `linux-zen` e se cambia compila e pubblica in
Releases con tag `v<versione>-atomisp<N>`.

Installazione (dalla pagina Releases):
```bash
sudo pacman -U linux-zen-atomisp-*.pkg.tar.zst linux-zen-atomisp-headers-*.pkg.tar.zst
sudo grub-mkconfig -o /boot/grub/grub.cfg      # GRUB
sudo bootctl update && sudo reinstall-kernels   # systemd-boot
# firmware CherryTrail ISP2401 (NON incluso in linux-firmware):
sudo cp shisp_2401a0_v21.bin /lib/firmware/
# atomisp + mt9m114 si caricano da soli via udev (attenzione: nessun
# file /etc/modprobe.d/*blacklist* per mt9m114!)
v4l2-ctl --list-devices
```
