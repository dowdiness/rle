# API Naming Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename `count()` → `length()`, `len()` → `span()`, `content_len()` → `logical_length()` across the RLE library, and add `is_empty()` to `HasLength` trait.

**Architecture:** Five sequential layers (traits → impls → tests → docs → generated), each verified with `moon check` before proceeding. Renames are achieved by replacing standalone `pub fn` methods with `pub impl TraitName for Type with method_name` blocks.

**Tech Stack:** MoonBit, `moon check` / `moon test` / `moon info` CLI.

---

## Layer 1 — Traits

### Task 1: Update `traits.mbt`

**Files:**
- Modify: `rle/traits.mbt`

**Step 1: Replace `HasLength` with version adding `is_empty` default**

```moonbit
///|
/// **HasLength** - "Plain size"
///
/// Basic length for a value.
pub(open) trait HasLength {
  length(Self) -> Int

  /// Returns true if length is zero
  is_empty(Self) -> Bool {
    self.length() == 0
  }
}
```

**Step 2: Replace `Spanning` — rename `content_len` to `logical_length`, add default**

```moonbit
///|
/// **Spanning** - "Two notions of size"
///
/// Many data structures need two different notions of "length":
///
/// - `span`: The total size in the position/index space.
///   Always positive; includes all elements regardless of state.
///
/// - `logical_length`: The size of the useful/visible payload.
///   May be less than `span` if some elements are hidden or deleted.
///   Defaults to `span()` — override when logical size differs.
///
/// Note: `span` defaults to `HasLength::length` unless overridden.
pub(open) trait Spanning: HasLength {
  span(Self) -> Int = _
  logical_length(Self) -> Int {
    self.span()
  }
}

///|
/// Default span delegates to plain length.
impl Spanning with span(self) {
  HasLength::length(self)
}
```

**Step 3: Verify**

```bash
moon check
```

Expected: passes (no implementors of `content_len` yet — those are in Layer 2).

**Step 4: Commit**

```bash
git add rle/traits.mbt
git commit -m "refactor: update HasLength and Spanning traits for 0.1.0 API"
```

---

## Layer 2 — Implementations

### Task 2: Update `prefix_sums.mbt`

Start with `PrefixSums` — it has no trait impls, only standalone renames. Easiest file.

**Files:**
- Modify: `rle/prefix_sums.mbt`

**Step 1: Rename `len` → `span`**

Find:
```moonbit
pub fn PrefixSums::len(self : PrefixSums) -> Int {
```
Replace with:
```moonbit
pub fn PrefixSums::span(self : PrefixSums) -> Int {
```

**Step 2: Rename `content_len` → `logical_length`**

Find:
```moonbit
pub fn PrefixSums::content_len(self : PrefixSums) -> Int {
```
Replace with:
```moonbit
pub fn PrefixSums::logical_length(self : PrefixSums) -> Int {
```

**Step 3: Rename `count` → `length`**

Find:
```moonbit
pub fn PrefixSums::count(self : PrefixSums) -> Int {
```
Replace with:
```moonbit
pub fn PrefixSums::length(self : PrefixSums) -> Int {
```

**Step 4: Verify**

```bash
moon check
```

Expected: errors in `rle.mbt` calling old `PrefixSums` method names — that's expected, fixed next. (`runs.mbt` does not call `PrefixSums` directly and is unaffected.)

**Step 5: Commit**

```bash
git add rle/prefix_sums.mbt
git commit -m "refactor: rename PrefixSums methods (len→span, content_len→logical_length, count→length)"
```

---

### Task 3: Update `runs.mbt`

**Files:**
- Modify: `rle/runs.mbt`

**Step 1: Replace `Runs::count` with `HasLength` trait impl**

Remove:
```moonbit
///|
/// Number of runs
pub fn[T] Runs::count(self : Runs[T]) -> Int {
  self.0.length()
}
```

Replace with:
```moonbit
///|
/// HasLength impl — number of runs
pub impl[T] HasLength for Runs[T] with length(self : Runs[T]) -> Int {
  self.0.length()
}

///|
/// HasLength impl — is_empty
pub impl[T] HasLength for Runs[T] with is_empty(self : Runs[T]) -> Bool {
  self.0.is_empty()
}
```

**Step 2: Remove the old standalone `is_empty`**

Remove:
```moonbit
///|
/// Check if there are no runs
pub fn[T] Runs::is_empty(self : Runs[T]) -> Bool {
  self.0.is_empty()
}
```

(It is now covered by the `HasLength` impl above.)

**Step 3: Replace `Runs::len` with `Spanning` trait impl**

