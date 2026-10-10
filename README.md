# World of Mixed Martial Arts 6 on an Apple Silicon Mac

A one-step installer that runs **WMMA6** (Grey Dog Software) on an Apple Silicon Mac with Wine. That includes the licence activation, which otherwise hangs.

Tested on an M5 Max with macOS 27.0, Wine 11.18 Staging (Gcenx build), winetricks 20260125, WMMA6 retail 1.09 (patched to 1.10) and the 1.08 trial. Tested in play: new game, many weeks simulated through events, save, reload, fighter photos, and an hour of unattended simming with memory steady at about 50 MB.

> Grey Dog Software doesn't support Macs, and this project isn't affiliated with them. Please don't ask them for help with it. Use this repo's issues instead.

---

## What you need

- An **Apple Silicon** Mac (M1 or later). The installer offers to install **Rosetta 2** if it's missing.
- **[Homebrew](https://brew.sh)**. The installer adds `winetricks` and `cabextract` from it.
- About **4 GB** of free space and an internet connection.
- Your **WMMA6 installer** (`WMMA6_Retail_Installer_XXX.msi`) from Grey Dog Software, and your licence key.

No game files or Microsoft files are included here. Microsoft's runtimes are downloaded from the same sources winetricks uses, and each download is checked against a SHA-256 checksum.

## Install

```sh
git clone https://github.com/Philsmith1/wmma6-on-mac.git
cd wmma6-on-mac
./install.sh ~/Downloads/WMMA6_Retail_Installer_109.msi
```

If you downloaded the ZIP instead, first run `xattr -dr com.apple.quarantine wmma6-on-mac` on the unzipped folder.

The install takes 20 to 40 minutes, mostly for .NET. You may see Wine installer windows flash past; they don't need you. Everything goes into `~/WMMA6-Mac`, and a **WMMA6** app appears in `~/Applications`. Set `WMMA6_HOME` or `APP_DIR` to change those locations.

## Play

Open **WMMA6** from `~/Applications` or Spotlight. The first time, the **License Wizard** appears after 10 to 20 seconds. Click **Activate your license**, enter your key, and the game starts.

The launcher keeps your display awake while you play. If the display sleeps, the game window can go blank. When you quit, the launcher shuts Wine down about 30 seconds after the game's last window closes.

## Updating

If you installed before 9 October 2026, update to get the fix for crashes during long sims (see **Troubleshooting**). Updating after 10 October also fixes white or black boxes around fighter photos. Quit the game, then in the `wmma6-on-mac` folder run:

```sh
git pull
./update.sh
```

If you downloaded the ZIP, download it again and run `./update.sh` from the new folder. It only replaces the fixed Wine files. Your game, saves and licence aren't touched.

## Mods and picture packs

Mods and picture packs install the same way as on Windows. Follow the mod's own instructions, using this game folder:

```
~/WMMA6-Mac/prefix/drive_c/Program Files (x86)/Grey Dog Software/World of Mixed Martial Arts 6/
```

To open it in Finder, run `open ~/WMMA6-Mac/prefix/drive_c/Program\ Files\ \(x86\)/Grey\ Dog\ Software/World\ of\ Mixed\ Martial\ Arts\ 6`. Databases (mods) go in its `Databases` folder, and pictures go in its `Pictures` folder. Quit the game before copying files in.

Large databases haven't been tested yet. If you try one, please report how it goes in this repo's issues.

## Game patches

Grey Dog patches are a replacement `WMMA6.exe`. Quit the game, then copy the new file over the old one in:

```
~/WMMA6-Mac/prefix/drive_c/Program Files (x86)/Grey Dog Software/World of Mixed Martial Arts 6/
```

The new version number appears in the game's title bar.

## Moving to another Mac

The licence can be active on one computer at a time. **Deactivate it first** with the **License Management** button on the game's main menu. Grey Dog's QLM customer site can also deactivate it.

## Troubleshooting

| Problem | Fix |
|---|---|
| Wine or the game is stuck | `source ~/WMMA6-Mac/wmma6-env.sh && wineserver -k` |
| The game never opens; the log shows `nested exception on signal stack` | The Rosetta fix isn't in place. Don't replace or update `~/WMMA6-Mac/Wine Staging.app`. Rerun `install.sh`. |
| `Run-time error '50003': Unexpected error` at startup | The native oleaut32 override is active. Run `source ~/WMMA6-Mac/wmma6-env.sh && wine reg add 'HKCU\Software\Wine\DllOverrides' /v '*oleaut32' /d builtin /f` |
| `Run-time error '5'` at startup | The game was started from the wrong folder. Use the WMMA6 app. |
| White or black boxes around fighter faces, bodies or belts | Installs from before 10 October 2026 lose GIF transparency. Run `./update.sh` (see **Updating**). |
| The game crashes during long sims or loading screens, often with `Error 3035: System resource exceeded` | Installs from before 9 October 2026 slowly run out of memory. Run `./update.sh` (see **Updating**). If it still happens after updating, please open an issue. |
| Install failed | Read `~/WMMA6-Mac/install.log`. Rerunning `install.sh` is safe. |

## Uninstall

Deactivate your licence first if you'll use it elsewhere. Back up any saves from the game folder's `Databases/…/SaveGames`, then:

```sh
source ~/WMMA6-Mac/wmma6-env.sh && wineserver -k
rm -rf ~/WMMA6-Mac ~/Applications/WMMA6.app
```

---

## How it works

WMMA6 is a 32-bit Visual Basic 6 program. It keeps its data in Access databases (DAO 3.6 / Jet 4.0) and checks your licence with QLM, which loads 32-bit .NET Framework into the game process. Wine on macOS runs 32-bit Windows code inside 64-bit processes ("WoW64") on Rosetta 2. Five problems needed solving.

**1. The licence check hangs (Rosetta fix).** Every 32-bit .NET program hangs under Wine on Apple Silicon with `nested exception on signal stack`. Wine's `wow64cpu.dll` switches the CPU between 32-bit and 64-bit mode with far *jumps*, and Rosetta 2 sometimes doesn't switch modes on one. The fix uses far *returns* instead. It comes from [kic99/TEW_IX_on_Mac](https://github.com/kic99/TEW_IX_on_Mac), and Sikarugir uses a similar workaround. → `fixes/wow64cpu/`

**2. Error 50003 with the native oleaut32.** The TEW IX guide installs the year-2000 native `oleaut32.dll` from the VB6 runtime. WMMA6 can't load one of its images with it and stops with run-time error 50003. This installer uses Wine's own oleaut32 instead.

**3. Speckled thumbnails with Wine's oleaut32.** When Wine's `IPicture::Render` shrinks an image, it uses the device context's default stretch mode, `BLACKONWHITE`. On paletted GIFs that ANDs neighbouring pixels together, so small fighter photos turn into coloured speckle. The fix sets `COLORONCOLOR` for the draw and then restores the previous mode. → `fixes/oleaut32/`

**4. Crashes in long sims (memory leak in Wine's oleaut32).** Wine's `OleLoadPicture` only gives a picture ownership of its bitmap when `fRunmode` is FALSE. VB6 passes TRUE, so the bitmap stays behind when the picture is freed. On Windows a loaded picture always owns its bitmap. WMMA6 loads a full-screen background (about 2 MB) every time a fight is processed. After about three hours of simming, its 2 GB of 32-bit address space was full and the next allocation failed: `Error 3035: System resource exceeded`, often in `wAdvanceFight`. The fix makes loaded pictures own their bitmaps. `fixes/oleaut32/leaktest.c` loads and frees a fight background 300 times: 589 MB leaked without the fix, 0 MB with it. → `fixes/oleaut32/`

**5. White and black boxes around fighter photos (Wine's oleaut32).** WMMA6's face, body and belt GIFs are 256-colour images with one colour marked transparent. Since April 2025, Wine has kept such images in 256 colours, but it only builds a transparency mask for 32-bit images. So the transparency was lost: faces got white boxes over backdrops, and bodies and belts got black boxes. The fix converts 256-colour images that have a transparent colour to 32-bit again, as Wine did before. [kic99](https://github.com/kic99/TEW_IX_on_Mac) spotted this in TEW IX. → `fixes/oleaut32/`

Other details:
- **MDAC 2.7** is unpacked with `cabextract` and set up directly, because its self-extractor fails under WoW64.
- **Jet 4.0 SP8** is installed from its own installer.
- **.NET's background compiler** (`mscorsvw.exe`) is blocked, because under Wine it never exits and stalls the install. .NET then compiles code as it runs, which is fine.

## The fixes

Both DLLs are built from Wine 11.18 source (the oleaut32 one with the Wine Staging v11.18 patches applied) and are licensed under the LGPL 2.1 (`COPYING.LIB`). Each folder has the patch and a `SHA256SUMS` file. To build them yourself, see [`fixes/README.md`](fixes/README.md). The installer keeps Wine's originals as `*.orig`.

## Credits

- [kic99/TEW_IX_on_Mac](https://github.com/kic99/TEW_IX_on_Mac): the Rosetta `wow64cpu` fix and the MDAC/Jet/.NET approach this builds on
- [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds)
- [winetricks](https://github.com/Winetricks/winetricks)
- [Wine](https://www.winehq.org) and [Wine Staging](https://github.com/wine-staging/wine-staging)
