const std = @import ("std");

const build = @import ("build_options");

const utils    = @import ("utils.zig");
const exe      = utils.exe;
const log_app  = utils.log_app;
const profile  = utils.profile;
const severity = utils.severity;

pub const options = struct
{
  const DEFAULT_HELP = false;
  const SHORT_HELP   = "-h";
  const LONG_HELP    = "--help";

  const DEFAULT_OUTPUT = null;
  const SHORT_OUTPUT   = "-o";
  const LONG_OUTPUT    = "--output";

  const DEFAULT_SEED = .{ .random = true, .sample = 0, };
  const SHORT_SEED   = "-S";
  const LONG_SEED    = "--seed";

  const DEFAULT_VERSION = false;
  const SHORT_VERSION   = "-v";
  const LONG_VERSION    = "--version";

  const OptionsWindow = enum
  {
    Basic,
  };

  const DEFAULT_WINDOW        = OptionsWindow.Basic;
  const DEFAULT_WINDOW_WIDTH  = 800;
  const DEFAULT_WINDOW_HEIGHT = 600;
  const SHORT_WINDOW          = "-w";
  const LONG_WINDOW           = "--window";

  const DEFAULT_CAMERA_DYNAMIC = false;
  const CAMERA_DYNAMIC         = "--camera-dynamic";
  const CAMERA_DYNAMIC_NO      = "--no" ++ CAMERA_DYNAMIC [1..];

  const DEFAULT_CAMERA_FPS = null;
  const CAMERA_FPS         = "--camera-fps";

  const DEFAULT_CAMERA_PIXEL = 200;
  const CAMERA_PIXEL         = "--camera-pixel";

  const DEFAULT_CAMERA_SLIDE = null;
  const CAMERA_SLIDE         = "--camera-slide";

  const DEFAULT_CAMERA_ZOOM = .{ .random = true, .percent = 0, };
  const CAMERA_ZOOM         = "--camera-zoom";

  const DEFAULT_COLORS_SMOOTH = false;
  const COLORS_SMOOTH         = "--colors-smooth";
  const COLORS_SMOOTH_NO      = "--no" ++ COLORS_SMOOTH [1..];

  const DEFAULT_STARS_DYNAMIC = false;
  const STARS_DYNAMIC         = "--stars-dynamic";
  const STARS_DYNAMIC_NO      = "--no" ++ STARS_DYNAMIC [1..];

  const camera_options = struct
  {
    dynamic: bool                                   = DEFAULT_CAMERA_DYNAMIC,
    fps:     ?u8                                    = DEFAULT_CAMERA_FPS,
    pixel:   u32                                    = DEFAULT_CAMERA_PIXEL,
    slide:   ?u32                                   = DEFAULT_CAMERA_SLIDE,
    zoom:    struct { random: bool, percent: u32, } = DEFAULT_CAMERA_ZOOM,
  };

  const colors_options = struct
  {
    smooth: bool = DEFAULT_COLORS_SMOOTH,
  };

  const stars_options = struct
  {
    dynamic: bool = DEFAULT_STARS_DYNAMIC,
  };

  help:    bool                                                       = DEFAULT_HELP,
  output:  ?[] const u8                                               = DEFAULT_OUTPUT,
  seed:    struct { random: bool, sample: u32, }                      = DEFAULT_SEED,
  version: bool                                                       = DEFAULT_VERSION,
  window:  struct { type: OptionsWindow, width: ?u32, height: ?u32, } = .{ .type = DEFAULT_WINDOW, .width = DEFAULT_WINDOW_WIDTH, .height = DEFAULT_WINDOW_HEIGHT, },
  camera:  camera_options                                             = camera_options {},
  colors:  colors_options                                             = colors_options {},
  stars:   stars_options                                              = stars_options {},

  const Self = @This ();

  const OptionsError = error
  {
    NoExecutableName,
    MissingArgument,
    UnknownOption,
    UnknownArgument,
  };

  fn parse (self: *Self, allocator: std.mem.Allocator, opts: *std.ArrayList ([] const u8)) !void
  {
    var index: usize = 0;
    var new_opt_used = false;
    var new_opt: [] const u8 = undefined;

    while (index < opts.items.len)
    {
      std.log.debug ("{s} | {s}", .{opts.items, opts.items [index]});

      // Handle '-abc' the same as '-a -bc' for short-form no-arg options
      if (opts.items [index][0] == '-' and opts.items [index].len > 2
          and (opts.items [index][1] == SHORT_HELP [1]
            or opts.items [index][1] == SHORT_VERSION [1]
              )
         )
      {
        try opts.insert (index + 1, opts.items [index][0..2]);
        new_opt = try std.fmt.allocPrint(allocator, "-{s}", .{ opts.items [index][2..] });
        new_opt_used = true;
        try opts.insert (index + 2, new_opt);
        _ = opts.orderedRemove (index);
        continue;
      }

      // Handle '-foo' the same as '-f oo' for short-form 1-arg options
      if (opts.items [index][0] == '-' and opts.items [index].len > 2
          and (opts.items [index][1] == SHORT_OUTPUT [1]
            or opts.items [index][1] == SHORT_SEED [1]
            or opts.items [index][1] == SHORT_WINDOW [1]
              )
         )
      {
        try opts.insert (index + 1, opts.items [index][0..2]);
        try opts.insert (index + 2, opts.items [index][2..]);
        _ = opts.orderedRemove (index);
        continue;
      }

      // Handle '--file=file1' the same as '--file file1' for long-form 1-arg options
      if (    std.mem.startsWith (u8, opts.items [index], CAMERA_PIXEL ++ "=")
           or std.mem.startsWith (u8, opts.items [index], CAMERA_ZOOM ++ "=")
           or std.mem.startsWith (u8, opts.items [index], LONG_OUTPUT ++ "=")
           or std.mem.startsWith (u8, opts.items [index], LONG_SEED ++ "=")
           or std.mem.startsWith (u8, opts.items [index], LONG_WINDOW ++ "=")
         )
      {
        const eq_index = std.mem.indexOf (u8, opts.items [index], "=").?;
        try opts.insert (index + 1, opts.items [index][0..eq_index]);
        try opts.insert (index + 2, opts.items [index][(eq_index + 1)..]);
        _ = opts.orderedRemove (index);
        continue;
      }

      // help option
      if (std.mem.eql (u8, opts.items [index], SHORT_HELP) or std.mem.eql (u8, opts.items [index], LONG_HELP))
      {
        self.help = true;
      // output option
      } else if (std.mem.eql (u8, opts.items [index], SHORT_OUTPUT) or std.mem.eql (u8, opts.items [index], LONG_OUTPUT)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s},{s} option", severity.ERROR, .{ SHORT_OUTPUT, LONG_OUTPUT });
          return OptionsError.MissingArgument;
        } else {
          self.output = opts.items [index + 1];
          index += 1;
        }
      // seed option
      } else if (std.mem.eql (u8, opts.items [index], SHORT_SEED) or std.mem.eql (u8, opts.items [index], LONG_SEED)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s},{s} option", severity.ERROR, .{ SHORT_SEED, LONG_SEED });
          return OptionsError.MissingArgument;
        } else {
          self.seed.sample = std.fmt.parseInt (u32, opts.items [index + 1], 10) catch |err|
                             {
                               if (err == error.InvalidCharacter)
                               {
                                 try log_app ("mandatory argument with {s},{s} option should a positive integer", severity.ERROR, .{ SHORT_SEED, LONG_SEED });
                               }
                               return err;
                             };
          self.seed.random = false;
          index += 1;
        }
      // version option
      } else if (std.mem.eql (u8, opts.items [index], SHORT_VERSION) or std.mem.eql (u8, opts.items [index], LONG_VERSION)) {
        self.version = true;
      // window option
      } else if (std.mem.eql (u8, opts.items [index], SHORT_WINDOW) or std.mem.eql (u8, opts.items [index], LONG_WINDOW)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s},{s} option", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW });
          return OptionsError.MissingArgument;
        } else {
          if (std.mem.count (u8, opts.items [index + 1], "x") == 1)
          {
            var token_iterator = std.mem.tokenizeScalar (u8, opts.items [index + 1], 'x');
            self.window.type = OptionsWindow.Basic;

            if (token_iterator.next ()) |token|
            {
              self.window.width = std.fmt.parseInt(u32, token, 10) catch |err|
                                  {
                                    if (err == error.InvalidCharacter)
                                    {
                                      try log_app ("mandatory argument with {s},{s} option should respect this format: WIDTHxHEIGHT", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW });
                                    }
                                    return err;
                                  };
            } else {
              try log_app ("unknown argument with {s},{s} option: '{s}'", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW, opts.items [index + 1] });
              return OptionsError.UnknownArgument;
            }

            if (token_iterator.next ()) |token|
            {
              self.window.height = std.fmt.parseInt(u32, token, 10) catch |err|
                                   {
                                     if (err == error.InvalidCharacter)
                                     {
                                       try log_app ("mandatory argument with {s},{s} option should respect this format: WIDTHxHEIGHT", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW });
                                     }
                                     return err;
                                   };
            } else {
              try log_app ("unknown argument with {s},{s} option: '{s}'", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW, opts.items [index + 1] });
              return OptionsError.UnknownArgument;
            }

            if (token_iterator.next () != null)
            {
              try log_app ("unknown argument with {s},{s} option: '{s}'", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW, opts.items [index + 1] });
              return OptionsError.UnknownArgument;
            }

            index += 1;
          } else {
            try log_app ("unknown argument with {s},{s} option: '{s}'", severity.ERROR, .{ SHORT_WINDOW, LONG_WINDOW, opts.items [index + 1] });
            return OptionsError.UnknownArgument;
          }
        }

      // --- CAMERA ----------------------------------------------------------

      // camera dynamic option
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_DYNAMIC)) {
        self.camera.dynamic = true;
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_DYNAMIC_NO)) {
        self.camera.dynamic = false;
      // camera fps option
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_FPS)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s} option", severity.ERROR, .{ CAMERA_FPS });
          return OptionsError.MissingArgument;
        } else {
          self.camera.fps = std.fmt.parseInt (u8, opts.items [index + 1], 10) catch |err|
                            {
                              if (err == error.InvalidCharacter)
                              {
                                try log_app ("mandatory argument with {s} option should be a positive integer", severity.ERROR, .{ CAMERA_FPS });
                              }
                              return err;
                            };
          index += 1;
        }
      // camera pixel option
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_PIXEL)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s} option", severity.ERROR, .{ CAMERA_PIXEL });
          return OptionsError.MissingArgument;
        } else {
          self.camera.pixel = std.fmt.parseInt (u32, opts.items [index + 1], 10) catch |err|
                              {
                                if (err == error.InvalidCharacter)
                                {
                                  try log_app ("mandatory argument with {s} option should be a positive integer", severity.ERROR, .{ CAMERA_PIXEL });
                                }
                                return err;
                              };
          index += 1;
        }
      // camera slide option
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_SLIDE)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s} option", severity.ERROR, .{ CAMERA_SLIDE });
          return OptionsError.MissingArgument;
        } else {
          self.camera.slide = std.fmt.parseInt (u32, opts.items [index + 1], 10) catch |err|
                              {
                                if (err == error.InvalidCharacter)
                                {
                                  try log_app ("mandatory argument with {s} option should be a positive integer", severity.ERROR, .{ CAMERA_SLIDE });
                                }
                                return err;
                              };
          index += 1;
        }
      // camera zoom option
      } else if (std.mem.eql (u8, opts.items [index], CAMERA_ZOOM)) {
        if (index + 1 >= opts.items.len)
        {
          try log_app ("missing mandatory argument with {s} option", severity.ERROR, .{ CAMERA_ZOOM });
          return OptionsError.MissingArgument;
        } else {
          self.camera.zoom.percent = std.fmt.parseInt (u32, opts.items [index + 1], 10) catch |err|
                                     {
                                       if (err == error.InvalidCharacter)
                                       {
                                         try log_app ("mandatory argument with {s} option should be a positive integer", severity.ERROR, .{ CAMERA_ZOOM });
                                       }
                                       return err;
                                     };
          self.camera.zoom.random  = false;
          index += 1;
        }

      // --- COLORS ----------------------------------------------------------

      // colors smooth option
      } else if (std.mem.eql (u8, opts.items [index], COLORS_SMOOTH)) {
        self.colors.smooth = true;
      } else if (std.mem.eql (u8, opts.items [index], COLORS_SMOOTH_NO)) {
        self.colors.smooth = false;

      // --- STARS -----------------------------------------------------------

      // stars dynamic option
      } else if (std.mem.eql (u8, opts.items [index], STARS_DYNAMIC)) {
        self.stars.dynamic = true;
      } else if (std.mem.eql (u8, opts.items [index], STARS_DYNAMIC_NO)) {
        self.stars.dynamic = false;

      // ---------------------------------------------------------------------

      } else {
        try log_app ("unknown option: '{s}'", severity.ERROR, .{ opts.items [index] });
        return OptionsError.UnknownOption;
      }

      index += 1;
    }
  }

  fn check (self: Self) void
  {
    _ = self;
  }

  fn show (self: Self) !void
  {
    if (self.output == null)
    {
      try log_app ("output: not used", severity.INFO, .{});
    } else {
      try log_app ("output: {s}", severity.INFO, .{ self.output.? });
    }
    try log_app ("seed: {any}", severity.INFO, .{ self.seed });
    try log_app ("window: {any}", severity.INFO, .{ self.window });

    try log_app ("camera dynamic: {}", severity.INFO, .{ self.camera.dynamic });
    if (self.camera.fps == null)
    {
      try log_app ("camera max fps: maximum unspecified", severity.INFO, .{});
    } else {
      try log_app ("camera max fps: {d}", severity.INFO, .{ self.camera.fps.? });
    }
    try log_app ("camera pixel: {d}", severity.INFO, .{ self.camera.pixel });
    if (self.camera.slide == null)
    {
      try log_app ("camera slide mode: not used", severity.INFO, .{});
    } else {
      try log_app ("camera mode: every {d} minutes", severity.INFO, .{ self.camera.slide.? });
    }
    try log_app ("zoom: {any}", severity.INFO, .{ self.camera.zoom });

    try log_app ("colors smooth transition: {}", severity.INFO, .{ self.colors.smooth });

    try log_app ("stars dynamic transition: {}", severity.INFO, .{ self.stars.dynamic });
  }

  pub fn init (allocator: std.mem.Allocator) !Self
  {
    var self = Self {};

    var opts_iterator = try std.process.argsWithAllocator (allocator);
    defer opts_iterator.deinit();

    _ = opts_iterator.next () orelse
        {
          return OptionsError.NoExecutableName;
        };

    var opts = std.ArrayList ([] const u8).init (allocator);

    while (opts_iterator.next ()) |opt|
    {
      try opts.append (opt);
    }

    try self.parse (allocator, &opts);
    self.check ();
    if (build.LOG_LEVEL > @intFromEnum (profile.TURBO)) try self.show ();

    return self;
  }

  pub fn init2 (allocator: std.mem.Allocator, opts: *std.ArrayList ([] const u8)) !Self
  {
    var self = Self {};

    try self.parse (allocator, opts);
    self.check ();
    if (build.LOG_LEVEL > @intFromEnum (profile.TURBO)) try self.show ();

    return self;
  }
};

