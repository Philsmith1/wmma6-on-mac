#!/bin/zsh
# Update an existing install with this repo's current Wine fixes, without reinstalling.
#
# usage: git pull && ./update.sh
#
# Uses WMMA6_HOME (default: ~/WMMA6-Mac), the same as install.sh. Quit the game first.

set -u
REPO="${0:A:h}"
WMMA6_HOME="${WMMA6_HOME:-$HOME/WMMA6-Mac}"
LIB="$WMMA6_HOME/Wine Staging.app/Contents/Resources/wine/lib/wine"

die() { print -P "%F{red}ERROR:%f $1"; exit 1; }

[ -d "$LIB" ] || die "no install found in $WMMA6_HOME (set WMMA6_HOME if you installed elsewhere)"
pgrep -qf 'Grey Dog Software.World of Mixed Martial Arts 6.' && die "quit WMMA6 first"
(cd "$REPO/fixes/wow64cpu" && shasum -a 256 -c -s SHA256SUMS) || die "fixes/wow64cpu/wow64cpu.dll checksum mismatch"
(cd "$REPO/fixes/oleaut32" && shasum -a 256 -c -s SHA256SUMS) || die "fixes/oleaut32/oleaut32.dll checksum mismatch"

for f in x86_64-windows/wow64cpu.dll:wow64cpu i386-windows/oleaut32.dll:oleaut32; do
    dst="$LIB/${f%%:*}"; src="$REPO/fixes/${f##*:}/${dst:t}"
    [ -f "$dst.orig" ] || cp -p "$dst" "$dst.orig"
    cmp -s "$src" "$dst" && print "${dst:t}: already up to date" && continue
    cp "$src" "$dst" && print "${dst:t}: updated"
done
# wineboot copied wow64cpu.dll into the prefix too.
SYS="$WMMA6_HOME/prefix/drive_c/windows/system32/wow64cpu.dll"
[ -f "$SYS" ] && ! cmp -s "$REPO/fixes/wow64cpu/wow64cpu.dll" "$SYS" && cp "$REPO/fixes/wow64cpu/wow64cpu.dll" "$SYS"

print -P "%F{green}%BDone.%b%f Start WMMA6 as usual."
