// swift-tools-version:6.2
import PackageDescription

// NP2kai's own include paths, in the order its libretro makefile passes them
// (several directories ship a compiler.h, so the order matters).
let np2kaiHeaderPaths: [String] = [
    "np2kai",
    "np2kai/cbus",
    "np2kai/common",
    "np2kai/diskimage",
    "np2kai/diskimage/cd",
    "np2kai/diskimage/fd",
    "np2kai/embed",
    "np2kai/embed/menu",
    "np2kai/embed/menubase",
    "np2kai/fdd",
    "np2kai/font",
    "np2kai/generic",
    "np2kai/io",
    "np2kai/mem",
    "np2kai/sound",
    "np2kai/sound/vermouth",
    "np2kai/sound/fmgen",
    "np2kai/trap",
    "np2kai/vram",
    "np2kai/wab",
    "np2kai/sdl",
    "np2kai/i386c",
    "np2kai/i386c/ia32",
    "np2kai/i386c/ia32/instructions",
    "np2kai/i386c/ia32/instructions/fpu",
    "np2kai/i386c/ia32/instructions/fpu/softfloat",
    "np2kai/i386c/ia32/instructions/mmx",
    "np2kai/i386c/ia32/instructions/sse",
    "np2kai/sdl/libretro",
    "np2kai/sdl/libretro/libretro-common/include",
    "np2kai/sdl/libretro/libretro-common/include/file",
    "np2kai/sdl/libretro/libretro-common/include/streams",
]

// Defines from NP2kai's libretro build (IA-32 core, same as RetroArch's np2kai).
let np2kaiDefines: [(String, String?)] = [
    ("__LIBRETRO__", nil),
    ("NDEBUG", nil),
    ("_NDEBUG", nil),
    ("NST_NO_ZLIB", nil),
    ("BIOS_IO_EMULATION", nil),
    ("OSLANG_UTF8", nil),
    ("OSLINEBREAK_CRLF", nil),
    ("SUPPORT_8BPP", nil),
    ("SUPPORT_16BPP", nil),
    ("SUPPORT_24BPP", nil),
    ("SUPPORT_32BPP", nil),
    ("SUPPORT_CL_GD5430", nil),
    ("SUPPORT_CRT15KHZ", nil),
    ("SUPPORT_FAST_MEMORYCHECK", nil),
    ("SUPPORT_FMGEN", nil),
    ("SUPPORT_GPIB", nil),
    ("SUPPORT_HRTIMER", nil),
    ("SUPPORT_KAI_IMAGES", nil),
    ("SUPPORT_LARGE_HDD", nil),
    ("SUPPORT_NORMALDISP", nil),
    ("SUPPORT_PC9861K", nil),
    ("SUPPORT_PX", nil),
    ("SUPPORT_RESUME", nil),
    ("SUPPORT_RS232C_FIFO", nil),
    ("SUPPORT_S98", nil),
    ("SUPPORT_SCSI", nil),
    ("SUPPORT_SMPU98", nil),
    ("SUPPORT_SOFTKBD", "0"),
    ("SUPPORT_SOUND_SB16", nil),
    ("SUPPORT_STATSAVE", "10"),
    ("SUPPORT_UTF8", nil),
    ("SUPPORT_V30EXT", nil),
    ("SUPPORT_V30ORIGINAL", nil),
    ("SUPPORT_VIDEOFILTER", nil),
    ("SUPPORT_VPCVHD", nil),
    ("SUPPORT_WAB", nil),
    ("USE_MAME", nil),
    ("USE_MAME_BSD", nil),
    ("VAEG_FIX", nil),
    ("VERMOUTH_LIB", nil),
    ("SUPPORT_DEBUGSS", nil),
    ("SUPPORT_NP2_THREAD", nil),
    ("SUPPORT_NP2_TICKCOUNT", nil),
    ("SUPPORT_ASYNC_CPU", nil),
    ("CPUCORE_IA32", nil),
    ("IA32_PAGING_EACHSIZE", nil),
    ("IA32_REBOOT_ON_PANIC", nil),
    ("SUPPORT_CRT31KHZ", nil),
    ("SUPPORT_PC9801_119", nil),
    ("SUPPORT_PC9821", nil),
    ("SUPPORT_IDEIO", nil),
    ("SUPPORT_LARGE_MEMORY", nil),
    ("SUPPORT_FPU_DOSBOX2_COMPATIBLE", nil),
    ("SUPPORT_PEGC", nil),
    ("SUPPORT_VGA_MODEX", nil),
    ("SUPPORT_GAMEPORT", nil),
    ("SUPPORT_IDEIO_48BIT", nil),
    ("SUPPORT_FPU_SOFTFLOAT3", nil),
    ("SUPPORT_PCI", nil),
    ("USE_FPU", nil),
    ("USE_MMX", nil),
    ("USE_3DNOW", nil),
    ("USE_SSE", nil),
    ("USE_SSE2", nil),
    ("USE_SSE3", nil),
    ("USE_SSSE3", nil),
    ("USE_SSE4_1", nil),
    ("USE_SSE4_2", nil),
    ("USE_SSE4A", nil),
    ("USE_TSC", nil),
    ("USE_FASTPAGING", nil),
    ("USE_VME", nil),
    ("SUPPORT_MEMDBG32", nil),
    ("NP2KAI_GIT_TAG", "\"kyuhachi\""),
    ("NP2KAI_GIT_HASH", "\"5939e0c\""),
]

// NP2kai predates clang treating these as errors; its own makefile builds
// fine with them as warnings.
let legacyCFlags = [
    "-fsigned-char", "-w", "-UDEBUG", "-fno-modules",
    "-Wno-error=incompatible-function-pointer-types",
    "-Wno-error=incompatible-pointer-types",
    "-Wno-error=int-conversion",
    "-Wno-error=implicit-function-declaration",
]

let np2kaiCSettings: [CSetting] =
    np2kaiHeaderPaths.map { .headerSearchPath($0) }
    + np2kaiDefines.map { .define($0.0, to: $0.1) }
    + [.unsafeFlags(legacyCFlags)]

let np2kaiCxxSettings: [CXXSetting] =
    np2kaiHeaderPaths.map { .headerSearchPath($0) }
    + np2kaiDefines.map { .define($0.0, to: $0.1) }
    + [.unsafeFlags(legacyCFlags)]

let package = Package(
    name: "Kyuhachi",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "CNP2kai",
            exclude: ["np2kai/LICENSE", "np2kai/LICENSES"],
            cSettings: np2kaiCSettings,
            cxxSettings: np2kaiCxxSettings,
            linkerSettings: [
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .executableTarget(
            name: "Kyuhachi",
            dependencies: ["CNP2kai"]
        ),
    ],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .cxx17
)
