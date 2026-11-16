// Public interface of the NP2kai core as seen from Swift.
//
// The core is driven through the standard libretro API. A few internal
// NP2kai functions are declared here as well, so the app can do things the
// libretro API does not cover (such as choosing the font, or inserting a
// disk into the second floppy drive).

#pragma once

#include "../np2kai/sdl/libretro/libretro-common/include/libretro.h"

/// Sets the TrueType/OpenType font used to generate the PC-98 font ROM
/// (font.tmp) and to draw the core's own menus.
void fontmng_setdeffontname(const char *name);

/// Inserts a disk image into floppy drive `drive` (0 = FDD1, 1 = FDD2).
/// Must be called on the thread that runs the core.
void kyuhachi_set_fdd(unsigned drive, const char *path);

/// Inserts a disk image without the usual insertion delay, for use right
/// before a reset (when starting a game). Must be called on the core thread.
void kyuhachi_ready_fdd(unsigned drive, const char *path);

/// Ejects the disk in floppy drive `drive`. Must be called on the core thread.
void kyuhachi_eject_fdd(unsigned drive);

/// Sets the hard disk image for IDE drive `drive` (0 = the first hard
/// disk), or removes it when `path` is NULL. Takes effect at the next reset.
/// Must be called on the core thread.
void kyuhachi_set_hdd(unsigned drive, const char *path);

/// The default value of one of NP2kai's libretro core options (the value
/// RetroArch would pass unless the user changed it), or NULL if unknown.
const char *kyuhachi_option_default(const char *key);

/// Presses or releases a key on the PC-98 keyboard, given its PC-98 key
/// code (0x00-0x7f). Must be called on the core thread.
void kyuhachi_key_down(unsigned char code);
void kyuhachi_key_up(unsigned char code);
