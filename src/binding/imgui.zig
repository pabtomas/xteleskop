const std = @import ("std");
const c = @import ("c");
const _glfw = @import ("glfw");
const _vk = @import ("vk");

pub usingnamespace imgui;

pub const imgui = struct
{
  pub const vk = struct
  {
    pub const InitInfo = struct
    {
      Instance:              _vk.Instance,
      PhysicalDevice:        _vk.PhysicalDevice,
      Device:                _vk.Device,
      QueueFamily:           u32,
      Queue:                 _vk.Queue,
      PipelineCache:         _vk.PipelineCache,
      DescriptorPool:        _vk.DescriptorPool,
      Subpass:               u32,
      MinImageCount:         u32,
      ImageCount:            u32,
      MSAASamples:           c_uint,
      UseDynamicRendering:   bool,
      ColorAttachmentFormat: i32,
      Allocator:             [*c] const _vk.AllocationCallbacks,
      CheckVkResultFn:       ?*const fn (c_int) callconv (.C) void,
    };
  };

  pub const glfw = struct
  {
    pub fn init () !void
    {
      const window = try _glfw.Context.get ();
      if (!c.cImGui_ImplGlfw_InitForVulkan (@ptrCast (window), true)) return error.ImGuiGlfwInitForVulkanFailure;
    }
  };

  pub const Context = struct
  {
    pub fn create () !void
    {
      if (c.ImGui_CreateContext (null) == null) return error.ImGuiCreateContextFailure;
    }
  };

  pub const Col = struct
  {
    pub const WindowBg = c.ImGuiCol_WindowBg;
  };

  pub const Style = struct
  {
    pub fn colorsDark () void
    {
      c.ImGui_StyleColorsDark (null);
    }

    const SetterTag = enum
    {
      colors,
      window_rounding,
    };

    const Setter = union (SetterTag)
    {
      colors: struct { index: usize, channel: [] const u8, value: usize, },
      window_rounding: usize,
    };

    fn zig_to_c_name (setter: Setter) [] const u8
    {
      return switch (setter)
      {
        .colors          => "Colors",
        .window_rounding => "WindowRounding",
      };
    }

    pub fn set (comptime setters: [] const Setter) void
    {
      const style = c.ImGui_GetStyle ();

      inline for (setters) |setter|
      {
        switch (setter)
        {
          .colors => |colors| @field (@field (style.*, "Colors") [colors.index], colors.channel) = colors.value,
          else => |active| @field (style.*, zig_to_c_name (setter)) = @field (setter, @tagName (active)),
        }
      }
    }
  };
};
