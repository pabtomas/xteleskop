const std = @import ("std");
const builtin = @import ("builtin");

pub usingnamespace @cImport ({
  @cDefine ("GLFW_INCLUDE_VULKAN", "1");
  @cDefine ("GLFW_INCLUDE_NONE", "1");
  @cInclude ("GLFW/glfw3.h");
  @cInclude ("dcimgui.h");
  @cInclude ("backends/dcimgui_impl_glfw.h");
  @cInclude ("backends/dcimgui_impl_vulkan.h");
});

pub const call_conv: std.builtin.CallingConvention =
  if (builtin.os.tag == .windows and builtin.cpu.arch == .x86)
    .Stdcall
  else if (builtin.abi == .android and
    (builtin.cpu.arch.isARM () or builtin.cpu.arch.isThumb ()) and
    std.Target.arm.featureSetHas (builtin.cpu.features, .has_v7) and
    builtin.cpu.arch.ptrBitWidth () == 32)
      // On Android 32-bit ARM targets, Vulkan functions use the "hardfloat"
      // calling convention, i.e. float parameters are passed in registers. This
      // is true even if the rest of the application passes floats on the stack,
      // as it does by default when compiling for the armeabi-v7a NDK ABI.
      .AAPCSVFP
  else
    .C;
