// メモリ管理のサンプル: allocator を引数で渡す・defer で解放・arena・固定バッファ
const std = @import("std");

// 確保する関数は allocator を引数で受け取る。解放は呼び出し側の責任
fn squares(alloc: std.mem.Allocator, n: usize) ![]u32 {
	const buf = try alloc.alloc(u32, n);
	for (buf, 0..) |*p, i| p.* = @intCast(i * i);
	return buf;
}

test "確保した直後に defer で解放を書く" {
	const alloc = std.testing.allocator;
	const list = try squares(alloc, 5);
	defer alloc.free(list);
	try std.testing.expectEqualSlices(u32, &.{ 0, 1, 4, 9, 16 }, list);
}

test "ArenaAllocator は個別に解放せず最後にまとめて解放する" {
	var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
	defer arena.deinit();
	const alloc = arena.allocator();
	_ = try squares(alloc, 100);
	_ = try squares(alloc, 200);
}

test "FixedBufferAllocator はヒープを使わず、足りなければ OutOfMemory を返す" {
	var buffer: [16]u8 = undefined;
	var fba = std.heap.FixedBufferAllocator.init(&buffer);
	const alloc = fba.allocator();
	const a = try squares(alloc, 4); // 16 バイトちょうど
	_ = a;
	try std.testing.expectError(error.OutOfMemory, squares(alloc, 1));
}

test "FailingAllocator で確保の失敗を起こせる" {
	var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
	try std.testing.expectError(error.OutOfMemory, squares(failing.allocator(), 3));
}
