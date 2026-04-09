// TODO: Rule generator

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const scanner = @import("scanner.zig");
const Token = scanner.Token;
const Symbol = scanner.Symbol.Tag;

const Word = union(enum) {
    terminal: Symbol,
    nonterminal: usize,

    fn symbol(sym: Symbol) Word {
        return .{ .terminal = sym };
    }

    fn rule(idx: usize) Word {
        return .{ .nonterminal = idx };
    }

    fn equal(lhs: Word, rhs: Word) bool {
        if (lhs == .terminal and rhs == .terminal) return lhs.terminal == rhs.terminal;
        if (lhs == .nonterminal and rhs == .nonterminal) return lhs.nonterminal == rhs.nonterminal;
        return false;
    }
};

pub const Production = []const Word;

const Rule = struct {
    productions: []const Production,

    pub fn init(productions: []const Production) Rule {
        return .{ .productions = productions };
    }
};

const ParsingTable = struct {
    // TODO: consider BitSet
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

pub fn parse(arena: Allocator, tokens: []Token) !bool {
    const rules = [_]Rule{
        // START RULE FOR CYK'S PARSER
        .init(&.{
            &.{ .rule(2), .rule(3) },
        }),

        .init(&.{
            &.{ .rule(2), .rule(3) },
        }),
        .init(&.{
            &.{.symbol(.minus)},
            &.{ .rule(2), .rule(2) },
        }),
        .init(&.{
            &.{.symbol(.plus)},
            &.{ .rule(3), .rule(3) },
        }),
    };
    var table: ParsingTable = try .init(arena, tokens.len, rules.len);

    for (0.., tokens) |s, token| {
        for (0.., rules) |v, rule| {
            for (rule.productions) |prod| {
                switch (prod[0]) {
                    .terminal => |symbol| if (symbol == token.symbol) table.set(0, s, v, true),
                    .nonterminal => {},
                }
            }
        }
    }

    for (2..(tokens.len + 1)) |l| { // length of span
        for (1..(tokens.len - l + 2)) |s| { // start of span
            for (1..l) |p| { // partition of span
                for (0.., rules) |a, rule| {
                    for (rule.productions) |prod| {
                        switch (prod[0]) {
                            .terminal => {},
                            .nonterminal => {
                                const b = prod[0].nonterminal;
                                const c = prod[1].nonterminal;
                                if (table.get(p - 1, s - 1, b) and table.get(l - p - 1, s + p - 1, c)) {
                                    table.set(l - 1, s - 1, a, true);
                                    // back.append(l, s, a, &.{ p, b, c });
                                }
                            },
                        }
                    }
                }
            }
        }
    }

    for (0..tokens.len) |i| {
        for (0..tokens.len) |j| {
            std.debug.print("({}, {})[", .{ i, j });
            for (0..rules.len) |k| {
                if (table.get(i, j, k)) std.debug.print("{}", .{k});
                if (k + 1 < rules.len and table.get(i, j, k + 1)) std.debug.print(", ", .{});
            }
            std.debug.print("] ", .{});
        }
        std.debug.print("\n", .{});
    }

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
