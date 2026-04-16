const std = @import("std");
const print = std.debug.print;
const Timer = std.time.Timer;

const scanner = @import("../scanner.zig");
const Token = scanner.Token;

const cyk = @import("../cyk.zig");
const earley = @import("../earley.zig");

const Result = @import("Result.zig");
const Data = Result.Data;

// TODO: new code structure
//  - TestType.zig -> generates inputs & rules
//  - a file doing something like this file, takes TestType.getStuff() and run
pub fn run() !void {
    const gpa = std.heap.smp_allocator;
    const n = 100;
    const tries = 5;
    const pairs = 10;

    var inputs: [n][]Token = undefined;
    for (0.., &inputs) |i, *x| {
        var y = try gpa.alloc(Token, (i + 1) * pairs * 2);
        for (0..(i + 1) * pairs) |j| y[j] = .init(.less, "", 0);
        for ((i + 1) * pairs..(i + 1) * pairs * 2) |j| y[j] = .init(.greater, "", 0);

        y[(i + 1) * pairs] = .init(.less, "", 0);

        x.* = y;
    }
    // for (0.., &inputs) |i, *x| {
    //     var y = try gpa.alloc(Token, (i + 1) * pairs * 2);
    //     for (0..(i + 1) * pairs) |j| y[j] = .init(.less, "", 0);
    //     for ((i + 1) * pairs..(i + 1) * pairs * 2) |j| y[j] = .init(.less, "", 0);
    //     x.* = y;
    // }

    const cyk_data = try gpa.alloc(Data, inputs.len);
    defer gpa.free(cyk_data);
    const earley_data = try gpa.alloc(Data, inputs.len);
    defer gpa.free(earley_data);

    for (0.., inputs) |i, tokens| {
        print("Running CYK {}\n", .{i + 1});
        var cyk_result = false;
        var cyk_timer: Timer = try .start();
        for (0..tries) |_| {
            cyk_result = try cyk.parse(gpa, tokens, &.{
                .init(&.{
                    &.{ .rule(2), .rule(3) },
                    &.{ .rule(2), .rule(1) },
                }),
                .init(&.{
                    &.{ .rule(0), .rule(3) },
                }),
                .init(&.{
                    &.{.symbol(.less)},
                }),
                .init(&.{
                    &.{.symbol(.greater)},
                }),
            });

            // cyk_result = try cyk.parse(gpa, tokens, &.{
            //     .init(&.{ // 0
            //         &.{ .rule(3), .rule(1) },
            //         &.{ .rule(4), .rule(2) },
            //         &.{ .rule(3), .rule(3) },
            //         &.{ .rule(4), .rule(4) },
            //     }),
            //     .init(&.{ // 1
            //         &.{ .rule(0), .rule(3) },
            //     }),
            //     .init(&.{ // 2
            //         &.{ .rule(0), .rule(4) },
            //     }),
            //     .init(&.{ // 3
            //         &.{.symbol(.less)},
            //     }),
            //     .init(&.{ // 4
            //         &.{.symbol(.greater)},
            //     }),
            // });

            // cyk_result = try cyk.parse(gpa, tokens, &.{
            //     .init(&.{
            //         &.{ .rule(1), .rule(2) },
            //     }),
            //     .init(&.{
            //         &.{.symbol(.less)},
            //         &.{ .rule(1), .rule(1) },
            //     }),
            //     .init(&.{
            //         &.{.symbol(.greater)},
            //         &.{ .rule(2), .rule(2) },
            //     }),
            // });
        }
        const cyk_time = cyk_timer.lap();
        cyk_data[i] = .{
            .success = cyk_result,
            .iterations = tries,
            .num_tokens = tokens.len,
            .time_ns = cyk_time,
            .n = 0,
        };
        if (!cyk_result) return error.CykParseFailed;
    }
    print("{f}", .{Result.init("CYK", cyk_data)});

    print("\n", .{});

    for (0.., inputs) |i, tokens| {
        print("Running Earley {}\n", .{i + 1});
        var earley_result = false;
        var earley_timer: Timer = try .start();
        for (0..tries) |_| {
            // O(n)
            earley_result = try earley.parse(gpa, tokens, &.{
                .init(&.{
                    &.{ .rule(1) },
                }),
                .init(&.{
                    &.{ .symbol(.less), .rule(1), .symbol(.greater) },
                    &.{ .symbol(.less), .symbol(.greater) },
                }),
            });

            // O(n^2)
            // earley_result = try earley.parse(gpa, tokens, &.{
            //     .init(&.{
            //         &.{.rule(1)},
            //     }),
            //     .init(&.{
            //         &.{ .symbol(.less), .rule(1), .symbol(.less) },
            //         &.{ .symbol(.greater), .rule(1), .symbol(.greater) },
            //         &.{ .symbol(.less), .symbol(.less) },
            //         &.{ .symbol(.greater), .symbol(.greater) },
            //     }),
            // });

            // O(n^2) 2
            // earley_result = try earley.parse(gpa, tokens, &.{
            //     .init(&.{
            //         &.{.rule(1)},
            //     }),
            //     .init(&.{
            //         &.{ .symbol(.less), .rule(1), .symbol(.less) },
            //         &.{ .symbol(.greater), .rule(1), .symbol(.greater) },
            //         &.{ .symbol(.less), .symbol(.less) },
            //         &.{ .symbol(.greater), .symbol(.greater) },
            //     }),
            // });

            // O(n^3)
            // earley_result = try earley.parse(gpa, tokens, &.{
            //     .init(&.{
            //         &.{ .rule(1), .rule(2) },
            //     }),
            //     .init(&.{
            //         &.{.symbol(.less)},
            //         &.{ .rule(1), .rule(1) },
            //     }),
            //     .init(&.{
            //         &.{.symbol(.greater)},
            //         &.{ .rule(2), .rule(2) },
            //     }),
            // });
        }
        const earley_time = earley_timer.lap();
        earley_data[i] = .{
            .success = earley_result,
            .iterations = tries,
            .num_tokens = tokens.len,
            .time_ns = earley_time,
            .n = 0,
        };
        if (!earley_result) return error.EarleyParseFailed;
    }
    print("{f}", .{Result.init("Earley", earley_data)});

    const cyk_f = try std.fs.cwd().createFile("cyk1.json", .{});
    defer cyk_f.close();
    var cyk_w = cyk_f.writer(&.{});
    try cyk_w.interface.print("{f}", .{std.json.fmt(Result.init("CYK", cyk_data), .{ .whitespace = .indent_tab })});
    try cyk_w.interface.flush();

    const earley_f = try std.fs.cwd().createFile("earley1.json", .{});
    defer earley_f.close();
    var earley_w = earley_f.writer(&.{});
    try earley_w.interface.print("{f}", .{std.json.fmt(Result.init("Earley", earley_data), .{ .whitespace = .indent_tab })});
    try earley_w.interface.flush();
}
