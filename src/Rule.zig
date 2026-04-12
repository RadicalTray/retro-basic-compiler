const std = @import("std");

const scanner = @import("scanner.zig");
const Symbol = scanner.Symbol.Tag;

const Rule = @This();

productions: []const Production,

pub fn init(productions: []const Production) Rule {
    return .{ .productions = productions };
}

pub const Production = []const Word;

pub const Word = union(enum) {
    terminal: Symbol,
    nonterminal: usize,

    pub fn symbol(sym: Symbol) Word {
        return .{ .terminal = sym };
    }

    pub fn rule(idx: usize) Word {
        return .{ .nonterminal = idx };
    }

    pub fn equal(lhs: Word, rhs: Word) bool {
        if (lhs == .terminal and rhs == .terminal) return lhs.terminal == rhs.terminal;
        if (lhs == .nonterminal and rhs == .nonterminal) return lhs.nonterminal == rhs.nonterminal;
        return false;
    }
};
