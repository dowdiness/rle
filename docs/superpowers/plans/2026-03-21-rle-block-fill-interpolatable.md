# RLE Block Fill & Interpolatable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add block fill, Interpolatable trait, and cursor streaming to the generic RLE library, enabling bulk sequential reads and continuous value computation within runs.

**Architecture:** New `Interpolatable` trait extends `Spanning`. Block fill methods traverse runs linearly from a starting position found via binary search. A shared private traversal helper keeps `fill_buffer` and `fill_buffer_interpolated` in sync. Cursor fill methods use the cursor's current position for O(k) streaming.

**Tech Stack:** MoonBit, moon CLI (check/test/build/fmt/info), quickcheck for property tests.

**Spec:** `docs/superpowers/specs/2026-03-21-rle-block-fill-interpolatable-design.md`

**Dev workflow (every task):** edit → `moon check` → `moon test` → `moon test --update` if snapshots changed → `moon info` → check `.mbti` diffs → `moon fmt` → commit.

**Codebase:** `/home/antisatori/ghq/github.com/dowdiness/canopy/rle`

---

## File Map

### New Files

None — all additions go into existing files following the library's single-package pattern.

### Modified Files

| File | Changes |
|------|---------|
| `src/traits.mbt` | Add `Interpolatable` trait definition |
| `src/runs.mbt` | Add `Runs::fill_buffer` |
| `src/rle.mbt` | Add `Rle::fill_buffer`, `Rle::fill_buffer_interpolated`, shared traversal helper |
| `src/rle_cursor.mbt` | Add `RleCursor::fill_buffer`, `RleCursor::fill_buffer_interpolated` |
| `src/rle_test.mbt` | Tests for Rle fill methods and Interpolatable |
| `src/runs_test.mbt` | Tests for Runs::fill_buffer |
| `src/runs_properties_test.mbt` | QuickCheck property tests |
| `docs/ARCHITECTURE.md` | Add Interpolatable to trait documentation |

---

## Task 1: Interpolatable Trait Definition

**Files:**
- Modify: `src/traits.mbt`
- Modify: `src/rle_test.mbt`

- [ ] **Step 1: Write failing tests for Interpolatable**

In `src/rle_test.mbt`, add test fixture types and tests. The tests use a
`ConstantSegment` type (constant value) and a `RampSegment` type (linear
interpolation). These are defined directly in the test file since they're
test-only types.

