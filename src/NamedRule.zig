const std = @import("std");
const Allocator = std.mem.Allocator;

const scanner = @import("scanner.zig");
const Symbol = scanner.Symbol.Tag;

const Rule = @import("Rule.zig");
const Production = Rule.Production;
const Word = Rule.Word;

const NamedRule = @This();

// TODO: rule manager?
pub fn genUnnamedRules(arena: Allocator, named_rules: []const NamedRule) ![]const Rule {
    const map: std.StringHashMapUnmanaged(usize) = .empty;
    defer map.deinit(arena);
    for (0.., named_rules) |i, named_rule| {
        const result = try map.getOrPut(arena, named_rule.name);
        if (result.found_existing) return error.DuplicateRuleNames;
        result.value_ptr.* = i;
    }

    const new_rules = try arena.alloc(Rule, named_rules.len);
    for (0.., named_rules) |i, named_rule| {
        const new_prods = try arena.alloc(Production, named_rule.productions.len);
        for (0.., named_rule.productions) |j, named_production| {
            new_prods[j] = try arena.alloc(Word, named_production.len);
            for (0.., named_production) |k, named_word| {
                new_prods[j][k] = switch (named_word) {
                    .terminal => |s| .symbol(s),
                    .nonterminal => |n| .rule(try map.get(n)),
                };
            }
        }
        new_rules[i] = .init(new_prods);
    }

    return try new_rules.toOwnedSlice(arena);
}

name: []const u8,
productions: []const NamedProduction,

pub fn init(productions: []const NamedProduction) NamedRule {
    return .{ .productions = productions };
}

pub const NamedProduction = []const NamedWord;

pub const NamedWord = union(enum) {
    terminal: Symbol,
    nonterminal: []const u8,

    pub fn symbol(sym: Symbol) NamedWord {
        return .{ .terminal = sym };
    }

    pub fn rule(name: []const u8) NamedWord {
        return .{ .nonterminal = name };
    }
};
