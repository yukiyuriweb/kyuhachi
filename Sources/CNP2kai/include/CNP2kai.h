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

/// Creates an unformatted 2HD floppy image (an empty D88 file) at `path`,
/// for games that format a new user disk themselves.
void kyuhachi_new_2hd(const char *path);

/// Sets the hard disk image for IDE drive `drive` (0 = the first hard
/// disk), or removes it when `path` is NULL. Takes effect at the next reset.
/// Must be called on the core thread.
void kyuhachi_set_hdd(unsigned drive, const char *path);

/// Saves the whole machine state to `path`. Returns 1 on success.
/// Must be called on the core thread.
int kyuhachi_save_state(const char *path);

/// Restores a state saved with kyuhachi_save_state, including the disks
/// that were in the drives. Returns 1 on success. Must be called on the
/// core thread.
int kyuhachi_load_state(const char *path);

/// The image in floppy drive `drive` or hard disk `drive`, or NULL when
/// empty. Must be called on the core thread.
const char *kyuhachi_fdd_path(unsigned drive);
const char *kyuhachi_hdd_path(unsigned drive);

/// The default value of one of NP2kai's libretro core options (the value
/// RetroArch would pass unless the user changed it), or NULL if unknown.
const char *kyuhachi_option_default(const char *key);

/// The values a core option can take, from NP2kai's option table.
int kyuhachi_option_value_count(const char *key);
const char *kyuhachi_option_value(const char *key, int index);

/// The option table's own copy of `value` (a string that lives as long as
/// the program), or NULL if `value` is not one of the option's values.
const char *kyuhachi_option_canonical(const char *key, const char *value);

/// Presses or releases a key on the PC-98 keyboard, given its PC-98 key
/// code (0x00-0x7f). Must be called on the core thread.
void kyuhachi_key_down(unsigned char code);
void kyuhachi_key_up(unsigned char code);