```moonbit
///|
struct ConstantSegment {
  value : Double
  len : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for ConstantSegment with length(self) { self.len }

///|
impl @rle.Spanning for ConstantSegment with span(self) { self.len }

///|
impl @rle.Mergeable for ConstantSegment with can_merge(a, b) {
  a.value == b.value
}

///|
impl @rle.Mergeable for ConstantSegment with merge(a, b) {
  { value: a.value, len: a.len + b.len }
}

///|
impl @rle.Interpolatable for ConstantSegment with interpolate(self, _offset) {
  self.value
}

///|
struct RampSegment {
  start : Double
  end_ : Double
  len : Int
} derive(Show, Eq)

///|
impl @rle.HasLength for RampSegment with length(self) { 1 }

///|
impl @rle.Spanning for RampSegment with span(self) { self.len }

///|
impl @rle.Mergeable for RampSegment with can_merge(_a, _b) { false }

///|
impl @rle.Mergeable for RampSegment with merge(a, _b) { a }

///|
impl @rle.Interpolatable for RampSegment with interpolate(self, offset) {
  if self.len <= 1 {
    self.start
  } else {
    let t = offset.to_double() / (self.len - 1).to_double()
    self.start + (self.end_ - self.start) * t
  }
}

///|
test "Interpolatable: constant segment returns same value at any offset" {
  let seg : ConstantSegment = { value: 0.5, len: 100 }
  inspect(@rle.Interpolatable::interpolate(seg, 0), content="0.5")
  inspect(@rle.Interpolatable::interpolate(seg, 50), content="0.5")
  inspect(@rle.Interpolatable::interpolate(seg, 99), content="0.5")
}

///|
test "Interpolatable: ramp segment interpolates linearly" {
  let seg : RampSegment = { start: 0.0, end_: 1.0, len: 11 }
  inspect(@rle.Interpolatable::interpolate(seg, 0), content="0")
  inspect(@rle.Interpolatable::interpolate(seg, 5), content="0.5")
  inspect(@rle.Interpolatable::interpolate(seg, 10), content="1")
}

///|
test "Interpolatable: single-position span returns start" {
  let seg : RampSegment = { start: 42.0, end_: 99.0, len: 1 }
  inspect(@rle.Interpolatable::interpolate(seg, 0), content="42")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `Interpolatable` trait not defined.

- [ ] **Step 3: Add Interpolatable trait to traits.mbt**

Append to `src/traits.mbt` after the `Addressable` trait:

```moonbit
///|
/// **Interpolatable** — compute a numeric value at a specific offset within a run.
///
/// Extends `Spanning` because implementations may need `self.span()` to
/// normalize the offset into a progress value.
///
/// Returns `Double` — appropriate for the primary consumers (parameter
/// automation, animation curves). Multi-valued interpolation (colors, vectors)
/// can use wrapper types that interpolate one channel at a time.
///
/// ## Contract
///
/// Callers must ensure `0 <= offset < self.span()`. The `find()` and
/// `fill_buffer()` methods return validated offsets via `RunPos`.
pub(open) trait Interpolatable : Spanning {
  interpolate(Self, offset : Int) -> Double
}
```

- [ ] **Step 4: Run tests**

Run: `moon check && moon test`
Expected: All tests pass including the 3 new Interpolatable tests.

- [ ] **Step 5: Run dev workflow and commit**

Run: `moon info && moon fmt`
Check `.mbti` diffs — `Interpolatable` should appear.

```bash
git add src/traits.mbt src/rle_test.mbt
git commit -m "Add Interpolatable trait with constant and ramp segment tests"
```

---

## Task 2: Runs::fill_buffer

**Files:**
- Modify: `src/runs.mbt`
- Modify: `src/runs_test.mbt`

- [ ] **Step 1: Write failing tests**

In `src/runs_test.mbt`, using `ConstantSegment` from Task 1 (define it again
in this test file since it's blackbox):

Note: Blackbox tests need to re-define the test types. Alternatively, check if
the types from `rle_test.mbt` are visible. Since both test files are in the
same blackbox test package (`dowdiness/rle_blackbox_test`), they should share
types. Verify by checking moon.pkg — if they're separate packages, define the
types again.

```moonbit
///|
test "Runs::fill_buffer fills within one run" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 10 } as ConstantSegment,
  ])
  let buf = Array::make(5, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(0, buf)
  inspect(result, content="Ok(5)")
  inspect(buf[0].value, content="1")
  inspect(buf[4].value, content="1")
}

///|
test "Runs::fill_buffer spans multiple runs" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
  ])
  let buf = Array::make(6, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(0, buf)
  inspect(result, content="Ok(6)")
  // First 3 positions: value 1.0
  inspect(buf[2].value, content="1")
  // Last 3 positions: value 2.0
  inspect(buf[3].value, content="2")
}

///|
test "Runs::fill_buffer partial fill past end" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
  ])
  let buf = Array::make(5, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(0, buf)
  inspect(result, content="Ok(3)")
  // Positions 3-4 untouched
  inspect(buf[3].value, content="0")
}

///|
test "Runs::fill_buffer start at mid-run" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 10 } as ConstantSegment,
  ])
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(5, buf)
  inspect(result, content="Ok(3)")
}

///|
test "Runs::fill_buffer start negative returns error" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(-1, buf)
  inspect(
    result,
    content="Err(PositionOutOfBounds(position=-1, length=5))",
  )
}

///|
test "Runs::fill_buffer empty buffer returns Ok(0)" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let buf : Array[ConstantSegment] = []
  let result = runs.fill_buffer(0, buf)
  inspect(result, content="Ok(0)")
}

///|
test "Runs::fill_buffer start past end returns Ok(0)" {
  let runs = @rle.Runs::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(10, buf)
  inspect(result, content="Ok(0)")
}