test "parse CLI args: empty"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  const opts = try options.init (allocator);

  try std.testing.expect (opts.help == options.DEFAULT_HELP);
  try std.testing.expect (opts.output == options.DEFAULT_OUTPUT);
  try std.testing.expect (opts.seed.random == true);
  try std.testing.expect (opts.seed.sample == 0);
  try std.testing.expect (opts.version == options.DEFAULT_VERSION);
  try std.testing.expect (opts.window.type == options.DEFAULT_WINDOW);
  try std.testing.expect (opts.window.width == options.DEFAULT_WINDOW_WIDTH);
  try std.testing.expect (opts.window.height == options.DEFAULT_WINDOW_HEIGHT);
  try std.testing.expect (opts.camera.dynamic == options.DEFAULT_CAMERA_DYNAMIC);
  try std.testing.expect (opts.camera.fps == options.DEFAULT_CAMERA_FPS);
  try std.testing.expect (opts.camera.pixel == options.DEFAULT_CAMERA_PIXEL);
  try std.testing.expect (opts.camera.slide == options.DEFAULT_CAMERA_SLIDE);
  try std.testing.expect (opts.camera.zoom.random == true);
  try std.testing.expect (opts.camera.zoom.percent == 0);
  try std.testing.expect (opts.colors.smooth == options.DEFAULT_COLORS_SMOOTH);
  try std.testing.expect (opts.stars.dynamic == options.DEFAULT_STARS_DYNAMIC);
}

