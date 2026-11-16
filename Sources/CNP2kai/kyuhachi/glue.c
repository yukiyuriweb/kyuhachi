// Small entry points into NP2kai internals that the libretro API lacks.

#include <compiler.h>
#include <fdd/diskdrv.h>

void kyuhachi_set_fdd(unsigned drive, const char *path)
{
	diskdrv_setfdd((REG8)drive, path, 0);
}

void kyuhachi_ready_fdd(unsigned drive, const char *path)
{
	diskdrv_readyfdd((REG8)drive, path, 0);
}

void kyuhachi_eject_fdd(unsigned drive)
{
	diskdrv_setfdd((REG8)drive, NULL, 0);
}

#include <keystat.h>

void kyuhachi_key_down(unsigned char code)
{
	keystat_keydown((REG8)code);
}

void kyuhachi_key_up(unsigned char code)
{
	keystat_keyup((REG8)code);
}

/* Sets (or clears, with NULL) the image for IDE/SASI drive `drive`. Takes
   effect at the next reset. */
void kyuhachi_set_hdd(unsigned drive, const char *path)
{
	diskdrv_setsxsi((REG8)drive, path);
}

#include <libretro.h>

/* NP2kai's table of libretro core options (libretro_core_options.h). */
extern struct retro_core_option_definition option_defs_us[];

const char *kyuhachi_option_default(const char *key)
{
	struct retro_core_option_definition *option;

	for (option = option_defs_us; option->key != NULL; option++)
	{
		if (strcmp(option->key, key) == 0)
		{
			return option->default_value;
		}
	}
	return NULL;
}