///|
test "Runs::fill_buffer empty sequence returns Ok(0)" {
  let runs : @rle.Runs[ConstantSegment] = @rle.Runs::new()
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = runs.fill_buffer(0, buf)
  inspect(result, content="Ok(0)")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `Runs::fill_buffer` not defined.

- [ ] **Step 3: Implement Runs::fill_buffer**

In `src/runs.mbt`:

```moonbit
///|
/// Fill `buffer` with run objects at consecutive positions starting from
/// `start`. Returns the number of positions filled or an error for invalid
/// start position.
pub fn[T : Spanning] Runs::fill_buffer(
  self : Runs[T],
  start : Int,
  buffer : Array[T],
) -> Result[Int, RleError] {
  let total = self.span()
  if start < 0 {
    return Err(PositionOutOfBounds(position=start, length=total))
  }
  if buffer.length() == 0 || start >= total {
    return Ok(0)
  }
  let pos = match self.find(start) {
    Some(pos) => pos
    None => return Ok(0)
  }
  let mut run_idx = pos.run
  let mut offset = pos.offset
  let mut filled = 0
  let buf_len = buffer.length()
  while filled < buf_len && run_idx < self.length() {
    let run = self.get(run_idx).unwrap()
    let remaining_in_run = run.span() - offset
    let to_fill = if remaining_in_run < buf_len - filled {
      remaining_in_run
    } else {
      buf_len - filled
    }
    for i = 0; i < to_fill; i = i + 1 {
      buffer[filled + i] = run
    }
    filled = filled + to_fill
    run_idx = run_idx + 1
    offset = 0
  }
  Ok(filled)
}
```

- [ ] **Step 4: Run tests**

Run: `moon check && moon test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/runs.mbt src/runs_test.mbt
git commit -m "Add Runs::fill_buffer for bulk sequential reads"
```

---

## Task 3: Rle::fill_buffer and fill_buffer_interpolated

**Files:**
- Modify: `src/rle.mbt`
- Modify: `src/rle_test.mbt`

- [ ] **Step 1: Write failing tests**

In `src/rle_test.mbt`:

```moonbit
///|
test "Rle::fill_buffer fills across runs" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
  ])
  let buf = Array::make(6, { value: 0.0, len: 0 } as ConstantSegment)
  let result = rle.fill_buffer(0, buf)
  inspect(result, content="Ok(6)")
  inspect(buf[2].value, content="1")
  inspect(buf[3].value, content="2")
}

///|
test "Rle::fill_buffer negative start returns error" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = rle.fill_buffer(-1, buf)
  inspect(
    result,
    content="Err(PositionOutOfBounds(position=-1, length=5))",
  )
}

///|
test "Rle::fill_buffer_interpolated constant segments" {
  let rle = @rle.Rle::from_array([
    { value: 0.5, len: 5 } as ConstantSegment,
  ])
  let buf = Array::make(5, 0.0)
  let result = rle.fill_buffer_interpolated(0, buf)
  inspect(result, content="Ok(5)")
  inspect(buf[0], content="0.5")
  inspect(buf[4], content="0.5")
}

///|
test "Rle::fill_buffer_interpolated ramp segments" {
  let rle = @rle.Rle::from_array([
    { start: 0.0, end_: 1.0, len: 11 } as RampSegment,
  ])
  let buf = Array::make(11, 0.0)
  let result = rle.fill_buffer_interpolated(0, buf)
  inspect(result, content="Ok(11)")
  inspect(buf[0], content="0")
  inspect(buf[5], content="0.5")
  inspect(buf[10], content="1")
}

///|
test "Rle::fill_buffer_interpolated cross-run transition" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
  ])
  let buf = Array::make(6, 0.0)
  let result = rle.fill_buffer_interpolated(0, buf)
  inspect(result, content="Ok(6)")
  inspect(buf[2], content="1")
  inspect(buf[3], content="2")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Implement shared traversal helper and fill methods**

In `src/rle.mbt`, add a shared private traversal helper that both
`fill_buffer` and `fill_buffer_interpolated` use:

```moonbit
///|
/// Shared traversal helper for fill operations. Walks runs from a starting
/// RunPos, calling `writer(buffer_index, run, offset_in_run)` for each
/// position. Returns the count of positions visited.
fn[T : Spanning] fill_traverse(
  runs : Runs[T],
  start_pos : RunPos,
  count : Int,
  writer : (Int, T, Int) -> Unit,
) -> Int {
  let mut run_idx = start_pos.run
  let mut offset = start_pos.offset
  let mut filled = 0
  while filled < count && run_idx < runs.length() {
    let run = runs.get(run_idx).unwrap()
    let remaining_in_run = run.span() - offset
    let to_fill = if remaining_in_run < count - filled {
      remaining_in_run
    } else {
      count - filled
    }
    for i = 0; i < to_fill; i = i + 1 {
      writer(filled + i, run, offset + i)
    }
    filled = filled + to_fill
    run_idx = run_idx + 1
    offset = 0
  }
  filled
}

///|
/// Fill `buffer` with run objects at consecutive positions starting from
/// `start`. Returns the number of positions filled or an error.
pub fn[T : Spanning] Rle::fill_buffer(
  self : Rle[T],
  start : Int,
  buffer : Array[T],
) -> Result[Int, RleError] {
  let sums = self.ensure_prefix()
  let total = sums.span()
  if start < 0 {
    return Err(PositionOutOfBounds(position=start, length=total))
  }
  if buffer.length() == 0 || start >= total {
    return Ok(0)
  }
  let pos = match self.runs.find_fast(sums, start) {
    Some(pos) => pos
    None => return Ok(0)
  }
  let filled = fill_traverse(self.runs, pos, buffer.length(), fn(i, run, _offset) {
    buffer[i] = run
  })
  Ok(filled)
}

///|
/// Fill `buffer` with interpolated Double values at consecutive positions.
pub fn[T : Interpolatable] Rle::fill_buffer_interpolated(
  self : Rle[T],
  start : Int,
  buffer : Array[Double],
) -> Result[Int, RleError] {
  let sums = self.ensure_prefix()
  let total = sums.span()
  if start < 0 {
    return Err(PositionOutOfBounds(position=start, length=total))
  }
  if buffer.length() == 0 || start >= total {
    return Ok(0)
  }
  let pos = match self.runs.find_fast(sums, start) {
    Some(pos) => pos
    None => return Ok(0)
  }
  let filled = fill_traverse(self.runs, pos, buffer.length(), fn(i, run, offset) {
    buffer[i] = run.interpolate(offset)
  })
  Ok(filled)
}
```

- [ ] **Step 4: Run tests**

Run: `moon check && moon test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/rle.mbt src/rle_test.mbt
git commit -m "Add Rle::fill_buffer and fill_buffer_interpolated with shared traversal"
```

---

## Task 4: RleCursor::fill_buffer and fill_buffer_interpolated

**Files:**
- Modify: `src/rle_cursor.mbt`
- Modify: `src/rle_test.mbt`

- [ ] **Step 1: Write failing tests**

In `src/rle_test.mbt`:

```moonbit
///|
test "RleCursor::fill_buffer sequential blocks" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
  ])
  let cursor = rle.cursor()
  let buf1 = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result1 = cursor.fill_buffer(buf1)
  inspect(result1, content="Some(3)")
  inspect(buf1[0].value, content="1")
  let buf2 = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result2 = cursor.fill_buffer(buf2)
  inspect(result2, content="Some(3)")
  inspect(buf2[0].value, content="2")
}

