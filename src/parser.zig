const std = @import("std");
const Allocator = std.mem.Allocator;

const scanner = @import("scanner.zig");
const Token = scanner.Token;
const Symbol = scanner.Symbol;

pub fn parse(arena: Allocator, tokens: []const Token) ![]const Line {
    var lines: std.ArrayList(Line) = try .initCapacity(arena, 64);
    errdefer lines.deinit(arena);

    var parser: Parser = .init(arena, tokens);
    while (parser.current < tokens.len) {
        if (try parser.line()) |line| {
            try lines.append(arena, line);
        }
    }

    return try lines.toOwnedSlice(arena);
}

const Parser = struct {
    arena: Allocator,
    tokens: []const Token,
    current: u16 = 0,

    pub fn init(arena: Allocator, tokens: []const Token) Parser {
        return .{
            .arena = arena,
            .tokens = tokens,
        };
    }

    fn line(p: *Parser) !?Line {
        switch (p.peek().symbol) {
            // TODO: check line number here?
            .number => |num| {
                p.current += 1;

                const stmt = try p.statement();

                switch (p.peek().symbol) {
                    .newline, .eof => {
                        p.current += 1;
                        return .{ .line_number = num, .statement = stmt };
                    },
                    else => return error.ExpectedNewline,
                }
            },
            .newline, .eof => {
                p.current += 1;
                return null;
            },
            else => return error.ExpectedLineNumber,
        }
    }

    fn statement(p: *Parser) !Statement {
        switch (p.peek().symbol) {
            .stop => {
                p.current += 1;
                return .stop;
            },
            .goto => {
                p.current += 1;
                return p.goto();
            },
            .print => {
                p.current += 1;
                return p.print();
            },
            .@"if" => {
                p.current += 1;
                return p.@"if"();
            },
            .identifier => |c| {
                p.current += 1;
                return p.assignment(c);
            },
            else => return error.ExpectedStatement,
        }
    }

    fn goto(p: *Parser) !Statement {
        switch (p.peek().symbol) {
            // TODO: also check line number here
            .number => |num| {
                p.current += 1;
                return .{ .goto = num };
            },
            else => return error.ExpectedLineNumber,
        }
    }

    fn print(p: *Parser) !Statement {
        const expr = try p.expression();
        return .{ .print = expr };
    }

    fn @"if"(p: *Parser) !Statement {
        const cond = try p.comparison();
        switch (p.peek().symbol) {
            // TODO: check line number here too
            .number => |num| {
                p.current += 1;
                return .{ .@"if" = .{ .condition = cond, .line_number = num } };
            },
            else => return error.ExpectedLineNumber,
        }
    }

    fn assignment(p: *Parser, identifier: u16) !Statement {
        switch (p.peek().symbol) {
            .equal => {
                p.current += 1;
                const expr = try p.expression();
                return .{ .assignment = .{ .identifier = identifier, .value = expr } };
            },
            else => return error.ExpectedEqual,
        }
    }

    fn comparison(p: *Parser) !Comparison {
        const left = try p.arena.create(Expression);
        left.* = try p.expression();

        const op: Comparison.Op = switch (p.peek().symbol) {
            .less => .less,
            .less_equal => .less_equal,
            .equal => .equal,
            .greater_equal => .greater_equal,
            .greater => .greater,
            else => return error.ExpectedComparisonOperator,
        };
        p.current += 1;

        const right = try p.arena.create(Expression);
        right.* = try p.expression();

        return .{ .op = op, .l = left, .r = right };
    }

    fn expression(p: *Parser) !Expression {
        var expr = try p.value();
        while (true) {
            const op: Expression.Addition.Op =
                switch (p.peek().symbol) {
                    .plus => .plus,
                    .minus => .minus,
                    else => return expr,
                };
            p.current += 1;

            const right = try p.arena.create(Expression);
            right.* = try p.value();

            const old_expr = try p.arena.create(Expression);
            old_expr.* = expr;

            expr = .{ .addition = .{ .op = op, .l = old_expr, .r = right } };
        }
    }

    fn value(p: *Parser) !Expression {
        switch (p.peek().symbol) {
            .identifier => |c| {
                p.current += 1;
                return .{ .identifier = c };
            },
            .number => |n| {
                p.current += 1;
                return .{ .constant = n };
            },
            else => return error.ExpectedIdentifierOrNumber,
        }
    }

    fn peek(p: Parser) Token {
        return p.tokens[p.current];
    }
};

// to cheat for the points, stray lines are ignored
pub const Line = struct {
    line_number: u16,
    statement: Statement,
};

pub const Statement = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    assignment: Assignment,
    @"if": If,
    print: Expression,
    goto: u16,
    stop,

    pub const Assignment = struct {
        identifier: u16,
        value: Expression,
    };

    pub const If = struct {
        condition: Comparison,
        line_number: u16,
    };
};

pub const Comparison = struct {
    op: Op,
    l: *const Expression,
    r: *const Expression,

    pub const Op = enum { less, less_equal, equal, greater_equal, greater };
};

pub const Expression = union(enum) {
    identifier: u16,
    constant: u16,
    addition: Addition,

    pub const Addition = struct {
        op: Op,
        l: *const Expression,
        r: *const Expression,

        pub const Op = enum { plus, minus };
    };
};
