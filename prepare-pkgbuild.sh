#!/usr/bin/env bash
# Clona il packaging ufficiale linux-zen e lo rinomina in linux-zen-atomisp.
# Da eseguire dentro il container Arch prima di makepkg.
# Uso: ./prepare-pkgbuild.sh
set -euo pipefail

UPSTREAM_URL="https://gitlab.archlinux.org/archlinux/packaging/packages/linux-zen.git"
WORKDIR="upstream-linux-zen"

rm -rf "$WORKDIR"
git clone --depth 1 "$UPSTREAM_URL" "$WORKDIR"
cd "$WORKDIR"

echo "==> Rinominato pkgbase/pkgname linux-zen -> linux-zen-atomisp"
# pkgbase
sed -i 's/^pkgbase=linux-zen$/pkgbase=linux-zen-atomisp/' PKGBUILD
# nomi pacchetto (non toccare gli URL zen-kernel)
sed -i "s/'linux-zen-headers'/'linux-zen-atomisp-headers'/g" PKGBUILD
sed -i "s/'linux-zen-docs'/'linux-zen-atomisp-docs'/g" PKGBUILD
# attenzione: sostituire 'linux-zen' da solo solo se e un nome pacchetto tra apici
sed -i "s/'linux-zen'/'linux-zen-atomisp'/g" PKGBUILD
# preset/install: se esistono file con linux-zen nel nome, rinominali
for f in linux-zen.preset 70-linux-zen.preset linux-zen.install; do
  if [ -f "$f" ]; then
    nf=$(echo "$f" | sed 's/linux-zen/linux-zen-atomisp/g')
    git mv "$f" "$nf" 2>/dev/null || mv "$f" "$nf"
  fi
done
# riferimenti interni ai path boot/preset (escludi URL http)
# `|| true`: grep esce 1 se non trova nulla e, con `set -e` + `pipefail`,
# ucciderebbe lo script. 2>/dev/null nasconde solo stderr, non l'exit code.
grep -rl 'linux-zen' --include='*.install' --include='*.preset' . 2>/dev/null | while read -r f; do
  sed -i 's/linux-zen/linux-zen-atomisp/g' "$f"
done || true
# ripristina URL upstream zen-kernel se toccati per sbaglio
sed -i 's#github.com/linux-zen-atomisp/zen-kernel#github.com/zen-kernel/zen-kernel#g' PKGBUILD
sed -i 's#zen-kernel/linux-zen-atomisp#zen-kernel/zen-kernel#g' PKGBUILD

echo "==> Applico fragment atomisp.conf al config"
if [ ! -f config ]; then
  echo "ERRORE: file 'config' non trovato in $WORKDIR, PKGBUILD upstream cambiato"
  ls -la
  exit 1
fi
cp ../atomisp.conf ./atomisp.conf
# Applica riga per riga: gestisce sia X=m sia "# X is not set"
while IFS= read -r line || [ -n "$line" ]; do
  # salta vuote e commenti semplici (ma non "# CONFIG_... is not set")
  if [[ "$line" =~ ^#\ CONFIG_.*\ is\ not\ set$ ]]; then
    sym=$(echo "$line" | awk '{print $2}' | cut -d= -f1)
    # rimuovi eventuale riga esistente e aggiungi disabilitazione
    sed -i "/^${sym}=/d" config
    sed -i "/^# ${sym} is not set/d" config
    echo "$line" >> config
  elif [[ "$line" =~ ^CONFIG_ ]]; then
    sym=$(echo "$line" | cut -d= -f1)
    val=$(echo "$line" | cut -d= -f2-)
    sed -i "/^${sym}=/d" config
    sed -i "/^# ${sym} is not set/d" config
    echo "${sym}=${val}" >> config
  fi
done < atomisp.conf
rm atomisp.conf

echo "==> config patchato, verifica:"
grep -E "ATOMISP" config || true

echo "OK. Ora makepkg -s gestira olddefconfig in prepare()."