///|
test "RleCursor::fill_buffer returns None when stale" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let cursor = rle.cursor()
  let _ = rle.append({ value: 2.0, len: 3 } as ConstantSegment)
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = cursor.fill_buffer(buf)
  inspect(result, content="None")
}

///|
test "RleCursor::fill_buffer at end returns Some(0)" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
  ])
  let cursor = rle.cursor()
  let _ = cursor.seek(3)  // at end
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let result = cursor.fill_buffer(buf)
  inspect(result, content="Some(0)")
}

///|
test "RleCursor::fill_buffer partial at end" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 3 } as ConstantSegment,
  ])
  let cursor = rle.cursor()
  let buf = Array::make(5, { value: 0.0, len: 0 } as ConstantSegment)
  let result = cursor.fill_buffer(buf)
  inspect(result, content="Some(3)")
}

///|
test "RleCursor::fill_buffer stale leaves position unchanged" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
  ])
  let cursor = rle.cursor()
  let _ = cursor.advance(2)
  let pos_before = cursor.position()
  let _ = rle.append({ value: 2.0, len: 3 } as ConstantSegment)
  let buf = Array::make(3, { value: 0.0, len: 0 } as ConstantSegment)
  let _ = cursor.fill_buffer(buf)
  // Position should be unchanged (still reports via the stale version)
  // Actually, position() itself returns None when stale
  inspect(cursor.position(), content="None")
  inspect(pos_before, content="Some(2)")
}

