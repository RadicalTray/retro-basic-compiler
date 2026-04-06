const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;

pub const Token = struct {
    symbol: Symbol,
    lexeme: []const u8,
    line: u32,

    pub fn init(symbol: Symbol, lexeme: []const u8, line: u32) Token {
        return .{
            .symbol = symbol,
            .lexeme = lexeme,
            .line = line,
        };
    }
};

pub const Symbol = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    eof,

    // 1 char
    equal,
    less,
    greater,
    plus,
    minus,
    newline, // statement separator

    // 2 char
    less_equal,
    greater_equal,

    // multiple char
    // keywords
    print,
    goto,
    stop,
    @"if",

    number: u16, // constants and line numbers are positive integers
    identifier: u16, // one [A-Z] only. warns/errors out multiple char identifier if more than 1 letter
};

pub fn scan(arena: Allocator, source: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = try .initCapacity(arena, 128);
    errdefer tokens.deinit(arena);

    var start: u32 = 0;
    var current: u32 = 0;
    var line: u32 = 1;

    while (current < source.len) : (start = current) {
        const c = source[current];
        current += 1;

        // TODO: make it not stop immediately when an error occurrs
        const symbol: Symbol = switch (c) {
            '=' => .equal,
            '+' => .plus,
            '-' => .minus,
            '\n' => blk: {
                line += 1;
                break :blk .newline;
            },
            '<' => blk: {
                if (peek(source, current) == '=') {
                    current += 1;
                    break :blk .less_equal;
                } else {
                    break :blk .less;
                }
            },
            '>' => blk: {
                if (peek(source, current) == '=') {
                    current += 1;
                    break :blk .greater_equal;
                } else {
                    break :blk .greater;
                }
            },
            '0'...'9' => blk: {
                while ('0' <= peek(source, current) and peek(source, current) <= '9') current += 1;
                break :blk .{ .number = try std.fmt.parseInt(u16, source[start..current], 10) }; // TODO: handle parseInt error
            },
            'A'...'Z' => blk: {
                while ('A' <= peek(source, current) and peek(source, current) <= 'Z') current += 1;
                const lexeme = source[start..current];

                if (lexeme.len == 1) break :blk .{ .identifier = c };
                if (eql(u8, lexeme, "PRINT")) break :blk .print;
                if (eql(u8, lexeme, "GOTO")) break :blk .goto;
                if (eql(u8, lexeme, "STOP")) break :blk .stop;
                if (eql(u8, lexeme, "IF")) break :blk .@"if";
                return error.InvalidIdentifier;
            },
            ' ' => continue,
            else => return error.UnexpectedCharacter,
        };
        try tokens.append(arena, .init(symbol, source[start..current], line));
    }
    try tokens.append(arena, .init(.eof, "", line + 1));

    return try tokens.toOwnedSlice(arena);
}

fn peek(arr: []const u8, idx: u32) u8 {
    if (idx >= arr.len) return 0;
    return arr[idx];
}
