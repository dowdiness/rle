# Trait-Enabled Generic Algorithms Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two traits (`FromRange`, `Addressable`) and three methods (`each_with_position`, `from_sorted_ints`, `iter_units`) to the rle library.

**Architecture:** Traits go in the foundation layer (`traits.mbt`). `from_sorted_ints` core logic lives at `Runs` layer with `Rle` wrapper. `each_with_position` and `iter_units` live at `Rle` layer (they depend on prefix sums). TDD: write failing tests first, then implement.

**Tech Stack:** MoonBit, `moon check`, `moon test`, `moonbitlang/quickcheck`

**Spec:** `docs/plans/2026-03-15-trait-algorithms-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `src/traits.mbt` | Add `FromRange` and `Addressable` trait definitions (append after existing traits) |
| `src/runs.mbt` | Add `Runs::from_sorted_ints` (append after `from_array`) |
| `src/rle.mbt` | Add `Rle::from_sorted_ints`, `each_with_position`, `iter_units` (append after `from_runs`) |
| `src/rle_test.mbt` | Blackbox tests for all new methods |
| `src/runs_wbtest.mbt` | Whitebox invariant tests for `from_sorted_ints` |
| `src/runs_properties_test.mbt` | QuickCheck round-trip property tests |
| `docs/ARCHITECTURE.md` | Update trait table and method listings |

No new files created. No new dependencies.

---

## Chunk 1: Test helper type + Traits

We need a test helper type that implements `FromRange + Addressable + Spanning + Mergeable` for blackbox tests. The benchmark file already shows this pattern with `BenchRun`. We'll define an equivalent `TestRange` in the test file.

### Task 1: Add `FromRange` and `Addressable` traits

**Files:**
- Modify: `src/traits.mbt` (append after line 122)

- [ ] **Step 1: Write the trait definitions**

Append to `src/traits.mbt` after the `Spanning` defaults:

```moonbit
///|
/// **FromRange** — construct a run value from an integer range `[start, start+count)`.
///
/// Consumers decide what to do with `start`:
/// - Index-carrying types store it: `LvRange { start, count }`
/// - Index-free types discard it: `DenseRun { count }`
///
/// Used by `Rle::from_sorted_ints` and `Runs::from_sorted_ints` to construct
/// runs from groups of consecutive integers.
pub(open) trait FromRange {
  from_range(start : Int, count : Int) -> Self
}

