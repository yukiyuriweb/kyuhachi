// Font manager for NP2kai, implemented with Core Text.
//
// Replaces sdl/fontmng.c. NP2kai asks this module for one glyph at a time,
// both to build the PC-98 font ROM (font/fontmake.c, 8x16 and 16x16 cells)
// and to draw its built-in menus. Glyphs are rasterised into an 8-bit
// coverage map whose rows are `width` bytes long.
//
// Every glyph sits on one shared baseline: the em box is taken out of the
// font's line box in proportion to its ascent and descent. Characters the
// font lacks (for example NEC's circled numbers in the Shinonome fonts) are
// drawn with whatever font Core Text picks as a fallback.

#include <compiler.h>
#include <fontmng.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <syslog.h>

/// Font file to use. Set by fontmng_setdeffontname(); the fallback below is
/// used when it is empty or cannot be loaded.
static char s_fontPath[MAX_PATH] = "";

/// PostScript name of the fallback font (ships with macOS).
#define FALLBACK_FONT_NAME CFSTR("HiraMinProN-W3")

typedef struct
{
	int size;
	UINT type;
	CTFontRef font;
	CGFloat baselineFromTop;
	/// Holds the most recent glyph: an _FNTDAT header followed by pixels.
	UINT8 *glyph;
} FontManager;

BRESULT fontmng_init(void)
{
	return SUCCESS;
}

void fontmng_setdeffontname(const char *name)
{
	milstr_ncpy(s_fontPath, name, NELEMENTS(s_fontPath));
}

static CTFontRef CreateFontFromFile(const char *path, CGFloat size)
{
	CFURLRef url;
	CFArrayRef descriptors;
	CTFontRef font = NULL;

	if (path[0] == '\0')
	{
		return NULL;
	}
	url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)path, strlen(path), false);
	if (url == NULL)
	{
		return NULL;
	}
	descriptors = CTFontManagerCreateFontDescriptorsFromURL(url);
	CFRelease(url);
	if (descriptors == NULL)
	{
		return NULL;
	}
	if (CFArrayGetCount(descriptors) > 0)
	{
		CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0);
		font = CTFontCreateWithFontDescriptor(descriptor, size, NULL);
	}
	CFRelease(descriptors);
	return font;
}

void *fontmng_create(int size, UINT type, const char *fontface)
{
	FontManager *fm;
	CTFontRef font;
	CGFloat ascent;
	CGFloat descent;

	(void)fontface;
	if (size < 0)
	{
		size = -size;
	}
	if (size < 6)
	{
		size = 6;
	}
	else if (size > 128)
	{
		size = 128;
	}

	font = CreateFontFromFile(s_fontPath, size);
	if (font == NULL)
	{
		syslog(LOG_WARNING, "Kyuhachi: cannot load font \"%s\"; using the fallback font", s_fontPath);
		font = CTFontCreateWithName(FALLBACK_FONT_NAME, size, NULL);
	}
	if (font == NULL)
	{
		return NULL;
	}

	fm = (FontManager *)calloc(1, sizeof(FontManager));
	if (fm == NULL)
	{
		CFRelease(font);
		return NULL;
	}
	fm->glyph = (UINT8 *)calloc(1, sizeof(_FNTDAT) + (size * 2) * size);
	if (fm->glyph == NULL)
	{
		CFRelease(font);
		free(fm);
		return NULL;
	}
	fm->size = size;
	fm->type = type;
	fm->font = font;

	ascent = CTFontGetAscent(font);
	descent = CTFontGetDescent(font);
	fm->baselineFromTop = (ascent + descent > 0) ? (size * ascent / (ascent + descent)) : size;
	return fm;
}

void fontmng_destroy(void *hdl)
{
	FontManager *fm = (FontManager *)hdl;

	if (fm)
	{
		CFRelease(fm->font);
		free(fm->glyph);
		free(fm);
	}
}

/// Decodes one UTF-8 character (up to U+FFFF) and advances the pointer.
static UniChar NextChar(const char **string)
{
	const UINT8 *s = (const UINT8 *)*string;
	UniChar c = 0;

	if (s == NULL || s[0] == 0)
	{
		return 0;
	}
	if ((s[0] & 0x80) == 0)
	{
		c = s[0];
		s += 1;
	}
	else if (((s[0] & 0xe0) == 0xc0) && ((s[1] & 0xc0) == 0x80))
	{
		c = ((s[0] & 0x1f) << 6) | (s[1] & 0x3f);
		s += 2;
	}
	else if (((s[0] & 0xf0) == 0xe0) && ((s[1] & 0xc0) == 0x80) && ((s[2] & 0xc0) == 0x80))
	{
		c = ((s[0] & 0x0f) << 12) | ((s[1] & 0x3f) << 6) | (s[2] & 0x3f);
		s += 3;
	}
	else
	{
		c = '?';
		s += 1;
	}
	*string = (const char *)s;
	return c;
}

