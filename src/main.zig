const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800.0, .h = 600.0 },
            .title = "Codotaku Paint",
            .window_init_options = .{},
        },
    },
    .frameFn = appFrame,
    .initFn = appInit,
    .deinitFn = appDeinit,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();
var g_canvas: Canvas = undefined;

pub fn appInit(win: *dvui.Window) !void {
    g_canvas = try .init(gpa, 1024);
    _ = win;
}

pub fn appDeinit() void {}

pub fn appFrame() !dvui.App.Result {
    try g_canvas.widget();
    return .ok;
}

const Stroke = struct {
    const Self = @This();
    path: dvui.Path.Path,
    options: dvui.Path.StrokeOptions,

    pub fn init(allocator: std.mem.Allocator, path_builder: *dvui.Path.Builder, options: dvui.Path.StrokeOptions) !Self {
        const path = try path_builder.build().dupe(allocator);
        path_builder.points.clearRetainingCapacity();
        return .{
            .path = path,
            .options = options,
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }

    pub fn draw(self: Self) void {
        self.path.stroke(self.options);
    }
};

const Canvas = struct {
    const Self = @This();

    strokes_arena: std.heap.ArenaAllocator,
    strokes: std.ArrayList(Stroke),
    path_builder: dvui.Path.Builder,
    is_drawing: bool = false,
    stroke_options: dvui.Path.StrokeOptions = .{
        .color = .white,
        .thickness = 2,
    },

    pub fn init(allocator: std.mem.Allocator, strokes_capacity: usize) !Self {
        return .{
            .strokes_arena = .init(allocator),
            .strokes = try .initCapacity(allocator, strokes_capacity),
            .path_builder = .init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.path_builder.deinit();
        self.strokes.deinit(self.strokes_arena.child_allocator);
        self.strokes_arena.deinit();
    }

    pub fn widget(self: *Self) !void {
        var box = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .margin = .all(32),
        });
        defer box.deinit();

        for (dvui.events()) |e| {
            var ev = e;
            if (!box.matchEvent(&ev)) continue;
            switch (e.evt) {
                .mouse => |mouse| switch (mouse.action) {
                    .press => self.is_drawing = true,
                    .release => {
                        self.is_drawing = false;
                        try self.strokes.append(self.strokes_arena.child_allocator, try .init(self.strokes_arena.allocator(), &self.path_builder, self.stroke_options));
                    },
                    .motion => if (self.is_drawing) {
                        self.path_builder.addPoint(mouse.p);
                    },
                    else => {},
                },
                else => {},
            }
        }

        for (self.strokes.items) |stroke| stroke.draw();
        self.path_builder.build().stroke(self.stroke_options);
    }
};
