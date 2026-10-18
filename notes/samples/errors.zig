// エラー処理のサンプル: エラー共用体・try・catch・if/else |err|・errdefer・||
const std = @import("std");

const ParseError = error{ Empty, TooLong };
const OtherError = error{Busy};
const AllError = ParseError || OtherError; // エラー集合の合併

fn check(s: []const u8) ParseError!usize {
	if (s.len == 0) return error.Empty;
	if (s.len > 10) return error.TooLong;
	return s.len;
}

fn checkTwice(a: []const u8, b: []const u8) !usize {
	return try check(a) + try check(b); // エラーならそのまま呼び出し元へ返す
}

fn mayBusy(busy: bool) AllError!void {
	if (busy) return error.Busy;
}

test "try はエラーを呼び出し元へそのまま返す" {
	try std.testing.expectEqual(@as(usize, 5), try checkTwice("ab", "cde"));
	try std.testing.expectError(error.Empty, checkTwice("ab", ""));
}

test "catch でその場で既定値にできる" {
	const n = check("") catch 0;
	try std.testing.expectEqual(@as(usize, 0), n);
}

test "if/else |err| と switch でエラーごとに分ける" {
	const msg = if (check("01234567890")) |_| "ok" else |err| switch (err) {
		error.Empty => "空",
		error.TooLong => "長すぎ",
	};
	try std.testing.expectEqualStrings("長すぎ", msg);
}

test "|| で合併したエラー集合はどちらのエラーも持てる" {
	try std.testing.expectError(error.Busy, mayBusy(true));
	try mayBusy(false);
}

const Res = struct {
	ok: bool,
	fn init(self: *Res, fail: bool) !void {
		if (fail) return error.InitFailed;
		self.ok = true;
	}
};

fn open(alloc: std.mem.Allocator, fail: bool) !*Res {
	const r = try alloc.create(Res);
	errdefer alloc.destroy(r); // init が失敗したときだけ解放する
	try r.init(fail);
	return r;
}

test "errdefer は失敗したときだけ後始末し、リークを残さない" {
	// std.testing.allocator はリークがあるとテストを失敗させる
	const alloc = std.testing.allocator;
	try std.testing.expectError(error.InitFailed, open(alloc, true));
	const r = try open(alloc, false);
	defer alloc.destroy(r);
	try std.testing.expect(r.ok);
}
