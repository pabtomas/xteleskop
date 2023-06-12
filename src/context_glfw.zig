const std   = @import ("std");
const glfw  = @import ("glfw");

const utils = @import ("utils.zig");
const debug = utils.debug;
const exe   = utils.exe;

fn callback (code: glfw.ErrorCode, description: [:0] const u8) void
{
  std.log.err ("glfw: {}: {s}", .{ code, description });
}

pub const context_glfw = struct
{
  window:             glfw.Window,
  extensions:         [][*:0] const u8,
  instance_proc_addr: *const fn (?*anyopaque, [*:0] const u8) callconv (.C) ?*const fn () callconv (.C) void,

  pub fn init () !context_glfw
  {
    var self: context_glfw = undefined;

    glfw.setErrorCallback (callback);
    if (!glfw.init (.{}))
    {
      std.log.err ("failed to initialize GLFW: {?s}", .{ glfw.getErrorString () });
      std.process.exit (1);
    }
    errdefer glfw.terminate ();

    // TODO: Hint

    self.window = glfw.Window.create (800, 600, exe, null, null, .{
      .client_api = .no_api,
    }) orelse {
      std.log.err ("failed to initialize GLFW window: {?s}", .{ glfw.getErrorString () });
      std.process.exit (1);
    };
    errdefer self.window.destroy ();

    self.extensions = glfw.getRequiredInstanceExtensions () orelse {
      const err = glfw.mustGetError();
      std.log.err("failed to get required vulkan instance extensions: error={s}", .{err.description});
      std.process.exit (1);
    };
    self.instance_proc_addr = &(glfw.getInstanceProcAddress);

    debug ("Init Glfw OK", .{});

    return self;
  }

  pub fn loop (self: context_glfw) !void
  {
    while (!self.window.shouldClose ())
    {
      glfw.pollEvents ();
    }
    debug ("Loop Glfw OK", .{});
  }

  pub fn cleanup (self: context_glfw) !void
  {
    self.window.destroy ();
    glfw.terminate ();
    debug ("Clean Up Glfw OK", .{});
  }
};
