#define COBJMACROS
#include <windows.h>
#include <ole2.h>
#include <olectl.h>
#include <stdio.h>
/* overtest <image> <out.bmp> <width> : Render the picture (as VB6 does) at <width> px over a red/blue backdrop */
int main(int argc, char **argv) {
    CoInitialize(NULL);
    HANDLE f = CreateFileA(argv[1], GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    DWORD size = GetFileSize(f, NULL), got; HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE, size);
    ReadFile(f, GlobalLock(g), size, &got, NULL); GlobalUnlock(g); CloseHandle(f);
    IStream *s; IPicture *p; CreateStreamOnHGlobal(g, FALSE, &s);
    OleLoadPicture(s, size, TRUE, &IID_IPicture, (void **)&p);
    OLE_XSIZE_HIMETRIC hw; OLE_YSIZE_HIMETRIC hh; IPicture_get_Width(p, &hw); IPicture_get_Height(p, &hh);
    int w = atoi(argv[3]), h = MulDiv(w, hh, hw);
    BITMAPINFO bi = {{sizeof(BITMAPINFOHEADER), w, -h, 1, 24, BI_RGB}}; void *bits;
    HDC dc = CreateCompatibleDC(NULL); HBITMAP bmp = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &bits, NULL, 0); SelectObject(dc, bmp);
    for (int y = 0; y < h; y++) { RECT r = {0, y, w, y + 1}; HBRUSH b = CreateSolidBrush(RGB(200 - y * 150 / h, 30, 50 + y * 150 / h)); FillRect(dc, &r, b); DeleteObject(b); }
    IPicture_Render(p, dc, 0, 0, w, h, 0, hh, hw, -hh, NULL);
    BITMAPFILEHEADER fh = {0x4d42, 0, 0, 0, sizeof(fh) + sizeof(BITMAPINFOHEADER)}; int stride = (w * 3 + 3) & ~3;
    fh.bfSize = fh.bfOffBits + stride * h; bi.bmiHeader.biHeight = -h;
    FILE *o = fopen(argv[2], "wb"); fwrite(&fh, sizeof(fh), 1, o); fwrite(&bi.bmiHeader, sizeof(BITMAPINFOHEADER), 1, o); fwrite(bits, stride * h, 1, o); fclose(o);
    return 0;
}