test "parse CLI args: short-help"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  try opts_list.appendSlice (&[_][] const u8 { options.SHORT_HELP, });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (opts.output == options.DEFAULT_OUTPUT);
  try std.testing.expect (opts.seed.random == true);
  try std.testing.expect (opts.seed.sample == 0);
  try std.testing.expect (opts.version == options.DEFAULT_VERSION);
  try std.testing.expect (opts.window.type == options.DEFAULT_WINDOW);
  try std.testing.expect (opts.window.width == options.DEFAULT_WINDOW_WIDTH);
  try std.testing.expect (opts.window.height == options.DEFAULT_WINDOW_HEIGHT);
  try std.testing.expect (opts.camera.dynamic == options.DEFAULT_CAMERA_DYNAMIC);
  try std.testing.expect (opts.camera.fps == options.DEFAULT_CAMERA_FPS);
  try std.testing.expect (opts.camera.pixel == options.DEFAULT_CAMERA_PIXEL);
  try std.testing.expect (opts.camera.slide == options.DEFAULT_CAMERA_SLIDE);
  try std.testing.expect (opts.camera.zoom.random == true);
  try std.testing.expect (opts.camera.zoom.percent == 0);
  try std.testing.expect (opts.colors.smooth == options.DEFAULT_COLORS_SMOOTH);
  try std.testing.expect (opts.stars.dynamic == options.DEFAULT_STARS_DYNAMIC);
}

