const std = @import("std");
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const Line = parser.Line;
const Expression = parser.Expression;
const Addition = Expression.Addition;
const Comparison = parser.Comparison;

pub fn genBCode(arena: Allocator, lines: []const Line) ![]BCode {
    var codes: std.ArrayList(BCode) = try .initCapacity(arena, lines.len * 4);
    errdefer codes.deinit(arena);
    for (lines) |line| {
        try codes.append(arena, .initLine(line.line_number));
        switch (line.statement) {
            .assignment => |x| {
                try codes.appendSlice(arena, &.{ .initId(x.identifier), .initOp(.equal) });
                try genExpressionBCode(arena, &codes, &x.value);
            },
            .@"if" => |x| {
                try codes.append(arena, .initIf());
                try genExpressionBCode(arena, &codes, x.condition.l);
                try codes.append(arena, .initOp(try .fromComparison(x.condition.op)));
                try genExpressionBCode(arena, &codes, x.condition.r);
                try codes.append(arena, .initGoto(x.line_number));
            },
            .goto => |x| {
                try codes.append(arena, .initGoto(x));
            },
            .print => |x| {
                try codes.append(arena, .initPrint());
                try genExpressionBCode(arena, &codes, &x);
            },
            .stop => {
                try codes.append(arena, .initStop());
            },
        }
    }
    try codes.append(arena, .initEof());

    return try codes.toOwnedSlice(arena);
}

fn genExpressionBCode(gpa: Allocator, codes: *std.ArrayList(BCode), expression: *const Expression) !void {
    switch (expression.*) {
        .identifier => |c| try codes.append(gpa, .initId(c)),
        .constant => |n| try codes.append(gpa, .initConst(n)),
        .addition => |x| {
            try genExpressionBCode(gpa, codes, x.l);
            try codes.append(gpa, .initOp(try .fromAddition(x.op)));
            try genExpressionBCode(gpa, codes, x.r);
        },
    }
}

pub const BCode = union(Coding) {
    // NOTE: in their example, only one 0 (u16?) was used in eof, here this uses two 0's.
    eof: u16,

    line: u16,
    id: u16,
    @"const": u16,
    @"if": u16,
    goto: u16,
    print: u16,
    stop: u16,
    op: Op,

    pub fn initEof() BCode {
        return .{ .eof = 0 };
    }

    pub fn initLine(line_number: u16) BCode {
        return .{ .line = line_number };
    }

    pub fn initId(char: u16) BCode {
        return .{ .id = char - 'A' + 1 }; // A = 1
    }

    pub fn initConst(number: u16) BCode {
        return .{ .@"const" = number };
    }

    pub fn initIf() BCode {
        return .{ .@"if" = 0 };
    }

    pub fn initGoto(line_number: u16) BCode {
        return .{ .goto = line_number };
    }

    pub fn initPrint() BCode {
        return .{ .print = 0 };
    }

    pub fn initStop() BCode {
        return .{ .stop = 0 };
    }

    pub fn initOp(op: Op) BCode {
        return .{ .op = op };
    }

    pub fn toInt(code: BCode) [2]u16 {
        const tag: u16 = @intFromEnum(code);
        const value: u16 = switch (code) {
            .line,
            .id,
            .@"const",
            .@"if",
            .goto,
            .print,
            .stop,
            .eof,
            => |x| x,
            .op => |x| @intFromEnum(x),
        };
        return .{ tag, value };
    }
};

pub const Coding = enum(u16) {
    eof = 0,
    line = 10,
    id = 11,
    @"const" = 12,
    @"if" = 13,
    goto = 14,
    print = 15,
    stop = 16,
    op = 17,
};

pub const Op = enum(u16) {
    plus = 1,
    minus = 2,
    less = 3,
    equal = 4,

    pub fn fromAddition(op: Addition.Op) !Op {
        return switch (op) {
            .plus => .plus,
            .minus => .minus,
        };
    }

    pub fn fromComparison(op: Comparison.Op) !Op {
        return switch (op) {
            .less => .less,
            .less_equal => error.OperatorNotSupported,
            .equal => .equal,
            .greater_equal => error.OperatorNotSupported,
            .greater => error.OperatorNotSupported,
        };
    }
};
