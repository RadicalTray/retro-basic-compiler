const std = @import("std");
const Allocator = std.mem.Allocator;

const scanner = @import("scanner.zig");
const Token = scanner.Token;

const Rule = @import("Rule.zig");
const Word = Rule.Word;
const Production = Rule.Production;

// ohhh so this basically caches where its been (dynamic programming)
const StateSet = struct {
    rule: u8,
    production: u8,
    pos: u8, // position of production, 0 is before the first symbol, len is after the last symbol
    input_pos: u32, // position of input

    pub fn init(rule: u8, production: u8, pos: u8, input_pos: u32) StateSet {
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

pub fn parse(gpa: Allocator, tokens: []const Token, rules: []const Rule) !bool {
    const start_state: StateSet = .init(0, 0, 0, 0);
    const end_state: StateSet = .init(0, 0, @intCast(rules[0].productions[0].len), 0);

    var arena_allocator: std.heap.ArenaAllocator = .init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const Set = std.AutoArrayHashMapUnmanaged(StateSet, void);
    const S = try arena.alloc(Set, tokens.len + 1);
    for (S) |*s| {
        s.* = .empty;
        try s.ensureUnusedCapacity(arena, 256);
    }
    try S[0].putNoClobber(arena, start_state, {});

    for (0..tokens.len + 1) |k| {
        var i: usize = 0;
        var states = S[k].keys();
        while (i < states.len) : ({
            i += 1;
            states = S[k].keys();
        }) {
            const state = states[i];
            if (state.finished(rules)) {
                // COMPLETER
                var j: usize = 0;
                var states_input_pos = S[state.input_pos].keys();
                while (j < states_input_pos.len) : ({
                    j += 1;
                    states_input_pos = S[state.input_pos].keys();
                }) {
                    const curr_state = states_input_pos[j];
                    if (!curr_state.finished(rules) and
                        curr_state.nextWord(rules).equal(state.getRule()))
                    {
                        var next_state = curr_state;
                        next_state.pos += 1;
                        _ = try S[k].getOrPut(arena, next_state);
                    }
                }
            } else {
                switch (state.nextWord(rules)) {
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
                            _ = try S[k].getOrPut(arena, .init(@intCast(next_rule), @intCast(prod_idx), 0, @intCast(k)));
                        }
                    },
                }
            }
        }
    }

    // std.debug.print("S = ", .{});
    // for (0..S.len - 1) |i| std.debug.print("{}, ", .{S[i].keys().len});
    // std.debug.print("{}\n", .{S[S.len - 1].keys().len});
    //
    // var N: usize = 0;
    // for (S) |s| N += s.keys().len;
    // std.debug.print("N = {}\n", .{N});
    // std.debug.print("N * Stateset = {}\n", .{N * @sizeOf(StateSet)});

    return S[tokens.len].contains(end_state);
}