test "parse CLI args: short-help short-version short-seed short-window"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const seed_arg = "2";
  const window_width = "1280";
  const window_height = "1024";
  const window_arg = window_width ++ "x" ++ window_height;
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_HELP,
                                               options.SHORT_VERSION,
                                               options.SHORT_SEED,
                                               seed_arg,
                                               options.SHORT_WINDOW,
                                               window_arg,
                                             });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (opts.output == options.DEFAULT_OUTPUT);
  try std.testing.expect (opts.seed.random == false);
  try std.testing.expect (opts.seed.sample == try std.fmt.parseInt (u32, seed_arg, 10));
  try std.testing.expect (opts.version == true);
  try std.testing.expect (opts.window.type == options.DEFAULT_WINDOW);
  try std.testing.expect (opts.window.width == try std.fmt.parseInt (u32, window_width, 10));
  try std.testing.expect (opts.window.height == try std.fmt.parseInt (u32, window_height, 10));
  try std.testing.expect (opts.camera.dynamic == options.DEFAULT_CAMERA_DYNAMIC);
  try std.testing.expect (opts.camera.fps == options.DEFAULT_CAMERA_FPS);
  try std.testing.expect (opts.camera.pixel == options.DEFAULT_CAMERA_PIXEL);
  try std.testing.expect (opts.camera.slide == options.DEFAULT_CAMERA_SLIDE);
  try std.testing.expect (opts.camera.zoom.random == true);
  try std.testing.expect (opts.camera.zoom.percent == 0);
  try std.testing.expect (opts.colors.smooth == options.DEFAULT_COLORS_SMOOTH);
  try std.testing.expect (opts.stars.dynamic == options.DEFAULT_STARS_DYNAMIC);
}