Remove:
```moonbit
///|
/// Total span length - O(n)
pub fn[T : Spanning] Runs::len(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::span(item) })
}
```

Replace with:
```moonbit
///|
/// Spanning impl — total span, O(n)
pub impl[T : Spanning] Spanning for Runs[T] with span(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::span(item) })
}
```

**Step 4: Replace `Runs::content_len` with `logical_length` trait impl**

Remove:
```moonbit
///|
/// Total content length - O(n)
pub fn[T : Spanning] Runs::content_len(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::content_len(item) })
}
```

Replace with:
```moonbit
///|
/// Spanning impl — total logical length, O(n)
pub impl[T : Spanning] Spanning for Runs[T] with logical_length(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::logical_length(item) })
}
```

**Step 5: Update internal `self.len()` calls → `self.span()`**

There are 6 occurrences (lines 227, 276, 294, 420, 468, 509 in the original file). Search for `self.len()` within `runs.mbt` and replace all with `self.span()`.

**Step 6: Verify**

```bash
moon check
```

Expected: errors in `rle.mbt` calling `self.runs.count()` and `rle_benchmark.mbt` — fixed in later tasks.

**Step 7: Commit**

```bash
git add rle/runs.mbt
git commit -m "refactor: replace Runs standalone methods with HasLength/Spanning trait impls"
```

---

### Task 4: Update `rle.mbt`

**Files:**
- Modify: `rle/rle.mbt`

**Step 1: Replace `Rle::count` with `HasLength` trait impl**

Remove:
```moonbit
///|
/// Number of runs
pub fn[T] Rle::count(self : Rle[T]) -> Int {
  self.runs.count()
}
```

Replace with:
```moonbit
///|
/// HasLength impl — number of runs
pub impl[T] HasLength for Rle[T] with length(self : Rle[T]) -> Int {
  self.runs.length()
}

///|
/// HasLength impl — is_empty
pub impl[T] HasLength for Rle[T] with is_empty(self : Rle[T]) -> Bool {
  self.runs.is_empty()
}
```

**Step 2: Remove the old standalone `is_empty`**

Remove:
```moonbit
///|
/// Check if the Rle contains no runs
pub fn[T] Rle::is_empty(self : Rle[T]) -> Bool {
  self.runs.is_empty()
}
```

(Now covered by the `HasLength` impl above.)

**Step 3: Replace `Rle::len` with `Spanning` trait impl**

Remove:
```moonbit
///|
/// Total span length - O(1) with cache
pub fn[T : Spanning] Rle::len(self : Rle[T]) -> Int {
  self.ensure_prefix().len()
}
```

Replace with:
```moonbit
///|
/// Spanning impl — total span, O(1) with cache
pub impl[T : Spanning] Spanning for Rle[T] with span(self : Rle[T]) -> Int {
  self.ensure_prefix().span()
}
```

**Step 4: Replace `Rle::content_len` with `logical_length` trait impl**

Remove:
```moonbit
///|
/// Total content length - O(1) with cache
pub fn[T : Spanning] Rle::content_len(self : Rle[T]) -> Int {
  self.ensure_prefix().content_len()
}
```

Replace with:
```moonbit
///|
/// Spanning impl — logical content length, O(1) with cache
pub impl[T : Spanning] Spanning for Rle[T] with logical_length(self : Rle[T]) -> Int {
  self.ensure_prefix().logical_length()
}
```

**Step 5: Update internal calls in `rle.mbt`**

| Location | Find | Replace |
|----------|------|---------|
| `extend` method | `self.runs.count()` (×2) | `self.runs.length()` |
| `range` method | `sums.len()` | `sums.span()` |
| `value_at` method | `sums.len()` | `sums.span()` |
| `range_clamped` method | `self.len()` | `self.span()` |

Search for all remaining occurrences of `.count()`, `.len()`, `.content_len()` in `rle.mbt` and replace.

**Step 6: Verify**

```bash
moon check
```

Expected: errors only in test files and `rle_benchmark.mbt` — fixed in later tasks.

**Step 7: Commit**

```bash
git add rle/rle.mbt
git commit -m "refactor: replace Rle standalone methods with HasLength/Spanning trait impls"
```

---

### Task 5: Update `rle_cursor.mbt`

**Files:**
- Modify: `rle/rle_cursor.mbt`

**Step 1: Rename 4 calls of `self.rle.len()` → `self.rle.span()`**

Lines 64, 76, 149, 183. Find all `self.rle.len()` and replace with `self.rle.span()`.

**Step 2: Verify**

```bash
moon check
```

**Step 3: Commit**

