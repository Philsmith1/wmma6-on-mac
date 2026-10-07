/* Reproduces the speckled-thumbnail bug in Wine's IPicture::Render.
 *
 * Build:  i686-w64-mingw32-gcc -O2 -o thumbtest.exe thumbtest.c -lole32 -loleaut32 -luuid -lgdi32
 * Run:    wine thumbtest.exe face.gif out.bmp 130 0     (0 = leave the DC's default stretch mode)
 *         wine thumbtest.exe face.gif out.bmp 130 3     (3 = COLORONCOLOR, 4 = HALFTONE)
 *
 * With unpatched Wine, mode 0 gives coloured speckle on paletted GIFs; with the patch it is clean.
 */
#define COBJMACROS
#include <windows.h>
#include <olectl.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    WCHAR path[MAX_PATH];
    IPicture *pic;
    OLE_XSIZE_HIMETRIC hw;
    OLE_YSIZE_HIMETRIC hh;
    BITMAPINFO bi = {0};
    BITMAPFILEHEADER fh = {0x4D42};
    HBITMAP bmp;
    HDC dc;
    HRESULT hr;
    void *bits;
    FILE *f;
    int w, h, mode, stride;

    if (argc < 5) { printf("usage: thumbtest <image> <out.bmp> <width> <stretch mode>\n"); return 2; }
    MultiByteToWideChar(CP_ACP, 0, argv[1], -1, path, MAX_PATH);
    CoInitialize(NULL);
    hr = OleLoadPicturePath(path, NULL, 0, 0, &IID_IPicture, (void **)&pic);
    if (FAILED(hr)) { printf("load failed %08lx\n", hr); return 1; }
    IPicture_get_Width(pic, &hw);
    IPicture_get_Height(pic, &hh);
    w = atoi(argv[3]);
    h = (int)((double)w * hh / hw);
    mode = atoi(argv[4]);

    bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = h;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 24;
    dc = CreateCompatibleDC(NULL);
    bmp = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &bits, NULL, 0);
    SelectObject(dc, bmp);
    if (mode) { SetStretchBltMode(dc, mode); SetBrushOrgEx(dc, 0, 0, NULL); }
    printf("stretch mode in use: %d\n", GetStretchBltMode(dc));

    /* same call VB6 makes: source rectangle in HIMETRIC, y flipped */
    hr = IPicture_Render(pic, dc, 0, 0, w, h, 0, hh, hw, -hh, NULL);
    printf("render %08lx, %dx%d\n", hr, w, h);
    GdiFlush();

    stride = (w * 3 + 3) & ~3;
    fh.bfOffBits = sizeof(fh) + sizeof(bi.bmiHeader);
    fh.bfSize = fh.bfOffBits + stride * h;
    f = fopen(argv[2], "wb");
    fwrite(&fh, sizeof(fh), 1, f);
    fwrite(&bi.bmiHeader, sizeof(bi.bmiHeader), 1, f);
    fwrite(bits, stride * h, 1, f);
    fclose(f);
    return 0;
}
