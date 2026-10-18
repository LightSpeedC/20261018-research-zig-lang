# Zig 言語の調査

Zig がどんな言語か、どう書くか、どれくらい速いかを公開情報から調べる

> 📅 作成: 2026-10-18 / 更新: 2026-10-18

[親サイトへ](../)

汎用のシステムプログラミング言語 Zig について、言語の特徴・構文・メモリ管理・エラー処理・並行処理・速度・採用例を調べた結果。

> [!NOTE]
> <strong>`std.Io` のコードは動かしていない。</strong>基本構文・メモリ管理・エラー処理は、Zig 0.17.0 で動くサンプルとテストで確かめた（[syntax.zig](notes/samples/syntax.zig) ・ [memory.zig](notes/samples/memory.zig) ・ [errors.zig](notes/samples/errors.zig)。全件の実行は `tools/40_test/run-tests.cmd`）。並行処理の章の `std.Io` は 0.16 で入ったばかりで、版によって関数名や引数が変わりうる。

1. [Zig の概要](#1-zig-の概要)
2. [基本構文](#2-基本構文)
3. [メモリ管理](#3-メモリ管理)
4. [エラー処理](#4-エラー処理)
5. [並行処理と非同期 I/O](#5-並行処理と非同期-io)
6. [速度](#6-速度)
7. [Zig で書かれたプロジェクト](#7-zig-で書かれたプロジェクト)
8. [出典](#8-出典)

## 1. Zig の概要

Andrew Kelley 氏が 2016 年に始めた言語。非営利の Zig Software Foundation が開発する。C の置き換えを狙い、C と同じ領域をより安全・明快に書けるようにする。

### 特徴

- **隠れた制御フローが無い**。暗黙の関数呼び出し・メモリ確保・例外・演算子オーバーロード・マクロを持たない
- **手動メモリ管理**。GC は無く、確保する関数には allocator を引数で渡す
- **`comptime`**。コンパイル時に Zig のコードを実行でき、ジェネリクスやメタプログラミングを担う
- **エラーは値**。例外は無く、エラー共用体型で返す
- **安全性チェック**。Debug / ReleaseSafe では範囲外アクセスや整数オーバーフローを実行時に検出する
- **C との親和性**。`@cImport` で C ヘッダを直接読む。`zig cc` は C/C++ のクロスコンパイラとしても使える
- **ビルドも Zig で書く**。`build.zig` を使い、make や CMake は要らない

### 現状

- 1.0 前。版ごとに言語と標準ライブラリに破壊的変更が入る
- 0.16.0 で I/O をインターフェースとして扱う形が入った
- 手元に入れた Zig は `zig version` で 0.17.0 と確かめた。0.17.0 が最新の安定版で、2026-10-01 に出たという情報は、第三者のサイトの記述で、公式サイトでは確かめていない

### C ・ Rust との比較

|  | C | Rust | Zig |
|---|---|---|---|
| メモリ安全性 | なし | コンパイル時に保証（borrow checker） | 実行時チェックのみ |
| エラー処理 | 戻り値・errno | `Result<T, E>` | エラー共用体 `E!T` |
| 学習コスト | 低 | 高 | 中 |
| 安定性 | 高 | 高 | 1.0 前 |

## 2. 基本構文

### 記号の意味

| 記号 | 書く位置 | 意味 |
|---|---|---|
| `:` | 変数・引数の名前の後ろ | 型注釈（`const a: i32 = 10;`）。戻り値の型は `)` の後ろに `:` なしで書く |
| `E!T` / `!T` | 型 | エラー共用体型。エラー集合 `E` のどれか、または `T` の値。`E` を省くとコンパイラが推論する |
| `?T` | 型 | optional。値か `null` |
| `\|x\|` | if ・ while ・ for ・ catch ・ switch の後ろ | キャプチャ。取り出した値に名前を付ける。`\|*x\|` はポインタで受ける |
| `A \|\| B` | 型 | エラー集合の合併 |
| `!a` | 式 | 論理否定 |
| `a \| b` | 式 | ビット OR |
| `and` / `or` | 式 | 論理積・論理和。`&&` ・ `\|\|` ではなく語で書く。右辺は必要なときだけ評価する |
| `orelse` / `.?` | 式 | optional の取り出し。`null` なら既定値／ `.?` は `orelse unreachable` と同じ |

### 制御構文

```zig
const a: i32 = 10;                  // const は変えない、var は変える
const c = if (a > 5) "大" else "小"; // if は式になる（三項演算子の代わり）

const maybe: ?i32 = 42;
if (maybe) |v| { _ = v; }           // 値があるときだけ取り出す

var i: usize = 0;
while (i < 3) : (i += 1) {}         // : ( ) は毎回の後処理
while (it.next()) |item| { _ = item; } // null が返るまで回す

for (0..10) |n| { _ = n; }          // 範囲・配列・スライスを回す。C 形式の for は無い
for (arr, 0..) |x, idx| { _ = x; _ = idx; } // 要素と添字
for (arr) |*p| { p.* += 1; }        // ポインタで受けて書き換える

const s = switch (a) {              // 全部の値を網羅しないとコンパイルエラー
    0 => "zero",
    1...9 => "small",
    else => "big",
};
defer cleanup();                    // スコープを出るときに必ず実行する
```

### 関数

```zig
fn add(a: i32, b: i32) i32 { return a + b; }
fn parse(s: []const u8) !u32 { ... }             // エラーを返しうる
fn max(comptime T: type, a: T, b: T) T { ... }   // 型を引数で受ける（ジェネリクスの代わり）
```

- 関数はすべて普通の同期関数。中断・再開できる特別な関数は無い
- クロージャは無い。状態は構造体に持たせる
- 値を捨てられるのは `void` 型の式だけ。戻り値を使わないなら `_ = f();` と明示する

## 3. メモリ管理

GC は無く、確保も解放も手動で行う。**メモリを確保する関数は allocator を引数で受け取る**。確保の仕方は呼び出し側が決める。

```zig
fn makeList(alloc: std.mem.Allocator, n: usize) ![]u32 {
    return try alloc.alloc(u32, n);   // 失敗すると error.OutOfMemory
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();            // 終了時にリークを報告する
    const alloc = gpa.allocator();

    const list = try makeList(alloc, 10);
    defer alloc.free(list);            // 確保した直後に解放を書く
}
```

### allocator の選び方

言語リファレンスの「Choosing an Allocator」に挙がっているもの。

| allocator | 使いどころ |
|---|---|
| `std.heap.c_allocator` | libc をリンクするなら、主な allocator の第一候補 |
| `std.heap.FixedBufferAllocator` | 使う量の上限がコンパイル時に分かるとき。ヒープを使わない |
| `std.heap.ArenaAllocator` | コマンドラインのプログラムや、1 フレーム・1 リクエスト単位の処理。最後にまとめて解放する |
| `std.heap.page_allocator` | OS からページ単位で確保する。arena の土台に使う |
| `std.testing.allocator` | テスト用。簡単なリーク検出をする |
| `std.testing.FailingAllocator` | `error.OutOfMemory` の扱いをテストする |
| `std.heap.DebugAllocator` | Debug ビルドの汎用。0.14 で `GeneralPurposeAllocator` から改名 |
| `std.heap.smp_allocator` | リリースビルドの汎用 |

### Rust との違い

Rust はコンパイル時に所有権を検査するが、Zig は検査しない。解放後の使用や二重解放は、Debug ビルドの実行時チェックや `DebugAllocator` で見つける。Bun が Rust へ移った主な理由もここにある（「Zig で書かれたプロジェクト」の章）。

## 4. エラー処理

例外は無い。エラーは戻り値として、エラー共用体型 `E!T` で返す。

```zig
const ParseError = error{ Empty, TooLong };  // エラー集合を定義する

fn check(s: []const u8) ParseError!void {
    if (s.len == 0) return error.Empty;
    if (s.len > 10) return error.TooLong;
}

fn run() !void {
    try check("abc");                  // エラーなら呼び出し元へ返す

    check("") catch |err| switch (err) { // その場で処理する
        error.Empty => {},
        error.TooLong => {},
    };

    const n = std.fmt.parseInt(u8, "x", 10) catch 0; // 失敗したら既定値
    _ = n;

    if (check("x")) |_| {} else |err| { _ = err; } // if でも分けられる
}

fn open(alloc: std.mem.Allocator) !*Res {
    const r = try alloc.create(Res);
    errdefer alloc.destroy(r);         // この後でエラーが返ったときだけ実行する
    try r.init();
    return r;
}
```

| 他言語の書き方 | Zig |
|---|---|
| `throw` | `return error.Xxx;` |
| `try { } catch { }` | `x() catch \|err\| { ... }`（式単位） |
| 呼び出し元へ伝える | `try x()` |
| `finally` | `defer` |
| 失敗したときだけ後始末 | `errdefer` |
| 意図して無視する | `x() catch unreachable` |

- **エラーは黙って捨てられない**。値を捨てられるのは `void` だけなので、`try` ・ `catch` ・ `if` のどれかで扱う
- エラーは列挙値のようなもので、メッセージなどの情報は持たせられない。詳しい情報は別の引数で返す
- **エラーリターントレース**。`main` からエラーが返ると、エラーが通ってきた経路を表示して終了コード 1 で終わる
- `unreachable` と `@panic` は回復できない停止で、エラー処理とは別

## 5. 並行処理と非同期 I/O

### コルーチン・goroutine・generator

| ほかの言語の機能 | Zig では |
|---|---|
| コルーチン（言語の機能として） | 無い |
| Go の goroutine | 構文としては無い。近いのは `std.Io` の `io.async()` / `io.concurrent()` |
| JS の generator（`yield`） | 無い。`next()` を持つ構造体（イテレータ）を書く |

### async / await が外された理由

- 0.10 までは言語のキーワード（`async` / `await` / `suspend` / `resume`）があった
- Zig 自身で書いた新しいコンパイラでは、この機能が動かなかった。0.11.0 で使えなくなり、2022 年 12 月に言語リファレンスからも消えた
- 言語リファレンスが挙げた未解決の問題は 4 つ
    - LLVM が async 関数を最適化できない
    - 他社製のデバッガで async 関数をデバッグできない
    - 取り消し（cancel）をどう扱うか決まっていない
    - async 関数のポインタがあると、スタックの大きさが決まらない
- 2025 年 7 月、キーワードは正式に削除された。言語に `async` / `await` のキーワードは戻さず、I/O の実装を支える低水準の仕組みとして入れ直す、という方針が示された

### 代わりの仕組み（0.16 の std.Io）

allocator を引数で渡すのと同じように、I/O を行う関数は `io` を引数で受け取る。並行に動かしたいところで `io.async()` を呼ぶと future が返り、`future.await(io)` で結果を受け取る。

```zig
fn work(io: std.Io) !void {
    var f = io.async(fetchA, .{io});
    defer f.cancel(io) catch {};   // 取り消しと後始末
    const r = try f.await(io);
    _ = r;
    try io.sleep(...);             // タイマ。待つのも io を通す
}
```

|  | 旧（〜0.10） | 新（0.16〜） |
|---|---|---|
| 仕組み | 言語のキーワード | 標準ライブラリの関数 |
| 関数の種類 | 同期関数と async 関数 | すべて普通の関数。`io` を引数で受けるだけ |
| 実行のしかた | 言語が決める | 渡す `Io` の実装で選ぶ。`std.Io.Threaded`（スレッド）／ `std.Io.Evented`（io_uring ・ kqueue） |

- 見た目は普通のブロッキングするコードと同じ。同じコードを、同期でも非同期でも動かせる
- 同時に動くことが必要なときは `io.concurrent()` を使う
- 0.16 で `Clock` ・ `Duration` ・ `Timeout` の型が入った。タイムアウトは、処理と sleep を競わせる形で書く例がある
- network は `std.Io.net` にある。0.16 で動く完全な例は見つけていない

## 6. 速度

### 実行速度

LLVM を最適化に使うため、ReleaseFast で作ったバイナリは C ・ Rust と同程度になる。2021 年の比較スレッドでは 6 本中 4 本で Rust が上回ったが、差は小さく、マイクロベンチマークでは優劣を決められないと結論している。速さを分けるのは言語ではなく、メモリ確保の仕方やデータ配置といった書き方である。

### コンパイル速度

Debug ビルドは、LLVM の機械語生成に時間がかかり、遅いとされてきた。

| 処理系 | 最小プログラムの Debug ビルド |
|---|---:|
| Zig 0.13.0 | 約 1.27 秒 |
| rustc 1.78.0 | 約 0.28 秒 |
| clang++ 17 | 約 0.16 秒 |

Zig の時間の大半は LLVM のオブジェクト出力だった（Ziggit の投稿者 1 名の計測）。

その対策として、Zig は次の 2 つを進めている。

- **自前の x86 バックエンド**: Debug ビルドで LLVM を使わない
- **インクリメンタルコンパイル**: 変えた関数だけを作り直す

再ビルドがミリ秒単位になったという報告や、75 秒が 20 秒に縮んだという報告がある。ただし二次情報で、計測の条件は確かめていない。2026 年 5 月には、ビルドシステムの改修で `zig build -h` が約 150 ミリ秒から約 14 ミリ秒になった。

> [!NOTE]
> <strong>数値は自分の環境で測り直す。</strong>この章の数値は版の古い計測や二次情報を含む。Zig は版ごとにコンパイラが大きく変わるため、使う版で hyperfine などを使って測らないと判断に使えない。

## 7. Zig で書かれたプロジェクト

| プロジェクト | 何か | 補足 |
|---|---|---|
| Bun | JavaScript/TypeScript のランタイム・バンドラ・パッケージマネージャ | Zig で開発され、Zig の採用例として最も知られていた。2025 年 12 月に Anthropic が買収。その後 Rust に書き換えられ、2026 年 5 月に本体へ取り込まれた。約 53.5 万行の Zig を AI で移植し、主な理由は use-after-free などのメモリ安全性の不具合を防ぐこと。Zig 版の最後は 1.3.14 |
| TigerBeetle | 金融取引（複式簿記）向けの分散データベース | Zig Software Foundation へ Synadia と共同で 512,000 ドルの寄付を表明 |
| Ghostty | ターミナルエミュレータ |  |
| Roc | 関数型言語のコンパイラ | Rust から Zig へ書き直し |
| River | Wayland の動的タイル型コンポジタ |  |
| hermetic_cc_toolchain | Bazel 用の C/C++ ツールチェーン | Uber が管理。`zig cc` の上で C/C++ をクロスコンパイルする。Uber は arm64 対応の基盤に使った |
| Zig | Zig のコンパイラ | Zig 自身で書かれている（セルフホスト） |

## 8. 出典

- [Zig Language Reference（master）](https://ziglang.org/documentation/master/)
- [Andrew Kelley: Zig's New Async I/O](https://andrewkelley.me/post/zig-new-async-io-text-version.html)
- [langref: eliminate dependencies on stage1（async を外したコミット）](https://git.jakstys.lt/motiejus/zig/commit/6e52f36d46f6dbcd4be6295fea6d54868399c12f/)
- [remove async, await, usingnamespace（#24362）](https://git.jakstys.lt/motiejus/zig/commit/fc2c1883b36a6ba8c7303d12b57147656dc7dd70)
- [DevClass: extremely breaking change to std.io](https://devclass.com/2025/07/07/zig-lead-makes-extremely-breaking-change-to-stdio-ahead-of-async-and-awaits-return/)
- [Ziggit: the new Io interface](https://ziggit.dev/t/a-little-help-with-io-please-i-am-trying-to-understand-how-to-use-the-new-io-interface-for-zig/14006)
- [Async/Await is finally back in Zig](https://charlesfonseca.substack.com/p/asyncawait-is-finally-back-in-zig)
- [Zig 0.16 Io interface (youngju.dev)](https://www.youngju.dev/blog/2026-07-16-zig-016-io-interface)
- [Ghostty: Zig 0.14 対応のコミット（DebugAllocator への改名）](https://git.uoc.run.place/Applied-Software/ghostty/commit/274f9e6c3a97163bbe5c3ee1c412ae45d7545c36)
- [Ziggit: Newcomer: Getting into Allocators](https://ziggit.dev/t/newcomer-getting-into-allocators/9621)
- [LWN: Zig 0.16.0](https://lwn.net/Articles/1067634/)
- [How To Install Zig on Ubuntu 26.04 LTS](https://idroot.us/install-zig-programming-language-ubuntu-26-04/)
- [zig systems programming pc](https://jisaku.com/posts/zig-systems-programming-pc)
- [Why is Zig much slower than other LLVM-based compilers?](https://ziggit.dev/t/why-is-zig-much-slower-than-other-llvm-based-compilers-includes-benchmark/5040)
- [Why is zig build so slow?](https://ziggit.dev/t/why-is-zig-build-so-slow/16935)
- [Is zig lang faster than rust?](https://users.rust-lang.org/t/is-zig-lang-faster-than-rust/70390)
- [Zig 2026: compilación incremental y nuevos tipos](https://ecosistemastartup.com/?p=66785)
- [Zig vs Rust 2026](https://tech-insider.org/zig-vs-rust-2026/)
- [Inside Zig's Incremental Compilation](https://zeli.app/story/49085666)
- [Simon Willison's Weblog: zig](https://simonwillison.net/tags/zig)
- [Synadia and TigerBeetle Pledge $512,000 to the Zig Software Foundation](https://tigerbeetle.com/blog/2025-10-25-synadia-and-tigerbeetle-pledge-512k-to-the-zig-software-foundation/)
- [roc rust to zig rewrite](https://www.developersdigest.tech/blog/roc-rust-to-zig-rewrite-feldman)
- [The Register: Anthropic's Bun Rust rewrite merged at speed of AI](https://www.theregister.com/devops/2026/05/14/anthropics-bun-rust-rewrite-merged-at-speed-of-ai/5240381)
- [InfoQ: Bun Rewrites 535K Lines of Zig into Rust](https://www.infoq.com/news/2026/09/bun-AI-rewrite-zig-rust-4-months/)
- [Wikipedia: Bun (software)](https://en.wikipedia.org/wiki/Bun_(software))
- [river (Codeberg)](https://codeberg.org/yugen-m7/river)
- [uber/hermetic_cc_toolchain](https://github.com/uber/hermetic_cc_toolchain)
- [Uber: Bootstrapping Uber's Infrastructure on arm64 with Zig](https://www.uber.com/en-TW/blog/bootstrapping-ubers-infrastructure-on-arm64-with-zig/)

[親サイトへ](../)
