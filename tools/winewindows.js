// usage: osascript -l JavaScript winewindows.js <pid> [<pid> ...]
// Prints how many real windows (visible or minimised) belong to the given processes.
// Uses only owner PID and bounds, which macOS provides without Screen Recording permission.
// Ignored: VB6's hidden 1x1 owner window, thin off-screen strips, and Wine's hidden
// off-screen 500x500 helper windows.
ObjC.import('CoreGraphics');
function run(argv) {
  var pids = argv.map(function (p) { return parseInt(p, 10); });
  var list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, 0))) || [];
  var n = 0;
  list.forEach(function (w) {
    if (pids.indexOf(w.kCGWindowOwnerPID) < 0 || w.kCGWindowLayer !== 0) return;
    var b = w.kCGWindowBounds;
    if (b.Width <= 50 || b.Height <= 50) return;
    if (!w.kCGWindowIsOnscreen && b.Width === 500 && b.Height === 500) return;
    n++;
  });
  return String(n);
}
