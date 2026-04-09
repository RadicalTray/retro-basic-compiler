const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const assert = std.debug.assert;

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

// ohhh so this basically caches where its been (dynamic programming)
// consider not using usize
const StateSet = struct {
    rule: usize, // TODO: needs to convert NamedRule to Rule
    production: usize, // TODO: needs to convert NamedRule to Rule
    pos: usize, // position of production, 0 is before the first symbol, len is after the last symbol
    input_pos: usize, // position of input

    pub fn init(rule: usize, production: usize, pos: usize, input_pos: usize) StateSet {
        return .{ .rule = rule, .production = production, .pos = pos, .input_pos = input_pos };
    }

    pub fn finished(s: StateSet, rules: []const Rule) bool {
        return s.pos == s.getProduction(rules).len;
    }

    pub fn nextWord(s: StateSet, rules: []const Rule) Word {
        return s.getProduction(rules)[s.pos];
    }

    pub fn getRule(s: StateSet) Word {
        return .rule(s.rule);
    }

    pub fn getProduction(s: StateSet, rules: []const Rule) Production {
        return rules[s.rule].productions[s.production];
    }
};

pub fn parse(arena: Allocator, tokens: []Token) !bool {
    const rules = [_]Rule{
        // START RULE FOR EARLEY'S PARSER
        .init(&.{
            &.{.rule(1)},
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

    const start_state: StateSet = .init(0, 0, 0, 0);
    const end_state: StateSet = .init(0, 0, rules[0].productions[0].len, 0);

    const S = try arena.alloc(std.AutoArrayHashMapUnmanaged(StateSet, void), tokens.len + 1);
    for (0..S.len) |i| S[i] = .empty;
    try S[0].putNoClobber(arena, start_state, {});

    for (0..tokens.len + 1) |k| {
        var i: usize = 0;
        var states = S[k].keys();
        while (i < states.len) {
            const state = states[i];
            if (state.finished(&rules)) {
                // COMPLETER
                for (S[state.input_pos].keys()) |curr_state| {
                    if (!curr_state.finished(&rules) and
                        curr_state.nextWord(&rules).equal(state.getRule()))
                    {
                        var next_state = curr_state;
                        next_state.pos += 1;
                        _ = try S[k].getOrPut(arena, next_state);
                    }
                }
            } else {
                switch (state.nextWord(&rules)) {
                    .terminal => |next_symbol| {
                        // SCANNER
                        if (state.input_pos < tokens.len and next_symbol == tokens[k].symbol) {
                            var next_state = state;
                            next_state.pos += 1;
                            _ = try S[k + 1].getOrPut(arena, next_state);
                        }
                    },
                    .nonterminal => |next_rule| {
                        // PREDICTOR
                        for (0..rules[next_rule].productions.len) |prod_idx| {
                            _ = try S[k].getOrPut(arena, .init(next_rule, prod_idx, 0, k));
                        }
                    },
                }
            }

            i += 1;
            states = S[k].keys();
        }
    }

    return S[tokens.len].contains(end_state);
}