```bash
git add rle/rle_cursor.mbt
git commit -m "refactor: update rle_cursor.mbt len() → span() calls"
```

---

### Task 6: Update `runs_string.mbt` and `rle_benchmark.mbt`

**Files:**
- Modify: `rle/runs_string.mbt`
- Modify: `rle/rle_benchmark.mbt`

**Step 1: Remove `content_len` impl from `runs_string.mbt`**

Remove:
```moonbit
///|
/// String implements Spanning - span = content_len = UTF-16 code unit count
pub impl Spanning for String with content_len(self : String) -> Int {
  self.length()
}
```

Update the doc comment on the `HasLength` impl to reflect the new default:
```moonbit
///|
/// String implements Spanning - span = logical_length = UTF-16 code unit count
/// logical_length() defaults to span(), which defaults to HasLength::length()
```

**Step 2: Remove `content_len` impl from `rle_benchmark.mbt`**

Remove:
```moonbit
///|
pub impl Spanning for BenchRun with content_len(self : BenchRun) -> Int {
  self.len
}
```

The default `logical_length()` → `span()` → `HasLength::length()` → `self.len` is correct.

**Step 3: Verify — full clean build**

```bash
moon check
```

Expected: **zero errors**. This is the Layer 2 gate.

**Step 4: Commit**

```bash
git add rle/runs_string.mbt rle/rle_benchmark.mbt
git commit -m "refactor: remove redundant content_len impls (default logical_length sufficient)"
```

---

## Layer 3 — Tests

### Task 7: Update `rle_test.mbt` (75 tests)

**Files:**
- Modify: `rle/rle_test.mbt`

**Step 1: Bulk rename method calls**

Replace all occurrences:
- `.count()` → `.length()`
- `.len()` → `.span()`
- `.content_len()` → `.logical_length()`

**Step 2: Verify**

```bash
moon check && moon test --package rle 2>&1 | head -40
```

**Step 3: Commit**

```bash
git add rle/rle_test.mbt
git commit -m "test: update rle_test.mbt for renamed API methods"
```

---

### Task 8: Update `runs_test.mbt` (54 tests)

**Files:**
- Modify: `rle/runs_test.mbt`

**Step 1: Bulk rename method calls**

Replace all occurrences:
- `.count()` → `.length()`
- `.len()` → `.span()`
- `.content_len()` → `.logical_length()`

**Step 2: Verify**

```bash
moon check && moon test --package rle 2>&1 | head -40
```

**Step 3: Commit**

```bash
git add rle/runs_test.mbt
git commit -m "test: update runs_test.mbt for renamed API methods"
```

---

### Task 9: Update `runs_properties_test.mbt` (18 tests)

**Files:**
- Modify: `rle/runs_properties_test.mbt`

**Step 1: Bulk rename method calls**

Replace all occurrences of `.len()` → `.span()` (18 tests use `runs.len()`).

**Step 2: Verify**

```bash
moon check && moon test --package rle 2>&1 | head -40
```

**Step 3: Commit**

```bash
git add rle/runs_properties_test.mbt
git commit -m "test: update runs_properties_test.mbt for renamed API methods"
```

---

### Task 10: Update `runs_wbtest.mbt` (10 tests) and `rle_benchmark.mbt` call sites

**Files:**
- Modify: `rle/runs_wbtest.mbt`
- Modify: `rle/rle_benchmark.mbt`

**Step 1: Update `runs_wbtest.mbt`**

Replace `.len()` → `.span()` (used in `let _ = rle.len()` calls at lines 88, 94, 101, 111).

**Step 2: Update `rle_benchmark.mbt` call sites**

Replace `.count()` → `.length()` in `b.keep(result.count())`, `b.keep(runs_a.count())`, `b.keep(runs.count())`.

**Step 3: Verify — full test gate**

```bash
moon check && moon test
```

Expected: **all tests pass**.

```bash
moon bench --package rle --release
```

Expected: benchmarks run without errors.

**Step 4: Commit**

```bash
git add rle/runs_wbtest.mbt rle/rle_benchmark.mbt
git commit -m "test: update whitebox tests and benchmark call sites for renamed API"
```

---

### Task 11: Add new `is_empty` trait coverage tests

**Files:**
- Modify: `rle/rle_test.mbt`

**Step 1: Add tests**

Add at the end of `rle_test.mbt`:

