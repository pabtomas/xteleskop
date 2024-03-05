const c = @import ("c");
const std = @import ("std");

const main = @import ("main.zig");
const Bool = main.Bool;
const Monitor = main.Monitor;

const Context = @import ("context.zig").Context;

pub const Window = struct
{
  handle: *c.GLFWwindow,

  pub fn from (handle: *anyopaque) @This ()
  {
    return .{ .handle = @as (*c.GLFWwindow, @ptrCast (@alignCast (handle))), };
  }

  const Tag = enum
  {
    resizable,
    client_api,
  };

  pub const Hint = union (Tag)
  {
    pub const ClientAPI = enum (c_int)
    {
      no_api = c.GLFW_NO_API,
    };

    resizable: Bool,
    client_api: ClientAPI,

    fn tag (self: @This ()) c_int
    {
      return switch (self)
      {
        .resizable  => c.GLFW_RESIZABLE,
        .client_api => c.GLFW_CLIENT_API,
      };
    }
  };

  pub const Size = struct
  {
    width: u32,
    height: u32,

    pub const Optional = struct
    {
      width: ?u32,
      height: ?u32,
    };

    pub const Limits = struct
    {
      pub fn set (min: Optional, max: Optional) !void
      {
        if (min.width != null and max.width != null)
          std.debug.assert (min.width.? <= max.width.?);
        if (min.height != null and max.height != null)
          std.debug.assert (min.height.? <= max.height.?);

        const window = try Context.get ();
        c.glfwSetWindowSizeLimits (window,
          if (min.width) |min_width| @as (c_int, @intCast (min_width)) else c.GLFW_DONT_CARE,
          if (min.height) |min_height| @as (c_int, @intCast (min_height)) else c.GLFW_DONT_CARE,
          if (max.width) |max_width| @as (c_int, @intCast (max_width)) else c.GLFW_DONT_CARE,
          if (max.height) |max_height| @as (c_int, @intCast (max_height)) else c.GLFW_DONT_CARE);
      }
    };
  };

  pub fn create (width: u32, height: u32, title: [*:0] const u8,
    monitor: ?Monitor, share: ?@This (), hints: [] const Hint) !@This ()
  {
    for (hints) |hint| c.glfwWindowHint (hint.tag (), @intFromEnum (std.meta.activeTag (hint)));
    if (c.glfwCreateWindow (@as (c_int, @intCast (width)), @as (c_int, @intCast (height)),
      &title [0], if (monitor) |m| m.handle else null, if (share) |w| w.handle else null)) |handle|
        return from (handle);

    return error.WindowInitFailed;
  }

  pub fn destroy (self: @This ()) void
  {
    c.glfwDestroyWindow (self.handle);
  }

  pub const UserPointer = struct
  {
    pub fn get (comptime T: type) !?*T
    {
      const window = try Context.get ();
      if (c.glfwGetWindowUserPointer (window)) |user_pointer|
        return @as (?*T, @ptrCast (@alignCast (user_pointer)));
      return null;
    }

    pub fn set (pointer: ?*anyopaque) !void
    {
      const window = try Context.get ();
      c.glfwSetWindowUserPointer (window, pointer);
    }
  };

  pub const Framebuffer = struct
  {
    pub const Size = struct
    {
      pub fn get () !Window.Size
      {
        const window = try Context.get ();
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize (window, &width, &height);
        return .{
                  .width = @as (u32, @intCast (width)),
                  .height = @as (u32, @intCast (height)),
                };
      }

      pub const Callback = struct
      {
        pub fn set (comptime callback: ?fn (Window, u32, u32) void) !void
        {
          const window = try Context.get ();
          if (callback) |user_callback|
          {
            const Wrapper = struct
            {
              pub fn framebufferSizeCallbackWrapper (handle: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void
              {
                @call (.always_inline, user_callback, .{ from (handle.?), @as (u32, @intCast (width)), @as (u32, @intCast (height)), });
              }
            };

            _ = c.glfwSetFramebufferSizeCallback (window, Wrapper.framebufferSizeCallbackWrapper);
          } else _ = c.glfwSetFramebufferSizeCallback (window, null);
        }
      };
    };
  };
};
