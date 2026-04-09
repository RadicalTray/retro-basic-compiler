const std = @import("std");
const eql = std.mem.eql;

const scanner = @import("./scanner.zig");
const parser = @import("./parser.zig");
const parser_cyk = @import("./parser_cyk.zig");
const parser_earley = @import("./parser_earley.zig");
const codegen = @import("./codegen.zig");

const usage =
    "Usage:\n" ++
    "To print BCode to stdout.\n" ++
    "\tcompiler input.basic\n" ++
    "To save BCode to a file.\n" ++
    "\tcompiler input.basic output.bcode\n";

pub fn main() !u8 {
    const gpa = std.heap.smp_allocator;

    // NOTE: input string must live longer than tokens
    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var input_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;

    const args = try std.process.argsAlloc(arena);
    {
        var i: usize = 1; // skip exe

        if (i < args.len) {
            input_file = args[i];
            i += 1;
        } else {
            std.log.err("Expected an input file!", .{});
            std.debug.print("{s}", .{usage});
            return 1;
        }

        if (i < args.len) {
            output_file = args[i];
            i += 1;
        }

        if (i < args.len) {
            std.log.err("Too many arguments!", .{});
            std.debug.print("{s}", .{usage});
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
    // const res = try parser_earley.parse(arena, tokens);
    const res = try parser_cyk.parse(arena, tokens);
    if (res) {
        std.debug.print("YYOOOOOOOO\n", .{});
    } else {
        std.debug.print("bruh\n", .{});
    }

    return 0;
}