test "parse CLI args: wrong window argument 1"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const window_width = "1280";
  const window_height = "1024";
  const window_arg = window_width ++ "xx" ++ window_height;
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_WINDOW,
                                               window_arg,
                                             });

  try std.testing.expectError(options.OptionsError.UnknownArgument, options.init2 (allocator, &opts_list));
}

test "parse CLI args: wrong window argument 2"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const window_height = "1024";
  const window_arg = "x" ++ window_height;
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_WINDOW,
                                               window_arg,
                                             });

  try std.testing.expectError(options.OptionsError.UnknownArgument, options.init2 (allocator, &opts_list));
}

test "parse CLI args: wrong window argument 3"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const window_width = "1280";
  const window_arg = window_width ++ "x";
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_WINDOW,
                                               window_arg,
                                             });

  try std.testing.expectError(options.OptionsError.UnknownArgument, options.init2 (allocator, &opts_list));
}

test "parse CLI args: wrong window argument 4"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const window_width = "1280";
  const window_height = "1024";
  const window_arg = window_width ++ "x" ++ window_height ++ "weirdending";
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_WINDOW,
                                               window_arg,
                                             });

  try std.testing.expectError(error.InvalidCharacter, options.init2 (allocator, &opts_list));
}

test "parse CLI args: missing window argument"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  try opts_list.appendSlice (&[_][] const u8 { options.LONG_WINDOW, });

  try std.testing.expectError(options.OptionsError.MissingArgument, options.init2 (allocator, &opts_list));
}

