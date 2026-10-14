#!/usr/bin/env python3
"""X11 test helper: click at window-relative coordinates (needs libX11 + libXtst).
Usage: xclick.py 0xWINDOWID  x,y | move:x,y | key:Name  ...   (window id from `wmctrl -l`)"""
import ctypes, sys, time
from ctypes import c_void_p, c_int, c_ulong, byref
x11 = ctypes.CDLL('libX11.so.6'); xt = ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.restype = c_void_p
d = c_void_p(x11.XOpenDisplay(None))
root = x11.XDefaultRootWindow(d)
win = int(sys.argv[1], 16)
import subprocess
def origin():
    x = c_int(); y = c_int(); child = c_ulong()
    x11.XTranslateCoordinates(d, c_ulong(win), c_ulong(root), 0, 0, byref(x), byref(y), byref(child))
    return x.value, y.value
def toplevel_of(w):
    """The top-level window (child of the root window) that contains w."""
    for _ in range(32):
        root_ret = c_ulong(); parent = c_ulong(); kids = ctypes.POINTER(c_ulong)(); n = ctypes.c_uint()
        if not x11.XQueryTree(d, c_ulong(w), byref(root_ret), byref(parent), byref(kids), byref(n)):
            return 0
        if parent.value == root or parent.value == 0:
            return w
        w = parent.value
    return 0


def toplevel_at(x, y):
    """The top-level window that is on top at screen point (x, y)."""
    dx = c_int(); dy = c_int(); child = c_ulong()
    x11.XTranslateCoordinates(d, c_ulong(root), c_ulong(root), x, y, byref(dx), byref(dy), byref(child))
    return child.value


def _on_top():
    # probe a spot near the bottom-left of the window, away from popup menus
    ox, oy = origin()
    return toplevel_at(ox + 5, oy + 500) == toplevel_of(win)


try:
    if not _on_top():       # raising closes popup menus, so only when really needed
        subprocess.call(['wmctrl', '-i', '-a', sys.argv[1]])
        time.sleep(0.25)
except OSError:
    pass


def pid_of(w):
    """The process that owns window w (via xprop), or None."""
    try:
        out = subprocess.run(['xprop', '-id', hex(w), '_NET_WM_PID'], capture_output=True,
                             text=True, timeout=3).stdout
        return int(out.split('=')[1].strip())
    except Exception:
        return None


def click(rx, ry):
    ox, oy = origin()
    # never click on something that is not the target window; its own popup menus
    # (same process) are fine
    top = toplevel_at(ox + rx, oy + ry)
    if top != toplevel_of(win):
        mine = pid_of(win) or pid_of(toplevel_of(win))
        theirs = pid_of(top)
        if mine is None or theirs != mine:
            sys.stderr.write("xclick: the window at that point is not the target; click skipped\n")
            sys.exit(3)
    x11.XWarpPointer(d, 0, c_ulong(root), 0, 0, 0, 0, ox + rx, oy + ry)
    x11.XFlush(d); time.sleep(0.15)
    xt.XTestFakeButtonEvent(d, 1, 1, 0); x11.XFlush(d); time.sleep(0.08)
    xt.XTestFakeButtonEvent(d, 1, 0, 0); x11.XFlush(d); time.sleep(0.5)
def key(name):
    """Press and release a key by X name (Down, Return, Escape...). Goes to whatever
    has the keyboard focus, which for a popup menu is the menu."""
    ks = x11.XStringToKeysym(name.encode())
    kc = x11.XKeysymToKeycode(d, ks)
    xt.XTestFakeKeyEvent(d, kc, 1, 0); x11.XFlush(d); time.sleep(0.06)
    xt.XTestFakeKeyEvent(d, kc, 0, 0); x11.XFlush(d); time.sleep(0.25)


def move(rx, ry):
    ox, oy = origin()
    x11.XWarpPointer(d, 0, c_ulong(root), 0, 0, 0, 0, ox + rx, oy + ry)
    x11.XFlush(d); time.sleep(0.2)


for a in sys.argv[2:]:
    if a.startswith('key:'):
        key(a[4:])
        continue
    if a.startswith('move:'):
        x, y = map(int, a[5:].split(','))
        move(x, y)
        continue
    x, y = map(int, a.split(','))
    click(x, y)
