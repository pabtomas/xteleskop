const std   = @import("std");
const vk    = @import("vulkan");
const glfw  = @import("glfw");
const build = @import("build_options");

const print = std.debug.print;

const MainError = error
{
  InitError,
  LoopError,
  CleanupError,
};

fn init () MainError!void
{
  print("Init OK\n", .{});
}

fn loop () MainError!void
{
  print("Loop OK\n", .{});
}

fn cleanup () MainError!void
{
  print("Clean Up OK\n", .{});
}

pub fn main () u8
{
  if (build.DEV)
  {
    print("You are running a dev build\n", .{});
  }
  init () catch
  {
    print("Init error\n", .{});
    return 1;
  };
  loop () catch
  {
    print("Loop error\n", .{});
    return 1;
  };
  cleanup () catch
  {
    print("Cleanup error\n", .{});
    return 1;
  };

  return 0;
}
