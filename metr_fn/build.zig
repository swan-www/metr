const std = @import("std");

pub const zig_version = std.builtin.zig_version;
pub const build_path_type = blk: {
	if(zig_version.major == 0)
	{
		if(zig_version.minor >= 12)
		{
			break :blk std.Build.LazyPath;
		}
		else unreachable;
	}
	else unreachable;
};

pub fn lazy_from_path(path_chars : []const u8, owner: *std.Build) std.Build.LazyPath
{
	if(zig_version.major == 0)
	{
		if(zig_version.minor >= 13)
		{
			return build_path_type{ .src_path = .{ .sub_path = path_chars, .owner = owner} };
		}
		else if(zig_version.minor >= 12)
		{
			return build_path_type{ .path = path_chars };
		}
		else unreachable;
	}
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    b.addModule("metr_fn", .{
		.target = target,
        .optimize = optimize,
		.root_source_file = lazy_from_path("metr_fn.zig", b),
	});
}