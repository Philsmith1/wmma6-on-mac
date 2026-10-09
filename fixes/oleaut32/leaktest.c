#define COBJMACROS
#include <windows.h>
#include <ole2.h>
#include <olectl.h>
#include <stdio.h>
/* leaktest <image> : load the picture 300 times the way VB6 does (OleLoadPicture, fRunmode=TRUE),
   release it each time, and report how much committed private memory the process gained. */
static SIZE_T committed(void) {
    MEMORY_BASIC_INFORMATION m; char *a = 0; SIZE_T t = 0;
    while (VirtualQuery(a, &m, sizeof(m))) { if (m.State == MEM_COMMIT && m.Type == MEM_PRIVATE) t += m.RegionSize; a = (char *)m.BaseAddress + m.RegionSize; if ((ULONG_PTR)a >= 0x7fff0000) break; }
    return t;
}
int main(int argc, char **argv) {
    CoInitialize(NULL);
    HANDLE f = CreateFileA(argv[1], GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    DWORD size = GetFileSize(f, NULL), got; HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE, size);
    ReadFile(f, GlobalLock(g), size, &got, NULL); GlobalUnlock(g); CloseHandle(f);
    SIZE_T before = committed();
    for (int i = 0; i < 300; i++) {
        IStream *s; IPicture *p; CreateStreamOnHGlobal(g, FALSE, &s);
        HRESULT hr = OleLoadPicture(s, size, TRUE, &IID_IPicture, (void **)&p);
        if (FAILED(hr)) { printf("load failed %lx\n", hr); return 1; }
        IPicture_Release(p); IStream_Release(s);
    }
    printf("300 loads: committed memory grew by %lu MB\n", (unsigned long)((committed() - before) >> 20));
    return 0;
}