///|
/// **Addressable** — map a position within a run to a domain integer value.
///
/// `global_start` is the run's start position derived from prefix sums.
/// `offset` is 0-based within the run (`0 <= offset < span`).
///
/// Consumers decide the mapping:
/// - Index-carrying: `self.start + offset` (ignores `global_start`)
/// - Index-free: `global_start + offset` (derives from prefix sums)
///
/// Used by `Rle::iter_units` to expand compressed runs into individual integers.
pub(open) trait Addressable {
  address(Self, global_start : Int, offset : Int) -> Int
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: PASS (traits are defined but not used yet)

- [ ] **Step 3: Commit**

```bash
moon fmt && git add src/traits.mbt && git commit -m "feat: add FromRange and Addressable traits"
```

---

## Chunk 2: `each_with_position` + test helper type (TDD)

Test helper type `TestRange` is defined first since both `each_with_position` and later chunks need a multi-run type for meaningful tests.

### Task 2: Define test helper type, test and implement `each_with_position`

**Files:**
- Modify: `src/rle.mbt` (append new method)
- Modify: `src/rle_test.mbt` (append helper type + tests)

- [ ] **Step 1: Add test helper type and write failing blackbox tests**

Append to `src/rle_test.mbt`:

```moonbit
///|
/// Test helper: index-carrying range type for testing FromRange/Addressable.
/// Mirrors the spec's LvRange consumer example.
priv struct TestRange {
  start : Int
  count : Int
} derive(Show, Eq)

///|
impl @rle.FromRange for TestRange with from_range(start, count) {
  { start, count }
}

///|
impl @rle.Addressable for TestRange with address(self, _global_start, offset) {
  self.start + offset
}

///|
impl @rle.HasLength for TestRange with length(self) {
  self.count
}

///|
impl @rle.Spanning for TestRange with span(self) {
  self.count
}

///|
impl @rle.Mergeable for TestRange with can_merge(a, b) {
  a.start + a.count == b.start
}

///|
impl @rle.Mergeable for TestRange with merge(a, b) {
  { start: a.start, count: a.count + b.count }
}

///|
/// Test helper: index-free dense run type. Tests the global_start + offset path.
priv struct DenseTestRun {
  count : Int
} derive(Show, Eq)

///|
impl @rle.FromRange for DenseTestRun with from_range(_start, count) {
  { count }
}

///|
impl @rle.Addressable for DenseTestRun with address(
  _self,
  global_start,
  offset
) {
  global_start + offset
}

///|
impl @rle.HasLength for DenseTestRun with length(self) {
  self.count
}

///|
impl @rle.Spanning for DenseTestRun with span(self) {
  self.count
}

///|
impl @rle.Mergeable for DenseTestRun with can_merge(_a, _b) {
  true
}

///|
impl @rle.Mergeable for DenseTestRun with merge(a, b) {
  { count: a.count + b.count }
}

///|
test "Rle::each_with_position on empty" {
  let rle : @rle.Rle[String] = @rle.Rle::new()
  let positions : Array[(String, Int, Int)] = []
  rle.each_with_position(fn(run, start, end) {
    positions.push((run, start, end))
  })
  inspect(positions.length(), content="0")
}

///|
test "Rle::each_with_position single run" {
  let rle = @rle.Rle::from_string("hello")
  let positions : Array[(String, Int, Int)] = []
  rle.each_with_position(fn(run, start, end) {
    positions.push((run, start, end))
  })
  inspect(positions.length(), content="1")
  inspect(positions[0].0, content="hello")
  inspect(positions[0].1, content="0")
  inspect(positions[0].2, content="5")
}

///|
test "Rle::each_with_position multiple runs (TestRange)" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_array(
    [{ start: 0, count: 3 }, { start: 5, count: 3 }],
  )
  let positions : Array[(Int, Int)] = []
  rle.each_with_position(fn(_run, start, end) {
    positions.push((start, end))
  })
  inspect(positions.length(), content="2")
  inspect(positions[0], content="(0, 3)")
  inspect(positions[1], content="(3, 6)")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `each_with_position` not defined

- [ ] **Step 3: Implement `each_with_position`**

Append to `src/rle.mbt` after `Rle::from_runs` (around line 52):

```moonbit
///|
/// Iterate runs with their start and end positions derived from prefix sums.
///
/// Yields `(run_value, start_position, end_position)` for each run.
/// Calls `ensure_prefix()` once, then iterates the runs array.
/// This is the building block for `iter_units` and consumer-defined algorithms.
pub fn[T : Spanning] Rle::each_with_position(
  self : Rle[T],
  f : (T, Int, Int) -> Unit,
) -> Unit {
  let prefix = self.ensure_prefix()
  for i = 0; i < self.runs.0.length(); i = i + 1 {
    let run = self.runs.0[i]
    let start = prefix.span_before(i)
    let end = prefix.spans[i]
    f(run, start, end)
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `moon test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
moon fmt && git add src/rle.mbt src/rle_test.mbt && git commit -m "feat: add Rle::each_with_position with test helper types"
```

---

## Chunk 3: `from_sorted_ints` (TDD)

### Task 3: Write failing tests for `from_sorted_ints`

**Files:**
- Modify: `src/rle_test.mbt` (append tests — `TestRange` already defined in Chunk 2)

- [ ] **Step 1: Write failing tests**

Append to `src/rle_test.mbt`:

```moonbit
///|
test "Rle::from_sorted_ints empty input" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([])
  inspect(rle.is_empty(), content="true")
}

///|
test "Rle::from_sorted_ints single element" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([5])
  inspect(rle.length(), content="1")
  inspect(rle.span(), content="1")
}

///|
test "Rle::from_sorted_ints consecutive" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([0, 1, 2, 3, 4])
  // All consecutive → one run via from_array_batch merge
  inspect(rle.length(), content="1")
  inspect(rle.span(), content="5")
}

///|
test "Rle::from_sorted_ints with gaps" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([0, 1, 2, 5, 6, 7])
  // Two groups: [0,1,2] and [5,6,7]
  inspect(rle.length(), content="2")
  inspect(rle.span(), content="6")
}

///|
test "Rle::from_sorted_ints skips duplicates" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([1, 1, 2, 3, 3])
  // After dedup: [1, 2, 3] → one run
  inspect(rle.length(), content="1")
  inspect(rle.span(), content="3")
}

///|
test "Rle::from_sorted_ints duplicates across gap" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([1, 1, 2, 5, 5, 6])
  // After dedup: [1, 2] and [5, 6] → two runs
  inspect(rle.length(), content="2")
  inspect(rle.span(), content="4")
}

///|
test "Rle::from_sorted_ints all duplicates" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([5, 5, 5])
  // After dedup: [5] → one run with count 1
  inspect(rle.length(), content="1")
  inspect(rle.span(), content="1")
}

///|
test "Rle::from_sorted_ints dense run collapses (index-free)" {
  let rle : @rle.Rle[DenseTestRun] = @rle.Rle::from_sorted_ints([0, 1, 2, 3, 4])
  // DenseTestRun always merges → single run
  inspect(rle.length(), content="1")
  inspect(rle.span(), content="5")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `from_sorted_ints` not defined

### Task 4: Implement `Runs::from_sorted_ints` and `Rle::from_sorted_ints`

**Files:**
- Modify: `src/runs.mbt` (append after `from_array` at line 59)
- Modify: `src/rle.mbt` (append after `from_array` at line 46)

- [ ] **Step 1: Implement `Runs::from_sorted_ints`**

Append to `src/runs.mbt` after `Runs::from_array`:

```moonbit
///|
/// Construct Runs from a sorted array of integers.
///
/// Groups consecutive integers into runs via `FromRange`, then feeds
/// them through `from_array_batch` for stack-merge normalization.
///
/// **Deduplication contract:** Duplicate values in the input are silently
/// skipped. This is a stated guarantee, not incidental behavior — CRDT
/// consumers (e.g. graph_diff output from hashset-derived arrays) rely on it.
///
/// **Sortedness:** Assumes input is sorted (ascending). Non-sorted input
/// produces unspecified (not incorrect) grouping.
///
/// Precondition: `ints[i-1] + 1` must not overflow `Int` for any `i`.
pub fn[T : FromRange + Spanning + Mergeable] Runs::from_sorted_ints(
  ints : Array[Int],
) -> Runs[T] {
  if ints.is_empty() {
    return Runs::new()
  }
  let groups : Array[T] = []
  let mut group_start = ints[0]
  let mut group_count = 1
  for i = 1; i < ints.length(); i = i + 1 {
    let cur = ints[i]
    if cur == ints[i - 1] {
      // Duplicate — skip
      continue
    }
    if cur == ints[i - 1] + 1 {
      // Consecutive — extend group
      group_count = group_count + 1
    } else {
      // Gap — emit current group, start new one
      groups.push(FromRange::from_range(group_start, group_count))
      group_start = cur
      group_count = 1
    }
  }
  // Emit final group
  groups.push(FromRange::from_range(group_start, group_count))
  Runs::from_array_batch(groups)
}
```

- [ ] **Step 2: Implement `Rle::from_sorted_ints`**

Append to `src/rle.mbt` after `Rle::from_array`:

```moonbit
///|
/// Construct an Rle from a sorted array of integers.
///
/// Groups consecutive integers into runs via `FromRange`, then normalizes
/// with stack-merge. See `Runs::from_sorted_ints` for deduplication and
/// sortedness contracts.
pub fn[T : FromRange + Spanning + Mergeable] Rle::from_sorted_ints(
  ints : Array[Int],
) -> Rle[T] {
  { runs: Runs::from_sorted_ints(ints), prefix: None, version: 0 }
}
```

- [ ] **Step 3: Run `moon check`**

Run: `moon check`
Expected: PASS

- [ ] **Step 4: Run tests**

Run: `moon test`
Expected: PASS — all `from_sorted_ints` tests green

- [ ] **Step 5: Commit**

```bash
moon fmt && git add src/runs.mbt src/rle.mbt src/rle_test.mbt && git commit -m "feat: add from_sorted_ints constructor"
```

---

## Chunk 4: `iter_units` (TDD)

### Task 5: Test and implement `iter_units`

**Files:**
- Modify: `src/rle.mbt` (append new method)
- Modify: `src/rle_test.mbt` (append tests)

- [ ] **Step 1: Write failing blackbox tests**

Append to `src/rle_test.mbt`:

```moonbit
///|
test "Rle::iter_units empty" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([])
  let units = rle.iter_units().collect()
  inspect(units.length(), content="0")
}

///|
test "Rle::iter_units consecutive" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([0, 1, 2, 3, 4])
  let units = rle.iter_units().collect()
  inspect(units, content="[0, 1, 2, 3, 4]")
}

///|
test "Rle::iter_units with gaps" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([0, 1, 2, 5, 6, 7])
  let units = rle.iter_units().collect()
  inspect(units, content="[0, 1, 2, 5, 6, 7]")
}

