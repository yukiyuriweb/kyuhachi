# Kyuhachi

A small native macOS app for playing NEC PC-9801 games from floppy and hard
disk images. It wraps the [NP2kai](https://github.com/AZO234/NP2kai) emulator core
(the same core RetroArch uses) in a SwiftUI front end, so no RetroArch, SDL or
Homebrew libraries are needed.

- Keep your games in the sidebar; each game is a set of disk images (Disk A,
  Disk B, …, and optionally a hard disk image). Double-click a game to connect
  its hard disk, put its first two floppies in FDD1/FDD2 and restart the
  machine.
- Floppy images: FDI, D88/D98, HDM, XDF, DUP, NFD, DCP and the other formats
  NP2kai reads. Hard disk images: HDI, THD, NHD, VHD, SLN (on the first IDE
  drive).
- Swap disks from the FDD1/FDD2 toolbar menus, or drop images on the screen.
- Save states: ⌘S (or the toolbar) saves the machine as it is now, with a
  screenshot; the Restore menu lists a game's states, newest first, and
  ⌘⇧S goes back to the latest one. States live in
  `~/Library/Application Support/Kyuhachi/States/` and may not load in a
  build with a different NP2kai version.
- Text is drawn with JF Dot Shinonome Mincho 16, a 16-dot bitmap font close to
  the PC-98's own. Characters it lacks (such as NEC's circled numbers) fall
  back to a system font.
- Settings (⌘,) set the machine (model, CPU clock, memory, sound board),
  volumes, the floppy seek sound, and the screen shape (square pixels or a
  4:3 monitor). A game can override the machine settings it needs from its
  context menu (Game Settings…). Machine settings apply at the next start or
  reset; volumes apply at once.
- No BIOS ROMs are needed. If you have dumps from your own machine, put them in
  `~/Library/Application Support/Kyuhachi/np2kai/` (`bios.rom`, `FONT.ROM` or
  `font.bmp`, `sound.rom`, …) and NP2kai uses them instead of its built-in
  replacements.

Requires macOS 26 or later.

## Keyboard

Keys map by position on a Japanese (JIS) Mac keyboard, which is laid out much
like the PC-98's. Some PC-98 keys have no direct counterpart:

| PC-98 | Mac |
| --- | --- |
| GRPH | Option |
| NFER / XFER | 英数 / かな |
| カナ | F15 |
| STOP / COPY | F13 / F14 |
| vf.1 / vf.2 | F11 / F12 |
| ROLL UP / ROLL DOWN | Page Up / Page Down |
| INS / DEL | Help (Insert) / Forward Delete |
| HOME CLR / HELP | Home / End |

Shortcuts with ⌘ go to the app, not the emulated machine.

## Mouse

Click the screen (or the mouse button in the toolbar) to give the mouse to
the PC-98: the Mac's pointer is hidden and held in place, and its movement and
buttons go to the emulated mouse. Press ⌘ or switch to another window to get
the pointer back.

## Building

```sh
./build.sh            # builds build/Kyuhachi.app
./build.sh --install  # also copies it to ~/Applications
```

## Licenses

Kyuhachi's own code (`Sources/Kyuhachi`, `Sources/CNP2kai/kyuhachi`,
`Sources/CNP2kai/include`, `scripts`) is under the MIT License.

`Sources/CNP2kai/np2kai` is a subset of NP2kai (revision 5939e0c) and keeps its
own licenses; see `Sources/CNP2kai/np2kai/LICENSE` and
`Sources/CNP2kai/np2kai/LICENSES/`. Most of it is MIT or modified BSD. The
fmgen sound generator (`sound/fmgen`) may only be redistributed as free
software; see `LICENSES/fmgen`. NP2kai's GPL-licensed parts are not included:
the DOSBox FPU, MAME's original OPL code and the Trident TGUI9680 emulation
are left out (NP2kai's default build does not use them either; this build
uses its SoftFloat FPU and MAME's BSD-licensed sound code), and the
libretro semaphore (`sdl/libretro/rsemaphore.c`) is replaced by
`Sources/CNP2kai/kyuhachi/semaphore.c`.

Changes made to the NP2kai sources:

- `sdl/dosio.c`: `file_attr()` returns -1 for a missing file (as the X11 port
  does), so the font ROM is generated from the TrueType font when no
  `font.bmp` exists.
- `sdl/libretro/rsemaphore.c` (GPL) is replaced by
  `Sources/CNP2kai/kyuhachi/semaphore.c`.
- `sdl/fontmng.c` is replaced by `Sources/CNP2kai/kyuhachi/fontmng_coretext.c`
  (Core Text), which also draws every glyph on a shared baseline.

`Resources/JF-Dot-ShinonomeMin16.ttf` is from the
[JF Dot fonts](http://jikasei.me/font/jf-dotfont/), an outline conversion of
the Shinonome bitmap fonts; both are in the public domain.