///|
test "RleCursor::fill_buffer_interpolated" {
  let rle = @rle.Rle::from_array([
    { start: 0.0, end_: 1.0, len: 11 } as RampSegment,
  ])
  let cursor = rle.cursor()
  let buf = Array::make(11, 0.0)
  let result = cursor.fill_buffer_interpolated(buf)
  inspect(result, content="Some(11)")
  inspect(buf[0], content="0")
  inspect(buf[5], content="0.5")
  inspect(buf[10], content="1")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — cursor fill methods not defined.

- [ ] **Step 3: Implement cursor fill methods**

In `src/rle_cursor.mbt`:

```moonbit
///|
/// Fill `buffer` with run objects from the cursor's current position.
/// Advances the cursor by the count filled. Returns None if stale.
pub fn[T : Spanning] RleCursor::fill_buffer(
  self : RleCursor[T],
  buffer : Array[T],
) -> MayStale[Int] {
  if self.is_stale() {
    return None
  }
  if buffer.length() == 0 {
    return Some(0)
  }
  let runs = self.rle.runs
  let mut filled = 0
  let buf_len = buffer.length()
  let mut run_idx = self.run_index
  let mut offset = self.offset_in_run
  while filled < buf_len && run_idx < runs.length() {
    let run = runs.get(run_idx).unwrap()
    let remaining = run.span() - offset
    let to_fill = if remaining < buf_len - filled {
      remaining
    } else {
      buf_len - filled
    }
    for i = 0; i < to_fill; i = i + 1 {
      buffer[filled + i] = run
    }
    filled = filled + to_fill
    offset = offset + to_fill
    if offset >= run.span() {
      run_idx = run_idx + 1
      offset = 0
    }
  }
  self.run_index = run_idx
  self.offset_in_run = offset
  self.global_offset = self.global_offset + filled
  Some(filled)
}

///|
/// Fill `buffer` with interpolated Double values from the cursor's current
/// position. Advances the cursor by the count filled. Returns None if stale.
pub fn[T : Interpolatable] RleCursor::fill_buffer_interpolated(
  self : RleCursor[T],
  buffer : Array[Double],
) -> MayStale[Int] {
  if self.is_stale() {
    return None
  }
  if buffer.length() == 0 {
    return Some(0)
  }
  let runs = self.rle.runs
  let mut filled = 0
  let buf_len = buffer.length()
  let mut run_idx = self.run_index
  let mut offset = self.offset_in_run
  while filled < buf_len && run_idx < runs.length() {
    let run = runs.get(run_idx).unwrap()
    let remaining = run.span() - offset
    let to_fill = if remaining < buf_len - filled {
      remaining
    } else {
      buf_len - filled
    }
    for i = 0; i < to_fill; i = i + 1 {
      buffer[filled + i] = run.interpolate(offset + i)
    }
    filled = filled + to_fill
    offset = offset + to_fill
    if offset >= run.span() {
      run_idx = run_idx + 1
      offset = 0
    }
  }
  self.run_index = run_idx
  self.offset_in_run = offset
  self.global_offset = self.global_offset + filled
  Some(filled)
}
```

- [ ] **Step 4: Run tests**

Run: `moon check && moon test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/rle_cursor.mbt src/rle_test.mbt
git commit -m "Add RleCursor::fill_buffer and fill_buffer_interpolated"
```

---

## Task 5: QuickCheck Property Tests

**Files:**
- Modify: `src/runs_properties_test.mbt`

- [ ] **Step 1: Write property tests**

In `src/runs_properties_test.mbt`, add properties using the existing
QuickCheck setup. The property tests should use `ConstantSegment` or a
similar type. Check how the existing arbitrary generators work in
`src/arbitrary.mbt` and follow the same pattern.

Key properties:
1. `fill_buffer(start, buf)` for each position i in 0..count:
   `buf[i]` should equal the run at `value_at(start + i)`
2. `fill_buffer` count is always `<= buffer.length()` and `>= 0`
3. Cursor sequential fills match one contiguous fill

Note: Implementing custom `Arbitrary` for `ConstantSegment` or `RampSegment`
may be needed. Read `src/arbitrary.mbt` first to understand the pattern.

If QuickCheck integration is too complex for these custom types, write
manual deterministic property-like tests instead (loop over positions,
compare fill_buffer vs value_at).

```moonbit
///|
test "property: fill_buffer matches value_at for every position" {
  // Deterministic property test
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
    { value: 3.0, len: 4 } as ConstantSegment,
  ])
  let total = rle.span()
  let buf = Array::make(total, { value: 0.0, len: 0 } as ConstantSegment)
  let count = rle.fill_buffer(0, buf).unwrap()
  assert_eq(count, total)
  for i = 0; i < total; i = i + 1 {
    let expected = rle.value_at(i).unwrap()
    assert_eq(buf[i].value, expected.value)
  }
}

///|
test "property: cursor sequential fill matches contiguous fill" {
  let rle = @rle.Rle::from_array([
    { value: 1.0, len: 5 } as ConstantSegment,
    { value: 2.0, len: 3 } as ConstantSegment,
    { value: 3.0, len: 4 } as ConstantSegment,
  ])
  let total = rle.span()
  // Contiguous fill
  let big_buf = Array::make(total, { value: 0.0, len: 0 } as ConstantSegment)
  let _ = rle.fill_buffer(0, big_buf)
  // Sequential cursor fills of size 4
  let cursor = rle.cursor()
  let mut offset = 0
  while offset < total {
    let chunk_size = if total - offset < 4 { total - offset } else { 4 }
    let chunk = Array::make(chunk_size, { value: 0.0, len: 0 } as ConstantSegment)
    let count = cursor.fill_buffer(chunk).unwrap()
    for i = 0; i < count; i = i + 1 {
      assert_eq(chunk[i].value, big_buf[offset + i].value)
    }
    offset = offset + count
    if count == 0 { break }
  }
}
```

- [ ] **Step 2: Run tests**

Run: `moon test`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add src/runs_properties_test.mbt
git commit -m "Add property tests for fill_buffer consistency"
```

---

## Task 6: Integration Test and Documentation

**Files:**
- Modify: `src/rle_test.mbt`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Write integration test**

In `src/rle_test.mbt`:

```moonbit
///|
test "integration: fill_buffer_interpolated on multi-ramp timeline" {
  // Simulate a parameter automation timeline:
  // Ramp from 200 to 400 over 10 positions, then constant 400 for 5 positions
  let rle = @rle.Rle::from_array([
    { start: 200.0, end_: 400.0, len: 10 } as RampSegment,
    { value: 400.0, len: 5 } as ConstantSegment,
  ])
  let buf = Array::make(15, 0.0)
  let result = rle.fill_buffer_interpolated(0, buf)
  inspect(result, content="Ok(15)")
  // Ramp: position 0 = 200, position 9 = 400
  inspect(buf[0], content="200")
  inspect(buf[9], content="400")
  // Constant: positions 10-14 = 400
  inspect(buf[10], content="400")
  inspect(buf[14], content="400")
}
```

- [ ] **Step 2: Run test**

Run: `moon test`
Expected: Pass.

- [ ] **Step 3: Update ARCHITECTURE.md**

Read `docs/ARCHITECTURE.md` and add `Interpolatable` to the trait
documentation. Change "six traits" to "seven traits" if that phrase appears.
Add a brief description of `Interpolatable` in the trait table/list.

Also add `fill_buffer` and `fill_buffer_interpolated` to the operations
summary if one exists.

- [ ] **Step 4: Final dev workflow**

Run: `moon info && moon fmt`
Check all `.mbti` diffs — new public API should include `Interpolatable`,
`fill_buffer`, `fill_buffer_interpolated`.

- [ ] **Step 5: Commit**

```bash
git add src/rle_test.mbt docs/ARCHITECTURE.md src/pkg.generated.mbti
git commit -m "Add integration test and document Interpolatable in architecture"
```
