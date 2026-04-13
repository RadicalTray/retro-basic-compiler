const std = @import("std");
const print = std.debug.print;
const Timer = std.time.Timer;

const scanner = @import("../scanner.zig");
const Token = scanner.Token;

const parser_cyk = @import("../parser_cyk.zig");
const parser_earley = @import("../parser_earley.zig");

const Result = @import("Result.zig");
const Data = Result.Data;

pub fn run() !void {
    const gpa = std.heap.smp_allocator;
    const n = 10;
    const pairs = 100;

    var inputs: [n][]Token = undefined;
    for (0.., &inputs) |i, *x| {
        var y = try gpa.alloc(Token, (i + 1) * pairs * 2);
        for (0..(i + 1) * pairs) |j| y[j] = .init(.less, "", 0);
        for ((i + 1) * pairs..(i + 1) * pairs * 2) |j| y[j] = .init(.greater, "", 0);
        x.* = y;
    }

    const cyk_data = try gpa.alloc(Data, inputs.len);
    defer gpa.free(cyk_data);
    const earley_data = try gpa.alloc(Data, inputs.len);
    defer gpa.free(earley_data);

    const tries = 10;
    for (0.., inputs) |i, tokens| {
        print("Running CYK {}\n", .{i});

        var cyk_result = false;
        var cyk_timer: Timer = try .start();
        for (0..tries) |_| {
            cyk_result = try parser_cyk.parse(gpa, tokens, &.{
                // START RULE FOR CYK'S PARSER
                .init(&.{
                    &.{ .rule(2), .rule(3) },
                }),

                .init(&.{
                    &.{ .rule(2), .rule(3) },
                }),
                .init(&.{
                    &.{.symbol(.less)},
                    &.{ .rule(2), .rule(2) },
                }),
                .init(&.{
                    &.{.symbol(.greater)},
                    &.{ .rule(3), .rule(3) },
                }),
            });
        }
        const cyk_time = cyk_timer.lap();
        cyk_data[i] = .init(cyk_result, tries, tokens.len, cyk_time);

        print("Running Earley {}\n", .{i});

        var earley_result = false;
        var earley_timer: Timer = try .start();
        for (0..tries) |_| {
            earley_result = try parser_earley.parse(gpa, tokens, &.{
                // START RULE FOR EARLEY'S PARSER
                .init(&.{
                    &.{.rule(1)},
                }),

                .init(&.{
                    &.{ .rule(2), .rule(3) },
                }),
                .init(&.{
                    &.{.symbol(.less)},
                    &.{ .rule(2), .rule(2) },
                }),
                .init(&.{
                    &.{.symbol(.greater)},
                    &.{ .rule(3), .rule(3) },
                }),
            });
        }
        const earley_time = earley_timer.lap();
        earley_data[i] = .init(earley_result, tries, tokens.len, earley_time);
    }

    print("{f}", .{Result.init("CYK", cyk_data)});
    print("\n", .{});
    print("{f}", .{Result.init("Earley", earley_data)});
}

// DCFG 00001111
// UNAMBIGUOUS S -> A + A, A -> 0 | 1
// AMBIGUOUS A -> A + A | A - A | a
