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
# upstream chiama il file config.$CARCH (es. config.x86_64) e PKGBUILD fa
# `cp ../config.$CARCH .config`, quindi il file DEVE stare in $WORKDIR con quel nome.
# CARCH non e' ancora definito (makepkg non e' partito): default x86_64.
: "${CARCH:=x86_64}"
if [ -f "config.$CARCH" ]; then
  CFGFILE="config.$CARCH"
elif [ -f config ]; then
  CFGFILE=config
else
  echo "ERRORE: nessun config.$CARCH ne config trovato in $WORKDIR, PKGBUILD upstream cambiato"
  ls -la
  exit 1
fi
echo "    config da patchare: $CFGFILE"
cp ../atomisp.conf ./atomisp.conf
# Applica riga per riga: gestisce sia X=m sia "# X is not set"
while IFS= read -r line || [ -n "$line" ]; do
  # salta vuote e commenti semplici (ma non "# CONFIG_... is not set")
  if [[ "$line" =~ ^#\ CONFIG_.*\ is\ not\ set$ ]]; then
    sym=$(echo "$line" | awk '{print $2}' | cut -d= -f1)
    # rimuovi eventuale riga esistente e aggiungi disabilitazione
    sed -i "/^${sym}=/d" "$CFGFILE"
    sed -i "/^# ${sym} is not set/d" "$CFGFILE"
    echo "$line" >> "$CFGFILE"
  elif [[ "$line" =~ ^CONFIG_ ]]; then
    sym=$(echo "$line" | cut -d= -f1)
    val=$(echo "$line" | cut -d= -f2-)
    sed -i "/^${sym}=/d" "$CFGFILE"
    sed -i "/^# ${sym} is not set/d" "$CFGFILE"
    echo "${sym}=${val}" >> "$CFGFILE"
  fi
done < atomisp.conf
rm atomisp.conf

echo "==> config patchato, verifica:"
grep -E "ATOMISP" "$CFGFILE" || true

echo "==> Aggiungo patch camera (patches/*.patch) a source[] del PKGBUILD"
# Il PKGBUILD upstream ha un loop in prepare() che applica con 'patch -Np1'
# ogni file *.patch elencato in source[]. Appendo i nostri patch in coda
# (dopo il patch ufficiale zen, contro cui sono generati) e li copio nella
# dir del PKGBUILD. Checksum: 'SKIP' (file locali, non scaricati).
cp ../patches/*.patch .
python3 - <<'PYEOF'
import re, glob

patches = sorted(glob.glob('0*.patch'))
assert len(patches) == 4, f"attesi 4 patch, trovati {len(patches)}: {patches}"

src = open('PKGBUILD').read()

# 1) source(): nomi dei patch prima della ')' che chiude l'array
m = re.search(r"\)\nsource_x86_64=", src)
assert m, "chiusura di source() non trovata"
entries = '\n'.join(f'  {p}' for p in patches)
src = src[:m.start()] + entries + '\n' + src[m.start():]

# 2) b2sums(): 'SKIP' in coda (stessa posizione dei patch in source)
m = re.search(r"\)\nb2sums_x86_64=", src)
assert m, "chiusura di b2sums() non trovata"
skip_b = '\n' + '\n'.join(["        'SKIP'"] * len(patches))
src = src[:m.start()] + skip_b + src[m.start():]

# 3) sha256sums(): idem
m = re.search(r"\)\n\nexport KBUILD_BUILD_HOST=", src)
assert m, "chiusura di sha256sums() non trovata"
skip_s = '\n' + '\n'.join(["            'SKIP'"] * len(patches))
src = src[:m.start()] + skip_s + src[m.start():]

open('PKGBUILD', 'w').write(src)
print("    source[] += " + ', '.join(patches))
print("    checksum += 'SKIP' x%d (b2sums + sha256sums)" % len(patches))
PYEOF

# makepkg valida i checksum delle fonti PRIMA di prepare(), e noi abbiamo appena
# modificato $CFGFILE: il checksum in b2sums_x86_64 non corrisponde piu'.
# Gli array checksum devono restare allineati 1:1 con source[], quindi NON
# cancelliamo la voce (romperebbe gli indici): ricalcoliamo l'hash del file
# patchato, cosi' l'integrita' continua a essere verificata.
if [ "$CFGFILE" = "config.$CARCH" ]; then
  echo "==> Ricalcolo i checksum di $CFGFILE nel PKGBUILD"
  for arr in b2sums_x86_64 sha256sums_x86_64; do
    grep -q "^${arr}=(" PKGBUILD || continue
    case "$arr" in
      b2sums_x86_64)     tool=b2sum     ;;
      sha256sums_x86_64) tool=sha256sum ;;
    esac
    if command -v "$tool" >/dev/null 2>&1; then
      NEWHASH=$("$tool" "$CFGFILE" | cut -d' ' -f1)
    else
      # tool assente: SKIP e' un valore accettato da makepkg
      NEWHASH=SKIP
      echo "    $tool non disponibile, uso SKIP per $arr"
    fi
    # l'array per arch qui contiene una sola entry (il config)
    sed -i "s#^${arr}=(.*#${arr}=('${NEWHASH}')#" PKGBUILD
    echo "    $arr = $NEWHASH"
  done
else
  echo "AVVISO: $CFGFILE non e' config.$CARCH, checksum non aggiornato"
fi

echo "OK. Ora makepkg -s gestira olddefconfig in prepare()."