```moonbit
///|
test "HasLength::is_empty - empty Rle" {
  let rle : Rle[String] = Rle::new()
  inspect(rle.is_empty(), content="true")
}

///|
test "HasLength::is_empty - non-empty Rle" {
  let rle = Rle::from_string("hello")
  inspect(rle.is_empty(), content="false")
}

///|
test "HasLength::is_empty via generic constraint" {
  fn check_empty[T : HasLength](x : T) -> Bool {
    x.is_empty()
  }
  let empty : Rle[String] = Rle::new()
  let nonempty = Rle::from_string("hi")
  inspect(check_empty(empty), content="true")
  inspect(check_empty(nonempty), content="false")
}

///|
test "Spanning::logical_length default - equals span for String" {
  let rle = Rle::from_string("hello")
  inspect(rle.logical_length() == rle.span(), content="true")
}
```

**Step 2: Run and verify**

```bash
moon test --package rle
```

Expected: all pass including 4 new tests.

**Step 3: Commit**

```bash
git add rle/rle_test.mbt
git commit -m "test: add is_empty trait coverage and logical_length default tests"
```

---

## Layer 4 — Docs and Config

### Task 12: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Fix line 43**

Find:
```text
**Accessing prefix sums without ensure_prefix().** Always call `self.ensure_prefix()` before reading `self.prefix`. See `find()`, `len()`, `content_len()`, `range()`.
```

Replace with:
```text
**Accessing prefix sums without ensure_prefix().** Always call `self.ensure_prefix()` before reading `self.prefix`. See `find()`, `span()`, `logical_length()`, `range()`.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md method name references for 0.1.0 API"
```

---

### Task 13: Update `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Replace all old method names throughout the README**

- `.count()` → `.length()`
- `.len()` → `.span()`
- `.content_len()` → `.logical_length()`

**Step 2: Update any API tables or method lists** to reflect new names.

**Step 3: Verify examples compile** (manually check any inline code blocks).

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: update README for 0.1.0 API naming"
```

---

### Task 14: Create `CHANGELOG.md`

**Files:**
- Create: `CHANGELOG.md`

**Step 1: Create `CHANGELOG.md`**

```markdown
# Changelog

## [0.1.0] - 2026-02-19

Initial stable release with clean, consistent API.

### Breaking Changes

- `Rle::count()` → `Rle::length()`
- `Runs::count()` → `Runs::length()`
- `Rle::len()` → `Rle::span()`
- `Runs::len()` → `Runs::span()`
- `Rle::content_len()` → `Rle::logical_length()`
- `Runs::content_len()` → `Runs::logical_length()`
- `PrefixSums::len()` → `PrefixSums::span()`
- `PrefixSums::content_len()` → `PrefixSums::logical_length()`
- `PrefixSums::count()` → `PrefixSums::length()`
- `Spanning::content_len` trait method renamed to `logical_length` (now has default)
- `HasLength::is_empty()` added as trait method (default: `length() == 0`)

### Features

- Generic run-length encoding with O(log n) position lookup
- Lazy prefix sum caching for efficient queries
- Dual-length semantics (`span` vs `logical_length`)
- Cursor-based sequential traversal with staleness detection
- Comprehensive trait system (`HasLength`, `Spanning`, `Mergeable`, `Sliceable`)
- Full Unicode support (UTF-16 code units)
- Property-based testing with QuickCheck
- Batch construction and convenience operations (`insert`, `delete`, `splice`, `value_at`)
```

**Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "chore: add CHANGELOG for 0.1.0"
```

---

## Layer 5 — Generated Files

### Task 15: Regenerate `pkg.generated.mbti`

**Files:**
- Regenerate: `rle/pkg.generated.mbti`

**Step 1: Regenerate**

```bash
moon info
```

**Step 2: Verify exported names**

Check `rle/pkg.generated.mbti` contains:
- `pub fn PrefixSums::span(Self) -> Int` (not `len`)
- `pub fn PrefixSums::logical_length(Self) -> Int` (not `content_len`)
- `pub fn PrefixSums::length(Self) -> Int` (not `count`)
- `pub impl HasLength for Rle` (trait impl)
- `pub impl Spanning for Rle` (trait impl)
- `pub impl HasLength for Runs` (trait impl)
- `pub impl Spanning for Runs` (trait impl)

**Step 3: Final verification**

```bash
moon check && moon test && moon bench --package rle --release
```

Expected: all pass.

**Step 4: Commit**

```bash
git add rle/pkg.generated.mbti
git commit -m "chore: regenerate pkg.generated.mbti for 0.1.0 API"
```

---

## Final Checklist

- [ ] `moon check` passes
- [ ] `moon test` passes (100%)
- [ ] `moon bench --release` runs without errors
- [ ] `pkg.generated.mbti` exports new names
- [ ] `CHANGELOG.md` accurate
- [ ] `moon.mod.json` version is `"0.1.0"`