test "parse CLI args: combined short-help short-version short-output"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const output_arg = "potato";
  try opts_list.appendSlice (&[_][] const u8 { options.SHORT_HELP ++ options.SHORT_VERSION [1..] ++ options.SHORT_OUTPUT [1..] ++ output_arg, });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (std.mem.eql (u8, opts.output.?, output_arg));
  try std.testing.expect (opts.seed.random == true);
  try std.testing.expect (opts.seed.sample == 0);
  try std.testing.expect (opts.version == true);
  try std.testing.expect (opts.window.type == options.DEFAULT_WINDOW);
  try std.testing.expect (opts.window.width == options.DEFAULT_WINDOW_WIDTH);
  try std.testing.expect (opts.window.height == options.DEFAULT_WINDOW_HEIGHT);
  try std.testing.expect (opts.camera.dynamic == options.DEFAULT_CAMERA_DYNAMIC);
  try std.testing.expect (opts.camera.fps == options.DEFAULT_CAMERA_FPS);
  try std.testing.expect (opts.camera.pixel == options.DEFAULT_CAMERA_PIXEL);
  try std.testing.expect (opts.camera.slide == options.DEFAULT_CAMERA_SLIDE);
  try std.testing.expect (opts.camera.zoom.random == true);
  try std.testing.expect (opts.camera.zoom.percent == 0);
  try std.testing.expect (opts.colors.smooth == options.DEFAULT_COLORS_SMOOTH);
  try std.testing.expect (opts.stars.dynamic == options.DEFAULT_STARS_DYNAMIC);
}

test "parse CLI args: complex 1"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  const output_arg = "potato";
  const camera_pixel_arg = "150";
  const camera_zoom_arg = "50";
  try opts_list.appendSlice (&[_][] const u8 {
                                               options.STARS_DYNAMIC,
                                               options.COLORS_SMOOTH,
                                               options.SHORT_VERSION ++ options.SHORT_OUTPUT [1..] ++ options.SHORT_HELP [1..] ++ output_arg,
                                               options.CAMERA_PIXEL,
                                               camera_pixel_arg,
                                               options.CAMERA_ZOOM ++ "=" ++ camera_zoom_arg,
                                             });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == options.DEFAULT_HELP);
  try std.testing.expect (std.mem.eql (u8, opts.output.?, options.SHORT_HELP [1..] ++ output_arg));
  try std.testing.expect (opts.seed.random == true);
  try std.testing.expect (opts.seed.sample == 0);
  try std.testing.expect (opts.version == true);
  try std.testing.expect (opts.window.type == options.DEFAULT_WINDOW);
  try std.testing.expect (opts.window.width == options.DEFAULT_WINDOW_WIDTH);
  try std.testing.expect (opts.window.height == options.DEFAULT_WINDOW_HEIGHT);
  try std.testing.expect (opts.camera.dynamic == options.DEFAULT_CAMERA_DYNAMIC);
  try std.testing.expect (opts.camera.fps == options.DEFAULT_CAMERA_FPS);
  try std.testing.expect (opts.camera.pixel == try std.fmt.parseInt (u32, camera_pixel_arg, 10));
  try std.testing.expect (opts.camera.slide == options.DEFAULT_CAMERA_SLIDE);
  try std.testing.expect (opts.camera.zoom.random == false);
  try std.testing.expect (opts.camera.zoom.percent == try std.fmt.parseInt (u32, camera_zoom_arg, 10));
  try std.testing.expect (opts.colors.smooth == true);
  try std.testing.expect (opts.stars.dynamic == true);
}
