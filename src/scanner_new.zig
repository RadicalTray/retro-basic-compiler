const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;

pub const Symbol = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    eof,

    // 1 char
    less,
    equal,
    greater,
    plus,
    minus,
    semicolon,
    left_paren,
    right_paren,
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    dot,
    amp, // &
    percent,
    star,
    tilde,
    bang, // !

    // 2 char
    equal_equal,
    less_equal,
    greater_equal,

    // keywords
    auto,
    @"break",
    case,
    char,
    @"const",
    @"continue",
    default,
    do,
    double,
    @"else",
    @"enum",
    @"extern",
    float,
    @"for",
    goto,
    @"if",
    @"inline",
    int,
    long,
    register,
    restrict,
    @"return",
    short,
    signed,
    sizeof,
    static,
    @"struct",
    @"switch",
    typedef,
    @"union",
    unsigned,
    void,
    @"volatile",
    @"while",
    _Alignas,
    _Alignof,
    _Atomic,
    _Bool,
    _Complex,
    _Generic,
    _Imaginary,
    _Noreturn,
    _Static_assert,
    _Thread_local,

    // values
    identifier,
    constant,
    string,
};

pub fn scan(arena: Allocator, source: []const u8) ![]Symbol {
    var tokens: std.ArrayList(Symbol) = try .initCapacity(arena, 128);
    errdefer tokens.deinit(arena);

    var start: u32 = 0;
    var current: u32 = 0;
    var line: u32 = 1;

    while (current < source.len) : (start = current) {
        const c = source[current];
        current += 1;

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

                if (lexeme.len == 1) break :blk .{ .identifier = c - 'A' + 1 };
                if (eql(u8, lexeme, "PRINT")) break :blk .print;
                if (eql(u8, lexeme, "GOTO")) break :blk .goto;
                if (eql(u8, lexeme, "STOP")) break :blk .stop;
                if (eql(u8, lexeme, "IF")) break :blk .@"if";
                return error.InvalidIdentifier;
            },
            ' ', '\t', '\r' => continue,
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
