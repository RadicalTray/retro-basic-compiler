const std = @import("std");
const eql = std.mem.eql;

const scanner = @import("./scanner.zig");
const parser = @import("./parser.zig");
const codegen = @import("./codegen.zig");

pub fn main() !u8 {
    const gpa = std.heap.smp_allocator;

    // NOTE: input string must live longer than tokens
    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var input_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var cyk = false; // TODO:

    const args = try std.process.argsAlloc(arena);
    {
        var i: usize = 1; // skip exe

        if (i < args.len and eql(u8, args[i], "cyk")) {
            cyk = true;
            i += 1;
        }

        if (i < args.len) {
            input_file = args[i];
            i += 1;
        } else {
            std.log.err("Expected an input file!", .{});
            return 1;
        }

        if (i < args.len) {
            output_file = args[i];
            i += 1;
        }

        if (i < args.len) {
            std.log.err("Too many arguments!", .{});
            return 1;
        }
    }

    const input = blk: {
        if (input_file) |file_path| {
            break :blk try std.fs.cwd().readFileAlloc(arena, file_path, std.math.maxInt(usize));
        } else {
            unreachable;
        }
    };

    const tokens = try scanner.scan(arena, input);
    const lines = try parser.parse(arena, tokens);
    const codes = try codegen.genBCode(arena, lines);

    const out_f = blk: {
        if (output_file) |file_path| {
            break :blk try std.fs.cwd().createFile(file_path, .{});
        } else {
            break :blk std.fs.File.stdout();
        }
    };
    defer out_f.close();

    var out_buffer: [128]u8 = undefined;
    var out_w = out_f.writer(&out_buffer);
    const out = &out_w.interface;

    for (0.., codes) |i, c| {
        // Doesn't really need an EOF tag
        if (c == .eof) {
            try out.print("0\n", .{});
            break;
        }

        const nums = c.toInts();
        if (i + 1 < codes.len and (codes[i + 1] == .line or codes[i + 1] == .eof)) {
            try out.print("{} {}\n", .{ nums[0], nums[1] });
        } else {
            try out.print("{} {} ", .{ nums[0], nums[1] });
        }
    }
    try out.flush();

    return 0;
}