///|
test "Rle::iter_units single element" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([42])
  let units = rle.iter_units().collect()
  inspect(units, content="[42]")
}

///|
test "Rle::iter_units with duplicates in input" {
  let rle : @rle.Rle[TestRange] = @rle.Rle::from_sorted_ints([1, 1, 2, 5, 5, 6])
  let units = rle.iter_units().collect()
  inspect(units, content="[1, 2, 5, 6]")
}

///|
test "Rle::iter_units index-free (DenseTestRun)" {
  let rle : @rle.Rle[DenseTestRun] = @rle.Rle::from_sorted_ints([0, 1, 2, 3, 4])
  // DenseTestRun uses global_start + offset path
  let units = rle.iter_units().collect()
  inspect(units, content="[0, 1, 2, 3, 4]")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `moon test`
Expected: FAIL — `iter_units` not defined

- [ ] **Step 3: Implement `iter_units`**

Append to `src/rle.mbt` after `each_with_position`:

```moonbit
///|
/// Expand each run into individual domain integer values.
///
/// Uses prefix sums to derive `global_start` for each run, then calls
/// `Addressable::address` for each offset `0..span-1` within the run.
///
/// **Complexity:** O(total_span) — yields every unit position.
pub fn[T : Addressable + Spanning] Rle::iter_units(
  self : Rle[T],
) -> Iter[Int] {
  let prefix = self.ensure_prefix()
  let items = self.runs.0
  let total_runs = items.length()
  let mut run_idx = 0
  let mut offset = 0
  Iter::new(fn() {
    while run_idx < total_runs {
      let run = items[run_idx]
      let run_span = T::span(run)
      if offset < run_span {
        let global_start = prefix.span_before(run_idx)
        let value = T::address(run, global_start, offset)
        offset = offset + 1
        return Some(value)
      }
      run_idx = run_idx + 1
      offset = 0
    }
    None
  })
}
```

- [ ] **Step 4: Run tests**

Run: `moon test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
moon fmt && git add src/rle.mbt src/rle_test.mbt && git commit -m "feat: add Rle::iter_units"
```

---

## Chunk 5: Whitebox invariant tests + Property tests

### Task 6: Add whitebox tests for `from_sorted_ints` invariants

**Files:**
- Modify: `src/runs_wbtest.mbt` (append tests)

- [ ] **Step 1: Write whitebox invariant tests**

Append to `src/runs_wbtest.mbt`:

```moonbit
///|
/// Whitebox test helper: index-carrying range for testing FromRange.
priv struct WbRange {
  start : Int
  count : Int
} derive(Show, Eq)

///|
impl FromRange for WbRange with from_range(start, count) {
  { start, count }
}

///|
impl HasLength for WbRange with length(self) {
  self.count
}

///|
impl Spanning for WbRange with span(self) {
  self.count
}

///|
impl Mergeable for WbRange with can_merge(a, b) {
  a.start + a.count == b.start
}

///|
impl Mergeable for WbRange with merge(a, b) {
  { start: a.start, count: a.count + b.count }
}

///|
test "invariant: from_sorted_ints no adjacent mergeable runs" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7, 10])
  // Verify no adjacent runs are mergeable
  for i = 0; i < runs.0.length() - 1; i = i + 1 {
    inspect(
      Mergeable::can_merge(runs.0[i], runs.0[i + 1]),
      content="false",
    )
  }
}

///|
test "invariant: from_sorted_ints no zero-span runs" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7])
  for item in runs.0 {
    inspect(Spanning::span(item) > 0, content="true")
  }
}

///|
test "invariant: from_sorted_ints groups have correct starts" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7])
  inspect(runs.0.length(), content="2")
  inspect(runs.0[0].start, content="0")
  inspect(runs.0[0].count, content="3")
  inspect(runs.0[1].start, content="5")
  inspect(runs.0[1].count, content="3")
}

///|
test "invariant: from_sorted_ints dedup produces correct groups" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([1, 1, 1, 2, 3, 5, 5])
  inspect(runs.0.length(), content="2")
  inspect(runs.0[0].start, content="1")
  inspect(runs.0[0].count, content="3")
  inspect(runs.0[1].start, content="5")
  inspect(runs.0[1].count, content="1")
}
```

- [ ] **Step 2: Run tests**

Run: `moon test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
moon fmt && git add src/runs_wbtest.mbt && git commit -m "test: whitebox invariant tests for from_sorted_ints"
```

### Task 7: Add property-based round-trip test

**Files:**
- Modify: `src/runs_properties_test.mbt` (append test)

The round-trip property: for any strictly-sorted array of non-negative integers, `from_sorted_ints` → `iter_units` → collect should yield the original array.

We need a QuickCheck generator for strictly sorted arrays. Since `@qc.quick_check_fn` generates the input type directly, we generate an `Array[Int]` and transform it into strictly sorted form.

- [ ] **Step 1: Write property test**

Append to `src/runs_properties_test.mbt`:

```moonbit
///|
/// Property test helper: index-carrying range.
priv struct PropRange {
  start : Int
  count : Int
} derive(Show, Eq)

///|
impl @rle.FromRange for PropRange with from_range(start, count) {
  { start, count }
}

///|
impl @rle.Addressable for PropRange with address(self, _global_start, offset) {
  self.start + offset
}

///|
impl @rle.HasLength for PropRange with length(self) {
  self.count
}

///|
impl @rle.Spanning for PropRange with span(self) {
  self.count
}

///|
impl @rle.Mergeable for PropRange with can_merge(a, b) {
  a.start + a.count == b.start
}

///|
impl @rle.Mergeable for PropRange with merge(a, b) {
  { start: a.start, count: a.count + b.count }
}

///|
/// Property: from_sorted_ints → iter_units round-trip preserves values.
/// Takes arbitrary non-negative ints, sorts and deduplicates, then verifies round-trip.
fn prop_from_sorted_iter_roundtrip(raw : Array[Int]) -> Bool {
  // Transform to strictly sorted non-negative ints
  let filtered = raw.filter(fn(x) { x >= 0 && x < 10000 })
  let sorted = filtered.copy()
  sorted.sort()
  // Deduplicate
  let deduped : Array[Int] = []
  for v in sorted {
    match deduped.last() {
      Some(prev) => if v != prev { deduped.push(v) }
      None => deduped.push(v)
    }
  }
  let rle : @rle.Rle[PropRange] = @rle.Rle::from_sorted_ints(deduped)
  let result = rle.iter_units().collect()
  result == deduped
}

///|
test "property: from_sorted_ints → iter_units round-trip" {
  @qc.quick_check_fn(prop_from_sorted_iter_roundtrip)
}
```

- [ ] **Step 2: Run tests**

Run: `moon test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
moon fmt && git add src/runs_properties_test.mbt && git commit -m "test: property test for from_sorted_ints/iter_units round-trip"
```

---

## Chunk 6: Update interfaces and documentation

### Task 8: Update `.mbti` interface and format

**Files:**
- Modify: `src/pkg.generated.mbti` (auto-generated)
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Run `moon info` to update `.mbti`**

Run: `moon info`
Expected: `src/pkg.generated.mbti` updated with new trait and method signatures

- [ ] **Step 2: Run `moon fmt`**

Run: `moon fmt`
Expected: All files formatted

- [ ] **Step 3: Verify API surface**

Run: `git diff src/pkg.generated.mbti`
Expected: New entries for `FromRange`, `Addressable`, `each_with_position`, `from_sorted_ints`, `iter_units`

- [ ] **Step 4: Update `docs/ARCHITECTURE.md`**

In the traits table (around line 37), add two rows:

```markdown
| `FromRange` | `from_range(start, count)` | Constructors: `from_sorted_ints` |
| `Addressable` | `address(global_start, offset)` | Expansion: `iter_units` |
```

In the "Key operations" section for `Runs[T]` (around line 52), add:

```markdown
- `from_sorted_ints(ints)` — O(n) grouping + stack-merge, requires `FromRange`
```

In the "Key operations" section for `Rle[T]`, add:

```markdown
- `from_sorted_ints(ints)` — wraps `Runs` version
- `each_with_position(f)` — per-run iteration with prefix-sum-derived positions
- `iter_units()` — expand runs to individual integers, requires `Addressable`
```

- [ ] **Step 5: Run full test suite**

Run: `moon check && moon test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
moon fmt && git add src/pkg.generated.mbti docs/ARCHITECTURE.md && git commit -m "docs: update API surface and architecture for trait-enabled algorithms"
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] `moon check` passes
- [ ] `moon test` passes (all new + existing tests)
- [ ] `moon info && moon fmt` produces no changes (already formatted)
- [ ] `git diff *.mbti` shows only the expected new API entries
- [ ] No existing tests broken
- [ ] No changes to existing method signatures
