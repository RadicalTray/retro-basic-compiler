const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const scanner = @import("scanner.zig");
const Token = scanner.Token;

const Rule = @import("Rule.zig");

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

// TODO: memory very bad
pub fn parse(gpa: Allocator, tokens: []const Token, rules: []const Rule) !bool {
    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var table: ParsingTable = try .init(arena, tokens.len, rules.len);
    for (0.., tokens) |s, token|
        for (0.., rules) |v, rule|
            for (rule.productions) |prod|
                switch (prod[0]) {
                    .terminal => |symbol| if (symbol == token.symbol) table.set(0, s, v, true),
                    .nonterminal => {},
                };

    for (2..(tokens.len + 1)) |l| // length of span
        for (1..(tokens.len - l + 2)) |s| // start of span
            for (1..l) |p| // partition of span
                for (0.., rules) |a, rule|
                    for (rule.productions) |prod|
                        switch (prod[0]) {
                            .terminal => {},
                            .nonterminal => {
                                const b = prod[0].nonterminal;
                                const c = prod[1].nonterminal;
                                if (table.get(p - 1, s - 1, b) and table.get(l - p - 1, s + p - 1, c)) {
                                    table.set(l - 1, s - 1, a, true);
                                }
                            },
                        };

    // print("N = {}\n", .{table.list.items.len});

    return table.get(tokens.len - 1, 0, 0);
}
