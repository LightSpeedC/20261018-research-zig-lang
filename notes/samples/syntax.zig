// 基本構文のサンプル: if 式・optional・キャプチャ・while・for・switch
const std = @import("std");

fn classify(a: i32) []const u8 {
	return switch (a) {
		0 => "zero",
		1...9 => "small",
		else => "big",
	};
}

fn sumTo(n: usize) usize {
	var total: usize = 0;
	var i: usize = 1;
	while (i <= n) : (i += 1) total += i;
	return total;
}

test "if は式として値を返す" {
	const a: i32 = 10;
	const c = if (a > 5) "大" else "小";
	try std.testing.expectEqualStrings("大", c);
}

test "optional は |v| で取り出し、null は orelse で既定値になる" {
	const some: ?i32 = 42;
	const none: ?i32 = null;
	if (some) |v| {
		try std.testing.expectEqual(@as(i32, 42), v);
	} else unreachable;
	try std.testing.expectEqual(@as(i32, -1), none orelse -1);
}

test "while の : ( ) は毎回の後処理になる" {
	try std.testing.expectEqual(@as(usize, 55), sumTo(10));
}

test "for は要素と添字を同時に回し、|*p| で書き換えられる" {
	var arr = [_]i32{ 1, 2, 3 };
	for (&arr) |*p| p.* *= 10;
	var sum: i32 = 0;
	for (arr, 0..) |x, i| sum += x * @as(i32, @intCast(i));
	try std.testing.expectEqual(@as(i32, 0 * 10 + 1 * 20 + 2 * 30), sum);
}

test "switch は範囲と else で全ての値を網羅する" {
	try std.testing.expectEqualStrings("zero", classify(0));
	try std.testing.expectEqualStrings("small", classify(5));
	try std.testing.expectEqualStrings("big", classify(100));
}
