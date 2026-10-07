#!/bin/zsh
# Install World of Mixed Martial Arts 6 (Grey Dog Software) on an Apple Silicon Mac using Wine.
#
# usage: ./install.sh /path/to/WMMA6_Retail_Installer_XXX.msi
#
# Optional environment variables:
#   WMMA6_HOME  where everything is installed (default: ~/WMMA6-Mac)
#   APP_DIR     where the WMMA6 launcher app is created (default: ~/Applications)
#
# Nothing from Grey Dog Software or Microsoft is bundled. You supply your own WMMA6 installer
# and licence; Microsoft runtimes are downloaded from the same sources winetricks uses,
# and every download is checked against a SHA-256 checksum.

set -u
REPO="${0:A:h}"
MSI="${1:-}"
WMMA6_HOME="${WMMA6_HOME:-$HOME/WMMA6-Mac}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
LOG="$WMMA6_HOME/install.log"

WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.18/wine-staging-11.18-osx64.tar.xz"
WINE_SHA="b63704b91af269bc026a87f12bd297c4a50caaf570c322e600b6621ef918f127"
MDAC_URL="https://web.archive.org/web/20060718123742/http://ftp.gunadarma.ac.id/pub/driver/itegno/USB%20Software/MDAC/MDAC_TYP.EXE"
MDAC_SHA="36d2a3099e6286ae3fab181a502a95fbd825fa5ddb30bf09b345abc7f1f620b4"
JET_URL="https://web.archive.org/web/20210225171713/http://download.microsoft.com/download/4/3/9/4393c9ac-e69e-458d-9f6d-2fe191c51469/Jet40SP8_9xNT.exe"
JET_SHA="b060246cd499085a31f15873689d5fa7df817e407c8261a5c71fa6b9f7042560"

step() { print -P "\n%B==> $1%b"; print "\n==> $1" >> "$LOG"; }
die()  { print -P "%F{red}ERROR:%f $1"; print "ERROR: $1" >> "$LOG"; exit 1; }
run()  { "$@" >> "$LOG" 2>&1; }

# Download $1 to $2 unless already present, then verify SHA-256 $3.
fetch() {
    [ -f "$2" ] || curl -fL --retry 3 -o "$2" "$1" >> "$LOG" 2>&1 || die "download failed: $1"
    [ "$(shasum -a 256 "$2" | cut -d' ' -f1)" = "$3" ] || { rm -f "$2"; die "checksum mismatch for $2 (deleted, rerun to retry)"; }
}

# ---------------------------------------------------------------------------------------------
[ -n "$MSI" ] && [ -f "$MSI" ] || die "usage: ./install.sh /path/to/WMMA6_Retail_Installer_XXX.msi"
MSI="${MSI:A}"
[ "$(uname -m)" = arm64 ] || die "this installer is for Apple Silicon Macs"
mkdir -p "$WMMA6_HOME" "$APP_DIR" || die "cannot create $WMMA6_HOME"
: > "$LOG"
print "Installing WMMA6 into $WMMA6_HOME (log: $LOG)"

step "Checking Rosetta 2 and Homebrew tools"
if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    print "Rosetta 2 is needed. Installing it (you may be asked for your password)..."
    softwareupdate --install-rosetta --agree-to-license || die "Rosetta 2 install failed"
fi
command -v brew >/dev/null || die "Homebrew is required: see https://brew.sh"
for t in winetricks cabextract; do command -v $t >/dev/null || run brew install $t || die "brew install $t failed"; done

step "1/8  Downloading Wine 11.18 Staging (Gcenx build)"
CACHE="$WMMA6_HOME/downloads"; mkdir -p "$CACHE"
WINEAPP="$WMMA6_HOME/Wine Staging.app"
if [ ! -d "$WINEAPP" ]; then
    fetch "$WINE_URL" "$CACHE/wine-staging-11.18-osx64.tar.xz" "$WINE_SHA"
    run tar -xJf "$CACHE/wine-staging-11.18-osx64.tar.xz" -C "$WMMA6_HOME" || die "could not unpack Wine"
    xattr -dr com.apple.quarantine "$WINEAPP" 2>/dev/null
