const std = @import("std");

const Scanner = struct {
    begin: [*]const u8,
    end: [*]const u8,

    const Self = @This();
    fn backup(this: Self) [*]const u8 {
        return this.begin;
    }
    fn restore(this: *Self, backedUp: [*]const u8) void {
        this.begin = backedUp;
    }
    fn back(this: *Self) void {
        this.begin -= 1;
    }
    fn since(this: Self, backedUp: [*]const u8) []const u8 {
        return backedUp[0..(@intFromPtr(this.begin)-@intFromPtr(backedUp))];
    }
    fn next(this: *Self) ?u8 {
        if(@intFromPtr(this.begin) >= @intFromPtr(this.end))
            return null;
        defer this.begin += 1;
        return this.begin[0];
    }
    fn of(input: []const u8) Self {
        return Self {
            .begin = input.ptr,
            .end = input.ptr + input.len,
        };
    }
};

const ParsingErrors = error {
    ExpectedOpenParen,
    ExpectedCloseParen,
};

fn term(scanner: *Scanner) ParsingErrors!f64 {
    const backup = scanner.backup();
    while (scanner.next()) |val| {
        switch (val) {
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
            '.' => {},
            else => {
                scanner.back();
                break;
            },
        }
    }
    return std.fmt.parseFloat(f64, scanner.since(backup)) catch {
        scanner.restore(backup);
        if(scanner.next() != '(') return error.ExpectedOpenParen;
        const res = try sum(scanner);
        if(scanner.next() != ')') return error.ExpectedCloseParen;
        return res;
    };
}

fn mul(scanner: *Scanner) !f64 {
    var res = try term(scanner);
    while(scanner.next()) |ch| {
        switch(ch) {
            '*' => res = res * try term(scanner),
            '/' => res = res / try term(scanner),
            else => {
                scanner.back();
                return res;
            },
        }
    }
    return res;
}

fn sum(scanner: *Scanner) !f64 {
    var res = try mul(scanner);
    while(scanner.next()) |ch| {
        switch(ch) {
            '+' => res = res + try mul(scanner),
            '-' => res = res - try mul(scanner),
            else => {
                scanner.back();
                return res;
            },
        }
    }
    return res;
}

fn parse(input: []const u8) !f64 {
    var scanner = Scanner.of(input);
    return try sum(&scanner);
}

pub fn main() !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    defer bw.flush() catch {};
    const stdout = bw.writer();
    const stdin = std.io.getStdIn().reader();
    try stdout.writeAll("Welcome to simple calculator.\nType `exit` to exit.\n");
    try bw.flush();
    while(true) {
        var buf: [256]u8 = undefined;
        const input = std.mem.trimRight(u8, try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse return error.ReadFailed, "\n\r\t");
        if(std.mem.eql(u8, input, "exit"))
            return;
        const res = parse(input) catch |err| {
            try stdout.print("{}{c}", .{ err, '\n' });
            try bw.flush();
            continue;
        };
        try stdout.print("{d}{c}", .{ res, '\n'});
        try bw.flush();
    }
}

test "plus" {
    try std.testing.expectEqual(@as(f64, 4), try parse("2+2"));
    try std.testing.expectEqual(@as(f64, 511), try parse("2+6+2+12+69+420"));
}

test "minus" {
    try std.testing.expectEqual(@as(f64, 0), try parse("2-2"));
}

test "69" {
    try std.testing.expectEqual(@as(f64, 69), try parse("(3-5)*(23+5)+5*(23-3+5)"));
}