/// Returns a retained font that can draw `c` (the main font or a fallback)
/// and the glyph to draw.
static CTFontRef FontForChar(FontManager *fm, UniChar c, CGGlyph *glyph)
{
	CFStringRef string;
	CTFontRef fallback;

	if (CTFontGetGlyphsForCharacters(fm->font, &c, glyph, 1) && *glyph != 0)
	{
		CFRetain(fm->font);
		return fm->font;
	}
	string = CFStringCreateWithCharacters(NULL, &c, 1);
	fallback = CTFontCreateForString(fm->font, string, CFRangeMake(0, 1));
	CFRelease(string);
	if (fallback && CTFontGetGlyphsForCharacters(fallback, &c, glyph, 1) && *glyph != 0)
	{
		return fallback;
	}
	if (fallback)
	{
		CFRelease(fallback);
	}
	*glyph = 0;
	CFRetain(fm->font);
	return fm->font;
}

/// Width in pixels of one character cell: half or full width of the em.
static int CharWidth(FontManager *fm, UniChar c)
{
	CGGlyph glyph;
	CTFontRef font;
	CGSize advance;
	int width;

	font = FontForChar(fm, c, &glyph);
	CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, &advance, 1);
	CFRelease(font);
	if (!(fm->type & FDAT_PROPORTIONAL))
	{
		// PC-98 text is monospaced: every character takes a half or a full
		// cell. Latin and half-width kana are always half width, even in
		// fonts whose Latin letters are proportional and wide.
		if (c < 0x100 || c == 0x203e || (c >= 0xff61 && c <= 0xff9f))
		{
			return fm->size / 2;
		}
		return (advance.width <= fm->size * 0.75) ? (fm->size / 2) : fm->size;
	}
	width = (int)(advance.width + 0.5);
	if (width < 1)
	{
		width = 1;
	}
	if (width > fm->size * 2)
	{
		width = fm->size * 2;
	}
	return width;
}

static void SetHeader(FontManager *fm, FNTDAT fdat, int width)
{
	fdat->width = width;
	fdat->pitch = width;
	fdat->height = fm->size;
}

static void Rasterise(FontManager *fm, FNTDAT fdat, UniChar c)
{
	int width = CharWidth(fm, c);
	int height = fm->size;
	UINT8 *dst = (UINT8 *)(fdat + 1);
	CGColorSpaceRef gray;
	CGContextRef context;
	CTFontRef font;
	CGGlyph glyph;
	CGPoint position;
	CGRect bounds;
	const UINT8 *src;
	size_t rowBytes;
	int x;
	int y;
	int antialias = (fm->type & FDAT_ALIAS) != 0;

	SetHeader(fm, fdat, width);
	memset(dst, 0, width * height);

	gray = CGColorSpaceCreateDeviceGray();
	context = CGBitmapContextCreate(NULL, width, height, 8, 0, gray, kCGImageAlphaNone);
	CGColorSpaceRelease(gray);
	if (context == NULL)
	{
		return;
	}
	CGContextSetGrayFillColor(context, 0, 1);
	CGContextFillRect(context, CGRectMake(0, 0, width, height));
	CGContextSetGrayFillColor(context, 1, 1);
	CGContextSetShouldAntialias(context, antialias);
	CGContextSetAllowsAntialiasing(context, antialias);
	CGContextSetShouldSmoothFonts(context, false);

	font = FontForChar(fm, c, &glyph);
	if (glyph != 0)
	{
		position.y = height - fm->baselineFromTop;
		position.x = 0;
		if (!(fm->type & FDAT_PROPORTIONAL))
		{
			// Centre the glyph's advance in the fixed-width cell; squeeze
			// glyphs whose ink is wider than the cell.
			CGSize advance;
			CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, &advance, 1);
			position.x = (width - advance.width) / 2;
			if (advance.width > width)
			{
				CGFloat scale = 1;
				bounds = CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal, &glyph, NULL, 1);
				if (bounds.size.width > width)
				{
					scale = width / bounds.size.width;
					CGContextScaleCTM(context, scale, 1);
				}
				position.x = ((width / scale) - bounds.size.width) / 2 - bounds.origin.x;
			}
		}
		CTFontDrawGlyphs(font, &glyph, &position, 1, context);
	}
	CFRelease(font);

	src = (const UINT8 *)CGBitmapContextGetData(context);
	rowBytes = CGBitmapContextGetBytesPerRow(context);
	for (y = 0; y < height; y++)
	{
		for (x = 0; x < width; x++)
		{
			UINT8 v = src[y * rowBytes + x];
			dst[y * width + x] = antialias ? v : ((v >= 0x80) ? FDAT_DEPTH : 0);
		}
	}
	CGContextRelease(context);
}

BRESULT fontmng_getsize(void *hdl, const char *string, POINT_T *pt)
{
	FontManager *fm = (FontManager *)hdl;
	int width = 0;
	UniChar c;

	if (fm == NULL || string == NULL)
	{
		return FAILURE;
	}
	while ((c = NextChar(&string)) != 0)
	{
		width += CharWidth(fm, c);
	}
	if (pt)
	{
		pt->x = width;
		pt->y = fm->size;
	}
	return SUCCESS;
}

BRESULT fontmng_getdrawsize(void *hdl, const char *string, POINT_T *pt)
{
	return fontmng_getsize(hdl, string, pt);
}

FNTDAT fontmng_get(void *hdl, const char *string)
{
	FontManager *fm = (FontManager *)hdl;
	UniChar c;
	FNTDAT fdat;

	if (fm == NULL)
	{
		return NULL;
	}
	c = NextChar(&string);
	if (c == 0)
	{
		return NULL;
	}
	fdat = (FNTDAT)fm->glyph;
	Rasterise(fm, fdat, c);
	return fdat;
}
