const std = @import ("std");

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const cimgui_dep = builder.dependency ("cimgui", .{
    .target = target,
    .optimize = optimize,
  });
  const cimgui = cimgui_dep.artifact ("cimgui");

  const c = builder.createModule (.{
                                    .root_source_file = .{ .path = "src/binding/import.zig", },
                                    .target = target,
                                    .optimize = optimize,
                                   });
  c.linkSystemLibrary ("glfw", .{});
  c.linkSystemLibrary ("vulkan", .{});
  c.linkLibrary (cimgui);
  c.addIncludePath (cimgui_dep.path ("imgui"));

  const datetime_dep = builder.dependency ("zig-datetime", .{
    .target = target,
    .optimize = optimize,
  });

  const modules: [] const struct { ptr: *std.Build.Module, name: [] const u8 } =
    &.{
       .{
         .name = "datetime",
         .ptr = datetime_dep.module ("zig-datetime"),
        },
       .{
         .name = "glfw",
         .ptr = builder.createModule (.{
           .root_source_file = .{ .path = "src/binding/glfw.zig", },
           .target = target,
           .optimize = optimize,
         }),
        },
       .{
         .name = "vulkan",
         .ptr = builder.createModule (.{
           .root_source_file = .{ .path = "src/binding/vulkan.zig", },
           .target = target,
           .optimize = optimize,
         }),
        },
       .{
         .name = "imgui",
         .ptr = builder.createModule (.{
           .root_source_file = .{ .path = "src/binding/imgui.zig", },
           .target = target,
           .optimize = optimize,
         }),
        },
      };

  const EXE = "spaceporn";
  const exe = builder.addExecutable (.{
    .name = EXE,
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
  });

  for (modules) |*module|
  {
    module.ptr.addImport ("c", c);
    exe.root_module.addImport (module.name, module.ptr);
  }

  builder.installArtifact (exe);

  const run_cmd = builder.addRunArtifact (exe);
  run_cmd.step.dependOn (builder.getInstallStep ());

  const run_step = builder.step ("run", "Run " ++ EXE);
  run_step.dependOn (&run_cmd.step);

  const unit_tests = builder.addTest (.{
    .target = target,
    .optimize = optimize,
    .test_runner = "test/runner.zig",
    .root_source_file = .{ .path = "test/main.zig" },
  });
  unit_tests.step.dependOn (builder.getInstallStep ());

  const run_unit_tests = builder.addRunArtifact (unit_tests);

  const test_step = builder.step ("test", "Run tests");
  test_step.dependOn (&run_unit_tests.step);
}

fn compile_shaders (builder: *std.Build, exe: *std.Build.Step.Compile) void
{
  const shaders_dir = builder.build_root.handle.openIterableDir ("shaders", .{}) catch @panic ("Failed to open shaders directory");

  var it = shaders_dir.iterate ();
  while (it.next () catch @panic ("Failed to iterate shader directory")) |entry|
  {
    if (entry.kind == .file)
    {
      const ext = std.fs.path.extension (entry.name);
      if (std.mem.eql (u8, ext, ".glsl"))
      {
        const basename = std.fs.path.basename (entry.name);
        const name = basename [0 .. basename.len - ext.len];

        std.debug.print ("Found shader file to compile: {s}. Compiling with name: {s}\n", .{ entry.name, name });
        add_shader (builder, exe, name);
      }
    }
  }
}

fn add_shader (builder: *std.Build, exe: *std.Build.Step.Compile, name: [] const u8) void
{
  const source = std.fmt.allocPrint (builder.allocator, "shaders/{s}.glsl", .{ name }) catch @panic ("OOM");
  const outpath = std.fmt.allocPrint (builder.allocator, "shaders/{s}.spv", .{ name }) catch @panic ("OOM");

  const shader_compilation = builder.addSystemCommand (&.{ "glslangValidator" });
  shader_compilation.addArg ("-V");
  shader_compilation.addArg ("-o");
  const output = shader_compilation.addOutputFileArg (outpath);
  shader_compilation.addFileArg (.{ .path = source });

  exe.root_module.addAnonymousImport (name, .{ .root_source_file = output });
}
