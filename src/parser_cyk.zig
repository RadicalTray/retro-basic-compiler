// TODO: Rule generator

const std = @import("std");
const Allocator = std.mem.Allocator;

const scanner = @import("scanner.zig");
const Token = scanner.Token;
const Symbol = scanner.Symbol;

pub const SyntaxNode = union(enum) {
    const Tag = std.meta.Tag(@This());
};

const ParsingTable = struct {
    list: std.ArrayList(bool),
    input_length: usize,
    rule_count: usize,

    pub fn init(gpa: Allocator, input_length: usize, rule_count: usize) !ParsingTable {
        var list: std.ArrayList(bool) = try .initCapacity(gpa, 0);
        errdefer list.deinit(gpa);

        try list.resize(gpa, input_length * input_length * rule_count);
        for (list.items) |*x| x.* = false;

        return .{
            .list = list,
            .input_length = input_length,
            .rule_count = rule_count,
        };
    }

    pub fn deinit(p: *ParsingTable, gpa: Allocator) void {
        p.list.deinit(gpa);
    }

    pub fn get(p: ParsingTable, n1: usize, n2: usize, r: usize) bool {
        return p.list.items[p.getIdx(n1, n2, r)];
    }

    pub fn set(p: *ParsingTable, n1: usize, n2: usize, r: usize, value: bool) void {
        p.list.items[p.getIdx(n1, n2, r)] = value;
    }

    fn getIdx(p: ParsingTable, n1: usize, n2: usize, r: usize) usize {
        return n1 * p.input_length * p.rule_count + n2 * p.rule_count + r;
    }
};

const Rule = struct {
    productions: std.ArrayList(Production),

    pub fn init(gpa: Allocator, productions: []const Production) !Rule {
        var prod: std.ArrayList(Production) = try .initCapacity(gpa, productions.len);
        for (productions) |p| try prod.append(gpa, p);
        return .{
            .productions = prod,
        };
    }
};

const Production = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    terminal: Symbol.Tag,
    nonterminal: Nonterminal,

    pub const Nonterminal = struct {
        left: usize,
        right: usize,
    };
};

pub fn parse(arena: Allocator, tokens: []Token) !bool {
    const rules = [_]Rule{
        // 0 start:
        //     | line line
        //     | number line_1
        try .init(arena, &.{
            .{ .nonterminal = .{ .left = 1, .right = 1 } },
            .{ .nonterminal = .{ .left = 14, .right = 2 } },
        }),
        // 1 line:
        //    | line line
        //    | number line_1
        try .init(arena, &.{
            .{ .nonterminal = .{ .left = 1, .right = 1 } },
            .{ .nonterminal = .{ .left = 14, .right = 2 } },
        }),
        // 2 line_1: statement newline
        try .init(arena, &.{.{ .nonterminal = .{ .left = 3, .right = 15 } }}),
        // 3 statement:
        //         | id assignment_1
        //         | if if_statement_1
        //         | print id
        //         | goto number
        //         | stop
        try .init(arena, &.{
            .{ .nonterminal = .{ .left = 13, .right = 4 } },
            .{ .nonterminal = .{ .left = 17, .right = 7 } },
            .{ .nonterminal = .{ .left = 18, .right = 13 } },
            .{ .nonterminal = .{ .left = 19, .right = 14 } },
            .{ .terminal = .stop },
        }),
        // 4 assignment_1: equal expression
        try .init(arena, &.{.{ .nonterminal = .{ .left = 16, .right = 5 } }}),
        // 5 expression: value expression_1
        try .init(arena, &.{.{ .nonterminal = .{ .left = 10, .right = 6 } }}),
        // 6 expression_1: add_op value
        try .init(arena, &.{.{ .nonterminal = .{ .left = 11, .right = 10 } }}),
        // 7 if_statement_1: condition number
        try .init(arena, &.{.{ .nonterminal = .{ .left = 8, .right = 14 } }}),
        // 8 condition: value condition_1
        try .init(arena, &.{.{ .nonterminal = .{ .left = 10, .right = 9 } }}),
        // 9 condition_1: cmp_op value
        try .init(arena, &.{.{ .nonterminal = .{ .left = 12, .right = 10 } }}),
        // 10 value:
        //     | id
        //     | number
        try .init(arena, &.{
            .{ .terminal = .identifier },
            .{ .terminal = .number },
        }),
        // 11 add_op:
        //      | plus
        //      | minus
        try .init(arena, &.{
            .{ .terminal = .plus },
            .{ .terminal = .minus },
        }),
        // 12 cmp_op:
        //      | less
        //      | less_equal
        //      | greater
        //      | greater_equal
        //      | equal
        try .init(arena, &.{
            .{ .terminal = .less },
            .{ .terminal = .less_equal },
            .{ .terminal = .greater },
            .{ .terminal = .greater_equal },
            .{ .terminal = .equal },
        }),
        // 13 id
        try .init(arena, &.{.{ .terminal = .identifier }}),
        // 14 number
        try .init(arena, &.{.{ .terminal = .number }}),
        // 15 newline
        try .init(arena, &.{.{ .terminal = .newline }}),
        // 16 equal
        try .init(arena, &.{.{ .terminal = .equal }}),
        // 17 if
        try .init(arena, &.{.{ .terminal = .@"if" }}),
        // 18 print
        try .init(arena, &.{.{ .terminal = .print }}),
        // 19 goto
        try .init(arena, &.{.{ .terminal = .goto }}),
    };
    var table: ParsingTable = try .init(arena, tokens.len, rules.len);

    for (0.., tokens) |s, token|
        for (0.., rules) |v, rule|
            for (rule.productions.items) |prod|
                switch (prod) {
                    .terminal => |symbol| if (symbol == token.symbol) table.set(0, s, v, true),
                    else => {},
                };

    for (1..tokens.len) |l| // length of span
        for (0..(tokens.len - l + 1)) |s| // start of span
            for (0..(l - 1)) |p| // partition of span
                for (0.., rules) |a, rule|
                    for (rule.productions.items) |prod|
                        switch (prod) {
                            .nonterminal => |x| {
                                const b = x.left;
                                const c = x.right;
                                if (table.get(p, s, b) and table.get(l - p, s + p, c)) {
                                    table.set(l, s, a, true);
                                    // back.append(l, s, a, &.{ p, b, c });
                                }
                            },
                            else => {},
                        };

    std.debug.print("what\n", .{});

    return table.get(tokens.len - 1, 0, 0);
}

// CNF
// start: line line
//    | number line_1
//
// line: line line
//    | number line_1
// line_1: statement newline
//
// statement:
//         | id assignment_1
//         | if if_statement_1
//         | print id
//         | goto number
//         | stop
//
// assignment_1: equal expression
// expression: value expression_1
// expression_1: add_op value
//
// if_statement_1: condition number
// condition: value condition_1
// condition_1: cmp_op value
//
// value:
//     | id
//     | number
//
// add_op:
//      | plus
//      | minus
//
// cmp_op:
//      | less
//      | less_equal
//      | greater
//      | greater_equal
//      | equal