fi

step "2/8  Installing the two Wine fixes (Rosetta mode switch, thumbnail quality)"
(cd "$REPO/fixes/wow64cpu" && shasum -a 256 -c -s SHA256SUMS) || die "fixes/wow64cpu/wow64cpu.dll checksum mismatch"
(cd "$REPO/fixes/oleaut32" && shasum -a 256 -c -s SHA256SUMS) || die "fixes/oleaut32/oleaut32.dll checksum mismatch"
LIB="$WINEAPP/Contents/Resources/wine/lib/wine"
for f in x86_64-windows/wow64cpu.dll:wow64cpu i386-windows/oleaut32.dll:oleaut32; do
    dst="$LIB/${f%%:*}"; src="$REPO/fixes/${f##*:}/${dst:t}"
    [ -f "$dst.orig" ] || cp -p "$dst" "$dst.orig"
    cp "$src" "$dst"
done

cat > "$WMMA6_HOME/wmma6-env.sh" <<EOF
export PATH="$WINEAPP/Contents/Resources/wine/bin:\$PATH"
export WINEPREFIX="$WMMA6_HOME/prefix"
export WINEDEBUG=-all
EOF
source "$WMMA6_HOME/wmma6-env.sh"

step "3/8  Creating the Wine prefix"
run wineboot -u; run wineserver -w
cmp -s "$WINEPREFIX/drive_c/windows/system32/wow64cpu.dll" "$REPO/fixes/wow64cpu/wow64cpu.dll" || die "Rosetta fix missing from the prefix"
# Block .NET's background native-image compiler: under Wine it never exits and stalls the install.
run wine reg add 'HKCU\Software\Wine\DllOverrides' /v mscorsvw.exe /d "" /f

step "4/8  Installing MDAC 2.7 (database components)"
WTC="$HOME/.cache/winetricks"; mkdir -p "$WTC/mdac27" "$WTC/jet40"
fetch "$MDAC_URL" "$WTC/mdac27/MDAC_TYP.EXE" "$MDAC_SHA"
for d in msado15 odbccp32 mtxdm odbc32 oledb32; do
    run wine reg add 'HKCU\Software\Wine\DllOverrides' /v "*$d" /t REG_SZ /d native,builtin /f
done
# Its self-extractor fails under WoW64 ("Error creating process <setup /qnt>"), so unpack it by hand.
rm -rf "$WINEPREFIX/drive_c/windows/temp/mdac27x"
run cabextract -q -d "$WINEPREFIX/drive_c/windows/temp/mdac27x" "$WTC/mdac27/MDAC_TYP.EXE"
run winetricks -q -f nt40
(cd "$WINEPREFIX/drive_c/windows/temp/mdac27x" && run wine setup.exe /qnt); run wineserver -w
[ -f "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/System/ADO/msado26.tlb" ] || die "MDAC 2.7 did not install"

step "5/8  Installing Windows Script Host 5.7 and Jet 4.0 SP8"
run winetricks -q -f wsh57
fetch "$JET_URL" "$WTC/jet40/jet40sp8_9xnt.exe" "$JET_SHA"
(cd "$WTC/jet40" && run wine jet40sp8_9xnt.exe /q); run wineserver -w
[ -f "$WINEPREFIX/drive_c/windows/syswow64/msjet40.dll" ] || die "Jet 4.0 did not install"
run winetricks -q win10
printf 'mdac27\njet40\n' >> "$WINEPREFIX/winetricks.log"   # stop winetricks reinstalling them

