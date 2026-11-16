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

static struct retro_core_option_definition *FindOption(const char *key)
{
	struct retro_core_option_definition *option;

	for (option = option_defs_us; option->key != NULL; option++)
	{
		if (strcmp(option->key, key) == 0)
		{
			return option;
		}
	}
	return NULL;
}

const char *kyuhachi_option_default(const char *key)
{
	struct retro_core_option_definition *option = FindOption(key);

	return option ? option->default_value : NULL;
}

int kyuhachi_option_value_count(const char *key)
{
	struct retro_core_option_definition *option = FindOption(key);
	int count = 0;

	if (option)
	{
		while (count < RETRO_NUM_CORE_OPTION_VALUES_MAX && option->values[count].value != NULL)
		{
			count++;
		}
	}
	return count;
}

const char *kyuhachi_option_value(const char *key, int index)
{
	struct retro_core_option_definition *option = FindOption(key);

	if (option == NULL || index < 0 || index >= kyuhachi_option_value_count(key))
	{
		return NULL;
	}
	return option->values[index].value;
}

const char *kyuhachi_option_canonical(const char *key, const char *value)
{
	int count = kyuhachi_option_value_count(key);
	int i;

	for (i = 0; i < count; i++)
	{
		const char *candidate = kyuhachi_option_value(key, i);
		if (strcmp(candidate, value) == 0)
		{
			return candidate;
		}
	}
	return NULL;
}

#include <statsave.h>
#include <diskimage/fddfile.h>

/* statsave returns STATFLAG_FAILURE (-1) on failure; positive values are
   warnings (for example, a disk has changed since the state was saved). */
int kyuhachi_save_state(const char *path)
{
	return statsave_save_d(path) != STATFLAG_FAILURE;
}

int kyuhachi_load_state(const char *path)
{
	return statsave_load_d(path) != STATFLAG_FAILURE;
}

const char *kyuhachi_fdd_path(unsigned drive)
{
	UINT ftype;
	int ro;
	const OEMCHAR *path = fdd_getfileex((REG8)drive, &ftype, &ro);

	return (path != NULL && path[0] != '\0') ? path : NULL;
}

const char *kyuhachi_hdd_path(unsigned drive)
{
	const OEMCHAR *path = diskdrv_getsxsi((REG8)drive);

	return (path != NULL && path[0] != '\0') ? path : NULL;
}
