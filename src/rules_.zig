// goal:
//  - rule able refer to each other with numbers

const std = @import("std");
const assert = std.debug.assert;
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;

const scanner = @import("scanner.zig");
const Symbol = scanner.Symbol;

const NamedProduction = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    terminal: ?Symbol.Tag,
    nonterminal: []const []const u8,

    pub fn initTerm(symbol: Symbol.Tag) NamedProduction {
        return .{ .terminal = symbol };
    }

    pub fn initNonterm(rules: []const []const u8) NamedProduction {
        return .{ .nonterminal = rules };
    }
};

pub const NamedRule = struct {
    name: []const u8, // who cares about scalability amirite?
    productions: []const NamedProduction,

    pub fn init(name: []const u8, productions: []const NamedProduction) !NamedRule {
        return .{ .name = name, .productions = productions };
    }
};

// TODO: check referenced rules exist.
// fn main() {}

// Assumes rules[0] is the start rule.
fn start(gpa: Allocator, rules: []const NamedRule) ![]NamedRule {
    const start_rule_name = "S0";
    for (rules) |r| if (std.mem.eql(u8, r.name, start_rule_name)) return error.ConflictingStartRuleNames;

    const start_rule: NamedRule = .{
        .name = try gpa.dupe(u8, start_rule_name),
        .productions = try gpa.alloc(NamedProduction, rules[0].productions),
    };
    for (0.., rules[0].productions) |i, p| {
        switch (p) {
            .terminal => |x| start_rule.productions[i] = .initTerm(x),
            .nonterminal => |x| {
                const y = try gpa.alloc([]u8, x.len);
                for (0.., x) |j, s| y[j] = try gpa.dupe(u8, s);
                start_rule.productions[i] = .initNonterm(y);
            },
        }
    }

    const new_rules: std.ArrayList(NamedRule) = .empty;
    try new_rules.append(gpa, start_rule);
    try new_rules.appendSlice(gpa, rules);
    return try new_rules.toOwnedSlice(gpa);
}

fn term(gpa: Allocator, rules: []const NamedRule) []NamedRule {
    _ = gpa;
    _ = rules;
    @compileError("Why tf are you using this?");
}

fn bin(gpa: Allocator, rules: []const NamedRule) ![]NamedRule {
    for (rules) |r| for (r.name) |c| if ('0' <= c and c <= '9') return error.RuleNameContainsDigits;

    const new_rules: std.ArrayList(NamedRule) = .empty;
    for (rules) |rule| {
        for (rule.productions) |production| {
            var rule_idx: usize = 1;
            var new_prods: std.ArrayList(NamedProduction) = .empty;
            switch (production) {
                .terminal => try new_prods.append(gpa, production),
                // x -> a b | a b c d | "x" | p q r s t
                //
                // x -> a b | a x_1 | "x" | p x_3
                // x_1 -> b x_2
                // x_2 -> c d
                // x_3 -> q x_4
                // x_4 -> r x_5
                // x_5 -> s t
                .nonterminal => |x| {
                    if (x.len > 2) {
                        try new_prods.append(gpa, .initNonterm(&.{ x[0], rule.name ++ rule_idx }));
                        for (1..(x.len - 1)) |i| {
                            if (i + 1 < x.len - 1) {
                                try new_rules.append(gpa, .init(rule.name ++ rule_idx, .initNonterm(&.{ x[i], rule.name ++ (rule_idx + 1) })));
                            } else {
                                try new_rules.append(gpa, .init(rule.name ++ rule_idx, .initNonterm(&.{ x[i], x[i + 1] })));
                            }
                            rule_idx += 1;
                        }
                    } else {
                        const y = try gpa.alloc([]u8, x.len);
                        for (0.., x) |j, s| y[j] = try gpa.dupe(u8, s);
                        try new_prods.append(gpa, y);
                    }
                },
            }
        }
    }
    return try new_rules.toOwnedSlice(gpa);
}

fn del(gpa: Allocator, rules: []const NamedRule) []NamedRule {
    // S0 → AbB | C
    // B → AA | AC
    // C → b | c
    // A → a | ε
    //
    // S0 → AbB | Ab | bB | b | C
    // B → AA | A | AC | C
    // C → b | c
    // A → a
    const new_rules: std.ArrayList(NamedRule) = .empty;
    for (rules) |rule| {
        var new_prods: std.ArrayList(NamedProduction) = .empty;
        for (rule.productions) |production| {
            switch (production) {
                .terminal => |x| if (x) |sym| try new_prods.append(gpa, .initTerm(sym)),
                .nonterminal => |x| try new_prods.appendSlice(gpa, try del_1(gpa, rules, x)),
            }
        }
    }
    return try new_rules.toOwnedSlice(gpa);
}

// S0 → AbB | Ab | bB | b
// B → AA | A | AC | C
// A → a | ε
fn del_1(gpa: Allocator, rules: []const NamedRule, rule_names: []const []const u8) []NamedProduction {
    const new_prods: std.ArrayList(NamedProduction) = .empty;
    for (rule_names) |r| {
        if (nullable(r, rules)) {
            // produce yes
            // produce no
        } else {
            // produce yes
        }
    }
    return try new_prods.toOwnedSlice(gpa);
}

fn del_2(gpa: Allocator) !void {}

// O(n^???)
fn nullable(rule_name: []const u8, rules: []const NamedRule) bool {
    const rule = blk: {
        for (rules) |r| if (eql(u8, r.name, rule_name)) break :blk r;
        return error.RuleDoesNotExist;
    };
    blk: for (rule.productions) |p| {
        switch (p) {
            .nonterminal => |x| {
                for (x) |n| if (!nullable(n, rules)) continue :blk;
                return true;
            },
            .terminal => |x| if (x == null) return true,
        }
    }
    return false;
}

fn unit(gpa: Allocator, rules: []const NamedRule) []NamedRule {
    const new_rules: std.ArrayList(NamedRule) = .empty;
    for (rules) |rule| {
        var new_prods: std.ArrayList(NamedProduction) = .empty;
        for (rule.productions) |prod| {
            switch (prod) {
                .nonterminal => |x| {
                    if (x.len == 1) {
                        // TODO: handle rule is also unit rule
                        for (rules) |r| {
                            if (std.mem.eql(u8, r.name, x[0])) {
                                try new_prods.appendSlice(gpa, r.productions); // BUG: this isn't copied.
                            }
                        }
                        // TODO: put unreachable here
                    } else {
                        try new_prods.append(gpa, .initNonterm(x));
                    }
                },
                .terminal => |x| try new_prods.append(gpa, .initTerm(x)),
            }
        }
    }
    return try new_rules.toOwnedSlice(gpa);
}