step "6/8  Installing fonts, VB6 runtime and .NET Framework 4.8 (about 15 minutes)"
run winetricks -q -f corefonts tahoma vb6run dotnet48
# Use Wine's oleaut32 (with the thumbnail fix). vb6run's native oleaut32 makes WMMA6 stop
# with "Run-time error '50003': Unexpected error".
run wine reg add 'HKCU\Software\Wine\DllOverrides' /v '*oleaut32' /d builtin /f
run wineserver -w
[ -f "$WINEPREFIX/drive_c/windows/syswow64/msvbvm60.dll" ] || die "VB6 runtime did not install"
wine reg query 'HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full' /v Release 2>/dev/null | grep -q 0x80eb1 \
    || die ".NET Framework 4.8 did not install (see $LOG)"

step "7/8  Installing WMMA6 from ${MSI:t}"
cp "$MSI" "$WINEPREFIX/drive_c/windows/temp/wmma6.msi"
run wine msiexec /i 'C:\windows\temp\wmma6.msi' /qn; run wineserver -w
rm -f "$WINEPREFIX/drive_c/windows/temp/wmma6.msi"
EXE=$(find "$WINEPREFIX/drive_c" -name WMMA6.exe -path "*Grey Dog Software*" 2>/dev/null | head -1)
[ -n "$EXE" ] || die "WMMA6 did not install (see $LOG)"
GAMEDIR="${EXE:h}"

step "8/8  Creating the WMMA6 launcher"
cp "$REPO/tools/winewindows.js" "$WMMA6_HOME/"
cat > "$WMMA6_HOME/wmma6.sh" <<EOF
#!/bin/zsh
# Launch WMMA6. Keeps the display awake while playing, and shuts Wine down once the game has had
# no windows for 30 seconds (after quitting, the game process can otherwise linger invisibly).
source "$WMMA6_HOME/wmma6-env.sh"
GAME='Grey Dog Software.World of Mixed Martial Arts 6.WMMA6\\.exe'
ALL='Grey Dog Software.World of Mixed Martial Arts 6.'   # the game and its separate License Wizard
cd "$GAMEDIR" || exit 1   # must start from the game folder, or QLM fails with run-time error 5
pgrep -qf "\$GAME" && exit 0
caffeinate -d -w \$\$ &
wine WMMA6.exe "\$@" &
pid=""
for i in {1..30}; do sleep 2; pid=\$(pgrep -f "\$GAME" | head -1); [ -n "\$pid" ] && break; done
if [ -n "\$pid" ]; then
  seen=0; gone=0; waited=0
  while kill -0 \$pid 2>/dev/null; do
    sleep 5; waited=\$((waited+5))
    if [ "\$(osascript -l JavaScript "$WMMA6_HOME/winewindows.js" \$(pgrep -f "\$ALL"))" -gt 0 ]; then seen=1; gone=0; else gone=\$((gone+5)); fi
    [ \$seen = 1 ] && [ \$gone -ge 30 ] && break
    [ \$seen = 0 ] && [ \$waited -ge 300 ] && break
  done
fi
wineserver -k
EOF
chmod +x "$WMMA6_HOME/wmma6.sh"
APP="$APP_DIR/WMMA6.app"
rm -rf "$APP"
run osacompile -o "$APP" -e "do shell script \"nohup '$WMMA6_HOME/wmma6.sh' > '$WMMA6_HOME/last-run.log' 2>&1 &\""
ICO="$GAMEDIR/System/WMMA6.ico"
if [ -f "$ICO" ]; then
    T=$(mktemp -d); mkdir "$T/i.iconset"
    sips -s format png "$ICO" --out "$T/icon.png" >/dev/null 2>&1 \
      && for s in 16 32 128 256 512; do sips -z $s $s "$T/icon.png" --out "$T/i.iconset/icon_${s}x${s}.png" >/dev/null; done \
      && iconutil -c icns "$T/i.iconset" -o "$APP/Contents/Resources/applet.icns" && touch "$APP"
    rm -rf "$T"
fi

print -P "\n%F{green}%BDone!%b%f  Start the game with %BWMMA6%b in $APP_DIR (or Spotlight: \"WMMA6\")."
print "On first launch the License Wizard opens after 10-20 seconds: choose 'Activate your license'."
