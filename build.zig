const std = @import("std");

const SoloudBuildOptions = struct {
    with_sdl1: bool = false,
    with_sdl2: bool = false,
    with_sdl1_static: bool = false,
    with_sdl2_static: bool = false,
    with_portaudio: bool = false,
    with_openal: bool = false,
    with_xaudio2: bool = false,
    with_winmm: bool = false,
    with_wasapi: bool = false,
    with_alsa: bool = false,
    with_jack: bool = false,
    with_oss: bool = false,
    with_coreaudio: bool = false,
    with_vita_homebrew: bool = false,
    with_nosound: bool = false,
    with_miniaudio: bool = false,
    with_null: bool = true,
    ///Whether to compile a shared library or a static library
    shared: bool = false,
    ///Whether soloud.(a/so/dll) itself should link against required libraries
    link_libs: bool = true,
};

pub fn buildSoloud(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode, passed_options: SoloudBuildOptions) !*std.Build.CompileStep {
    const sdl1_root = root_path ++ "submodules/SDL1";
    const sdl2_root = root_path ++ "submodules/SDL";
    const dxsdk_root = std.os.getenv("DXSDK_DIR") orelse "C:/Program Files (x86)/Microsoft DirectX SDK (June 2010)";
    const portaudio_root = root_path ++ "submodules/portaudio";
    const openal_root = root_path ++ "submodules/openal-soft";

    const sdl1_include = sdl1_root ++ "/include";
    const sdl2_include = sdl2_root ++ "/include";
    const dxsdk_include = try std.mem.concat(b.allocator, u8, &.{ dxsdk_root, "/include" });
    const portaudio_include = portaudio_root ++ "/include";
    const openal_include = openal_root ++ "/include";

    var options = passed_options;

    var library_options = .{
        .name = "soloud",
        .target = target,
        .optimize = optimize,
    };

    var soloud = if (options.shared) b.addStaticLibrary(library_options) else b.addSharedLibrary(library_options);

    //The flags used in the build
    var build_flags = std.ArrayList([]const u8).init(b.allocator);

    //Windows specific defines
    if (target.isWindows()) {
        //NOTE: this is not in the original build scripts,
        //      but SoLoud uses _MSC_VER to detect windows,
        //      since thats not defined by `zig cc`, lets force WINDOWS_VERSION here
        soloud.defineCMacro("WINDOWS_VERSION", null);
    }

    //We need libc and libcpp for SoLoud
    soloud.linkLibC();
    soloud.linkLibCpp();

    //We need "-msse4.1" and "-fPIC" to compile the Vita homebrew backend
    if (options.with_vita_homebrew) {
        try build_flags.appendSlice(&.{ "-msse4.1", "-fPIC" });
    }

    //Add the include path
    soloud.addIncludePath(root_path ++ "include");

    //Add the `src/audiosource/`, `src/filter/`, and `src/core/` files to the compiled output
    const audiosource = try find_c_cpp_sources(b.allocator, root_path ++ "src/audiosource/");
    soloud.addCSourceFiles(audiosource.c, build_flags.items);
    soloud.addCSourceFiles(audiosource.cpp, build_flags.items);
    const filter = try find_c_cpp_sources(b.allocator, root_path ++ "src/filter/");
    soloud.addCSourceFiles(filter.c, build_flags.items);
    soloud.addCSourceFiles(filter.cpp, build_flags.items);
    const core = try find_c_cpp_sources(b.allocator, root_path ++ "src/core/");
    soloud.addCSourceFiles(core.c, build_flags.items);
    soloud.addCSourceFiles(core.cpp, build_flags.items);

    if (options.with_openal) {
        soloud.defineCMacro("WITH_OPENAL", null);
        const openal = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/openal/");
        soloud.addCSourceFiles(openal.c, build_flags.items);
        soloud.addCSourceFiles(openal.cpp, build_flags.items);
        soloud.addIncludePath(openal_include);
    }

    if (options.with_alsa) {
        soloud.defineCMacro("WITH_ALSA", null);
        const alsa = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/alsa/");
        soloud.addCSourceFiles(alsa.c, build_flags.items);
        soloud.addCSourceFiles(alsa.cpp, build_flags.items);

        if (options.link_libs) {
            soloud.linkSystemLibrary("asound");
        }
    }

    if (options.with_oss) {
        soloud.defineCMacro("WITH_OSS", null);
        const oss = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/oss/");
        soloud.addCSourceFiles(oss.c, build_flags.items);
        soloud.addCSourceFiles(oss.cpp, build_flags.items);
    }

    if (options.with_miniaudio) {
        soloud.defineCMacro("WITH_MINIAUDIO", null);
        const miniaudio = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/miniaudio/");
        soloud.addCSourceFiles(miniaudio.c, build_flags.items);
        soloud.addCSourceFiles(miniaudio.cpp, build_flags.items);
    }

    if (options.with_nosound) {
        soloud.defineCMacro("WITH_NOSOUND", null);
        const nosound = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/nosound/");
        soloud.addCSourceFiles(nosound.c, build_flags.items);
        soloud.addCSourceFiles(nosound.cpp, build_flags.items);
    }

    if (options.with_coreaudio) {
        soloud.defineCMacro("WITH_COREAUDIO", null);
        const coreaudio = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/coreaudio/");
        soloud.addCSourceFiles(coreaudio.c, build_flags.items);
        soloud.addCSourceFiles(coreaudio.cpp, build_flags.items);

        if (options.link_libs) {
            // soloud.linkSystemLibrary("AudioToolbox.framework");
            soloud.linkFramework("AudioToolbox");
        }
    }

    if (options.with_portaudio) {
        soloud.defineCMacro("WITH_PORTAUDIO", null);
        const portaudio = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/portaudio/");
        soloud.addCSourceFiles(portaudio.c, build_flags.items);
        soloud.addCSourceFiles(portaudio.cpp, build_flags.items);
        soloud.addIncludePath(portaudio_include);
    }

    if (options.with_sdl1) {
        soloud.defineCMacro("WITH_SDL1", null);
        const sdl = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/sdl/");
        soloud.addCSourceFiles(sdl.c, build_flags.items);
        soloud.addCSourceFiles(sdl.cpp, build_flags.items);
        soloud.addIncludePath(sdl1_include);
    }

    if (options.with_sdl2) {
        soloud.defineCMacro("WITH_SDL2", null);
        const sdl2 = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/sdl/");
        soloud.addCSourceFiles(sdl2.c, build_flags.items);
        soloud.addCSourceFiles(sdl2.cpp, build_flags.items);
        soloud.addIncludePath(sdl2_include);
    }

    if (options.with_sdl1_static) {
        soloud.defineCMacro("WITH_SDL1_STATIC", null);
        const sdl = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/sdl/");
        soloud.addCSourceFiles(sdl.c, build_flags.items);
        soloud.addCSourceFiles(sdl.cpp, build_flags.items);
        soloud.addIncludePath(sdl1_include);
    }

    if (options.with_sdl2_static) {
        soloud.defineCMacro("WITH_SDL2_STATIC", null);
        const sdl = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/sdl/");
        soloud.addCSourceFiles(sdl.c, build_flags.items);
        soloud.addCSourceFiles(sdl.cpp, build_flags.items);
        soloud.addIncludePath(sdl2_include);
    }

    if (options.with_wasapi) {
        soloud.defineCMacro("WITH_WASAPI", null);
        const wasapi = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/wasapi/");
        soloud.addCSourceFiles(wasapi.c, build_flags.items);
        soloud.addCSourceFiles(wasapi.cpp, build_flags.items);
    }

    if (options.with_xaudio2) {
        soloud.defineCMacro("WITH_XAUDIO2", null);
        const xaudio2 = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/xaudio2/");
        soloud.addCSourceFiles(xaudio2.c, build_flags.items);
        soloud.addCSourceFiles(xaudio2.cpp, build_flags.items);
        soloud.addIncludePath(dxsdk_include);
    }

    if (options.with_winmm) {
        soloud.defineCMacro("WITH_WINMM", null);
        const winmm = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/winmm/");
        soloud.addCSourceFiles(winmm.c, build_flags.items);
        soloud.addCSourceFiles(winmm.cpp, build_flags.items);

        if (options.link_libs) {
            soloud.linkSystemLibrary("winmm");
        }
    }

    if (options.with_vita_homebrew) {
        soloud.defineCMacro("WITH_VITA_HOMEBREW", null);
        soloud.defineCMacro("usleep=sceKernelDelayThread", null);
        const vita_homebrew = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/vita_homebrew/");
        soloud.addCSourceFiles(vita_homebrew.c, build_flags.items);
        soloud.addCSourceFiles(vita_homebrew.cpp, build_flags.items);
    }

    if (options.with_jack) {
        soloud.defineCMacro("WITH_JACK", null);
        const vita_homebrew = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/jack/");
        soloud.addCSourceFiles(vita_homebrew.c, build_flags.items);
        soloud.addCSourceFiles(vita_homebrew.cpp, build_flags.items);

        if (options.link_libs) {
            soloud.linkSystemLibrary("jack");
        }
    }

    if (options.with_null) {
        soloud.defineCMacro("WITH_NULL", null);
        const null_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "src/backend/null/");
        soloud.addCSourceFiles(null_srcs.c, build_flags.items);
        soloud.addCSourceFiles(null_srcs.cpp, build_flags.items);
    }

    return soloud;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var build_options = SoloudBuildOptions{};

    var with_common_backends = b.option(bool, "with_common_backends", "Include the common backends") orelse true;
    var with_tools = b.option(bool, "with_tools", "Include some testing tools") orelse false;
    var with_demos = b.option(bool, "with_demos", "Include the demos") orelse true;

    if (with_common_backends) {
        build_options.with_sdl1 = false;
        build_options.with_sdl2 = true;
        build_options.with_sdl1_static = false;
        build_options.with_sdl2_static = false;
        build_options.with_portaudio = true;
        build_options.with_openal = true;
        build_options.with_xaudio2 = false;
        build_options.with_winmm = false;
        build_options.with_wasapi = false;
        build_options.with_oss = true;
        build_options.with_nosound = true;
        build_options.with_miniaudio = false;

        if (target.isWindows()) {
            build_options.with_xaudio2 = false;
            build_options.with_wasapi = true;
            build_options.with_winmm = true;
            build_options.with_oss = false;
        }

        if (target.isDarwin()) {
            build_options.with_oss = false;
        }
    }

    build_options.with_sdl1 = b.option(bool, "with_sdl1", "Include the SDL1 backend") orelse false;
    build_options.with_sdl1_static = b.option(bool, "with_sdl1_static", "Include the SDL1 (static) backend") orelse false;
    build_options.with_sdl2 = b.option(bool, "with_sdl2", "Include the SDL2 backend") orelse false;
    build_options.with_sdl2_static = b.option(bool, "with_sdl2_static", "Include the SDL2 (static) backend") orelse false;
    build_options.with_portaudio = b.option(bool, "with_portaudio", "Include the portaudio backend") orelse false;
    build_options.with_openal = b.option(bool, "with_openal", "Include the OpenAL backend") orelse false;
    build_options.with_xaudio2 = b.option(bool, "with_xaudio2", "Include the XAudio2 backend") orelse false;
    build_options.with_winmm = b.option(bool, "with_winmm", "Include the winmm backend") orelse if (target.isWindows()) true else false;
    build_options.with_wasapi = b.option(bool, "with_wasapi", "Include the WASAPI backend") orelse false;
    build_options.with_alsa = b.option(bool, "with_alsa", "Include the ALSA backend") orelse if (target.isWindows() or target.isDarwin()) false else true;
    build_options.with_jack = b.option(bool, "with_jack", "Include the JACK backend") orelse false;
    build_options.with_oss = b.option(bool, "with_oss", "Include the OSS backend") orelse if (target.isWindows() or target.isDarwin()) false else true;
    build_options.with_coreaudio = b.option(bool, "with_coreaudio", "Include the CoreAudio backend") orelse if (target.isDarwin()) true else false;
    build_options.with_vita_homebrew = b.option(bool, "with_vita_homebrew", "Include the Vita Homebrew backend") orelse false;
    build_options.with_nosound = b.option(bool, "with_nosound", "Include the no sound backend") orelse false;
    build_options.with_miniaudio = b.option(bool, "with_miniaudio", "Include the MiniAudio backend") orelse false;
    build_options.with_null = b.option(bool, "with_null", "Include the Null backend") orelse false;

    var static_soloud = try buildSoloud(b, target, optimize, build_options);
    b.installArtifact(static_soloud);
    build_options.shared = true;
    b.installArtifact(try buildSoloud(b, target, optimize, build_options));

    if (with_tools) {
        { //sanity
            var sanity = b.addExecutable(.{
                .name = "sanity",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            sanity.addIncludePath(root_path ++ "include/");

            sanity.linkLibC();
            sanity.linkLibCpp();
            sanity.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(sanity, build_options);

            if (!target.isWindows()) {
                sanity.linkSystemLibrary("pthread");
                sanity.linkSystemLibrary("dl");
            }

            var sanity_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "src/tools/sanity/");
            sanity.addCSourceFiles(sanity_srcs.c, &.{});
            sanity.addCSourceFiles(sanity_srcs.cpp, &.{});

            b.installArtifact(sanity);
        } //sanity

        { //codegen
            var codegen = b.addExecutable(.{
                .name = "codegen",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            codegen.linkLibC();
            codegen.linkLibCpp();

            var codegen_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "src/tools/codegen/");
            codegen.addCSourceFiles(codegen_srcs.c, &.{});
            codegen.addCSourceFiles(codegen_srcs.cpp, &.{});

            b.installArtifact(codegen);
        } //codegen

        { //resamplerlab
            var resamplerlab = b.addExecutable(.{
                .name = "resamplerlab",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            resamplerlab.linkLibC();
            resamplerlab.linkLibCpp();

            var resamplerlab_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "src/tools/resamplerlab/");
            resamplerlab.addCSourceFiles(resamplerlab_srcs.c, &.{});
            resamplerlab.addCSourceFiles(resamplerlab_srcs.cpp, &.{});

            b.installArtifact(resamplerlab);
        } //resamplerlab

        { //lutgen
            var lutgen = b.addExecutable(.{
                .name = "lutgen",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            lutgen.linkLibC();
            lutgen.linkLibCpp();

            var lutgen_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "src/tools/lutgen/");
            lutgen.addCSourceFiles(lutgen_srcs.c, &.{});
            lutgen.addCSourceFiles(lutgen_srcs.cpp, &.{});

            b.installArtifact(lutgen);
        } //lutgen
    }

    if (with_demos) {
        { //simplest
            var simplest = b.addExecutable(.{
                .name = "simplest",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            simplest.addIncludePath(root_path ++ "include/");

            simplest.linkLibC();
            simplest.linkLibCpp();
            simplest.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(simplest, build_options);

            if (!target.isWindows()) {
                simplest.linkSystemLibrary("pthread");
                simplest.linkSystemLibrary("dl");
            }

            var simplest_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "demos/simplest/");
            simplest.addCSourceFiles(simplest_srcs.c, &.{});
            simplest.addCSourceFiles(simplest_srcs.cpp, &.{});

            b.installArtifact(simplest);
        } //simplest

        { //welcome
            var welcome = b.addExecutable(.{
                .name = "welcome",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            welcome.addIncludePath(root_path ++ "include/");

            welcome.linkLibC();
            welcome.linkLibCpp();
            welcome.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(welcome, build_options);

            if (!target.isWindows()) {
                welcome.linkSystemLibrary("pthread");
                welcome.linkSystemLibrary("dl");
            }

            var welcome_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "demos/welcome/");
            welcome.addCSourceFiles(welcome_srcs.c, &.{});
            welcome.addCSourceFiles(welcome_srcs.cpp, &.{});

            b.installArtifact(welcome);
        } //welcome

        { //null
            var null_exe = b.addExecutable(.{
                .name = "null",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            null_exe.addIncludePath(root_path ++ "include/");

            null_exe.linkLibC();
            null_exe.linkLibCpp();
            null_exe.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(null_exe, build_options);

            if (!target.isWindows()) {
                null_exe.linkSystemLibrary("pthread");
                null_exe.linkSystemLibrary("dl");
            }

            var null_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "demos/null/");
            null_exe.addCSourceFiles(null_srcs.c, &.{});
            null_exe.addCSourceFiles(null_srcs.cpp, &.{});

            b.installArtifact(null_exe);
        } //null

        { //enumerate
            var enumerate = b.addExecutable(.{
                .name = "enumerate",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            enumerate.addIncludePath(root_path ++ "include/");

            enumerate.linkLibC();
            enumerate.linkLibCpp();
            enumerate.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(enumerate, build_options);

            if (!target.isWindows()) {
                enumerate.linkSystemLibrary("pthread");
                enumerate.linkSystemLibrary("dl");
            }

            var enumerate_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "demos/enumerate/");
            enumerate.addCSourceFiles(enumerate_srcs.c, &.{});
            enumerate.addCSourceFiles(enumerate_srcs.cpp, &.{});

            b.installArtifact(enumerate);
        } //enumerate

        { //c_test
            var c_test = b.addExecutable(.{
                .name = "c_test",
                // In this case the main source file is merely a path, however, in more
                // complicated build scripts, this could be a generated file.
                .target = target,
                .optimize = optimize,
            });

            c_test.addIncludePath(root_path ++ "include/");

            c_test.linkLibC();
            c_test.linkLibCpp();
            c_test.linkLibrary(static_soloud);

            linkAgainstSoLoudLibs(c_test, build_options);

            if (!target.isWindows()) {
                c_test.linkSystemLibrary("pthread");
                c_test.linkSystemLibrary("dl");
            }

            var enumerate_srcs = try find_c_cpp_sources(b.allocator, root_path ++ "demos/c_test/");
            c_test.addCSourceFiles(enumerate_srcs.c, &.{});
            c_test.addCSourceFiles(enumerate_srcs.cpp, &.{});

            //Add the C api
            c_test.addCSourceFile("src/c_api/soloud_c.cpp", &.{});

            b.installArtifact(c_test);
        } //c_test
    }
}

fn linkAgainstSoLoudLibs(compile_step: *std.build.CompileStep, build_options: SoloudBuildOptions) void {
    if (!build_options.link_libs) {
        if (build_options.with_alsa) {
            compile_step.linkSystemLibrary("asound");
        }
        if (build_options.with_jack) {
            compile_step.linkSystemLibrary("jack");
        }
        if (build_options.with_coreaudio) {
            // compile_step.linkSystemLibrary("AudioToolbox.framework");
            compile_step.linkFramework("AudioToolbox");
        }
        if (build_options.with_winmm) {
            compile_step.linkSystemLibrary("winmm");
        }
    }
}

fn find_c_cpp_sources(allocator: std.mem.Allocator, search_path: []const u8) !struct { c: []const []const u8, cpp: []const []const u8 } {
    var c_list = std.ArrayList([]const u8).init(allocator);
    var cpp_list = std.ArrayList([]const u8).init(allocator);

    var dir = try std.fs.openIterableDirAbsolute(search_path, .{});
    defer dir.close();

    var walker: std.fs.IterableDir.Walker = try dir.walk(allocator);
    defer walker.deinit();

    var itr_next: ?std.fs.IterableDir.Walker.WalkerEntry = try walker.next();
    while (itr_next != null) {
        var next: std.fs.IterableDir.Walker.WalkerEntry = itr_next.?;

        //if the file is a c source file
        if (std.mem.endsWith(u8, next.path, ".c")) {
            var item = try allocator.alloc(u8, next.path.len + search_path.len);

            //copy the root first
            std.mem.copy(u8, item, search_path);

            //copy the filepath next
            std.mem.copy(u8, item[search_path.len..], next.path);

            try c_list.append(item);
        }

        //if the file is a cpp source file
        if (std.mem.endsWith(u8, next.path, ".cpp")) {
            var item = try allocator.alloc(u8, next.path.len + search_path.len);

            //copy the root first
            std.mem.copy(u8, item, search_path);

            //copy the filepath next
            std.mem.copy(u8, item[search_path.len..], next.path);

            try cpp_list.append(item);
        }

        itr_next = try walker.next();
    }

    return .{ .c = try c_list.toOwnedSlice(), .cpp = try cpp_list.toOwnedSlice() };
}

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const root_path = root() ++ "/";
