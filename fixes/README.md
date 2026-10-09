# The two Wine fixes

Both are small patches to Wine 11.18 and are licensed under the LGPL 2.1 (`../COPYING.LIB`). The prebuilt DLLs match the Gcenx **Wine 11.18 Staging** build. Each folder has a `SHA256SUMS` file. Your own builds will have different checksums because of compiler versions and timestamps.

| Folder | Replaces (inside `Wine Staging.app/Contents/Resources/wine/lib/wine/`) | Fixes |
|---|---|---|
| `wow64cpu/` | `x86_64-windows/wow64cpu.dll` | 32-bit .NET (the QLM licence check) hanging under Rosetta 2 |
| `oleaut32/` | `i386-windows/oleaut32.dll` | Speckled, shrunk GIF thumbnails; picture memory leak that crashed long sims |

`wineboot` copies `wow64cpu.dll` from the Wine app into each prefix, so the app copy has to be patched before the prefix is created. For an existing prefix, also copy it to `drive_c/windows/system32/`. Wine loads `oleaut32.dll` straight from the app.

## Building

You need `brew install mingw-w64` and the Wine 11.18 source.

### wow64cpu.dll (Rosetta fix)

The patch and its build script come from [kic99/TEW_IX_on_Mac](https://github.com/kic99/TEW_IX_on_Mac/tree/main/wow64cpu-rosetta-fix), where the cause is explained in detail. In short:

```sh
curl -fLO https://dl.winehq.org/wine/source/11.x/wine-11.18.tar.xz
tar -xJf wine-11.18.tar.xz wine-11.18/include wine-11.18/dlls/wow64cpu
patch wine-11.18/dlls/wow64cpu/cpu.c wow64cpu/wow64cpu-rosetta-farjump.patch
# then compile and link as in kic99's build.sh: import libraries generated from the installed
# Wine's ntdll.dll and wow64.dll, image base 0x7a400000, then write the
# "Wine builtin DLL" signature at offset 0x40
```

### oleaut32.dll (thumbnail and picture-leak fixes)

Build it from the **Staging** source, because Wine Staging patches oleaut32 too:

```sh
brew install mingw-w64 autoconf automake bison flex
curl -fL https://dl.winehq.org/wine/source/11.x/wine-11.18.tar.xz | tar -xJ
curl -fL https://github.com/wine-staging/wine-staging/archive/refs/tags/v11.18.tar.gz | tar -xz
python3 wine-staging-11.18/staging/patchinstall.py DESTDIR=wine-11.18 --all --backend=patch
patch -d wine-11.18 -p1 < oleaut32/oleaut32-stretchmode.patch
patch -d wine-11.18 -p1 < oleaut32/oleaut32-picture-leak.patch
cd wine-11.18
export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:$PATH"
arch -x86_64 ./configure CC="clang -arch x86_64" --enable-archs=i386,x86_64 --without-x --without-freetype \
    --without-gstreamer --without-vulkan --without-sdl --without-cups --without-gnutls --without-krb5
arch -x86_64 make -j8 dlls/oleaut32/i386-windows/oleaut32.dll
i686-w64-mingw32-strip -o oleaut32.dll dlls/oleaut32/i386-windows/oleaut32.dll
```

## Testing the thumbnail fix

`IPicture::Render` in `dlls/oleaut32/olepicture.c` draws with `StretchBlt` and leaves the device context's stretch mode as it is. The default is `BLACKONWHITE`, which ANDs the source pixels that get dropped. On a paletted GIF those are palette indices, which produces coloured speckle. The patch sets `COLORONCOLOR` for the draw and then restores the previous mode. `HALFTONE` isn't used, because the masked (transparent) path also goes through this function.

`oleaut32/thumbtest.c` reproduces it. It loads a GIF with `OleLoadPicturePath` and `Render`s it at about 40% size into a memory DC, the same call VB6 makes. Without the patch the result is speckled. With the patch it's clean.

## Testing the picture-leak fix

`OleLoadPicture` and `OleLoadPictureEx` in `dlls/oleaut32/olepicture.c` create the picture with `fOwn = !fRunmode`. VB6 passes `fRunmode = TRUE`, so the picture doesn't own the bitmap it decodes, and `Release` never deletes it. On Windows a loaded picture owns its bitmap. The patch passes `TRUE`. The leaked bitmaps live in the process's own memory, so a 32-bit game runs out of address space. In WMMA6 that showed up as Jet `Error 3035: System resource exceeded` after about three hours of simming.

`oleaut32/leaktest.c` loads an image 300 times with `OleLoadPicture(..., fRunmode = TRUE, ...)`, releases each one, and prints how much committed memory grew. With WMMA6's 1111×617 `Live_Fight.jpg`, it grew by 589 MB without the patch and 0 MB with it. Build it with `i686-w64-mingw32-gcc -O2 -o leaktest.exe leaktest.c -lole32 -loleaut32 -luuid`.
