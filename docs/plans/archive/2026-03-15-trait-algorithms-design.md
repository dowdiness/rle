# Trait-Enabled Generic Algorithms Design

**Date**: 2026-03-15
**Status**: Draft

## Problem

The RLE library needs to support two downstream consumers with different data models:

1. **CRDT project** (`dowdiness/crdt`) — compresses sorted integer arrays (Lamport versions) into ranges. Needs `from_sorted_ints`, `iter_units`, and a range type with position-dependent mergeability.
2. **loom parser** (`dowdiness/loom`) — compresses consecutive trivia tokens (whitespace, newlines) in CST children arrays. Needs O(log n) child lookup by byte offset. Uses intrinsic mergeability (same token kind).

The original proposal was to ship a concrete `IntRange { start, count }` type in the library. This violates the library's context-freedom property: storing absolute positions inside runs creates the "Position Fixup" anti-pattern (see `crdt/docs/architecture/anamorphism-discipline.md` §3). Mergeability for integer ranges is position-dependent — `can_merge(a, b) = a.start + a.count == b.start` — which the library cannot validate or enforce generically.

## Design Principle

**Algorithm-by-trait**: ship **traits** (vocabulary), not **types** (words). The library provides generic algorithms (`from_sorted_ints`, `iter_units`), and consumer types provide the behavior by implementing the traits — just as `Compare` lets you write a generic sort without knowing the element type.

The library never looks inside trait implementations. Whether a consumer stores positions internally (CRDT's `LvRange`) or derives them from prefix sums (loom's `CstElement`) is invisible to the library. Context-freedom is preserved at the library boundary.

## Additions

### New Traits

Two new traits in `traits.mbt`, below the existing four:

```moonbit
///| Construct a run value from an integer range [start, start+count).
///
/// Consumers decide what to do with `start`:
/// - Index-carrying types store it: `LvRange { start, count }`
/// - Index-free types discard it: `DenseRun { count }`
pub(open) trait FromRange {
  from_range(start : Int, count : Int) -> Self
}

///| Map a position within a run to a domain integer value.
///
/// `global_start` is the run's start position derived from prefix sums.
/// `offset` is 0-based within the run (0 <= offset < span).
///
/// Consumers decide the mapping:
/// - Index-carrying: `self.start + offset` (ignores global_start)
/// - Index-free: `global_start + offset` (derives from prefix sums)
pub(open) trait Addressable {
  address(Self, global_start : Int, offset : Int) -> Int
}
```

**Trait hierarchy** — `FromRange` and `Addressable` have no supertrait requirements. They are independent of `Spanning`, `Mergeable`, and `Sliceable`. The generic algorithms constrain them in combination:

```text
Existing:  HasLength ← Spanning    Mergeable    Sliceable
New:       FromRange               Addressable
           (no parents)            (no parents)
```

### New Methods

Three methods. Each requires a specific trait combination and uses the library's existing infrastructure.

#### 1. `each_with_position` — per-run iteration with prefix-sum positions

```moonbit
///| Iterate runs with their start and end positions derived from prefix sums.
///
/// Yields (run_value, start_position, end_position) for each run.
/// Calls ensure_prefix() once, then iterates the runs array.
pub fn[T : Spanning] Rle::each_with_position(
  self : Rle[T],
  f : (T, Int, Int) -> Unit,
) -> Unit
```

**Building block for `iter_units` and consumer-defined algorithms.** No new trait needed — only `Spanning` (already required for most operations).

**Algorithm:**

```text
0. Call ensure_prefix() to rebuild prefix sums if stale.
1. For each run at index i:
   start = prefix.span_before(i)
   end = prefix.spans[i]
   f(run, start, end)
```

#### 2. `from_sorted_ints` — group sorted integers into compressed runs

```moonbit
///| Core grouping algorithm at the Runs layer.
///
/// **Deduplication contract:** Duplicate values in the input are silently
/// skipped. This is a stated guarantee, not incidental behavior — CRDT
/// consumers (e.g. graph_diff output from hashset-derived arrays) rely on it.
///
/// **Sortedness:** Assumes input is sorted (ascending). In debug builds,
/// asserts `ints[i] >= ints[i-1]` for each i. Non-sorted input in release
/// builds produces unspecified (not incorrect) grouping.
///
/// Precondition: `ints[i-1] + 1` must not overflow Int for any i.
pub fn[T : FromRange + Spanning + Mergeable] Runs::from_sorted_ints(
  ints : Array[Int],
) -> Runs[T]

///| Convenience wrapper — delegates to Runs::from_sorted_ints, wraps in Rle.
///
/// Groups consecutive integers into runs via FromRange, then feeds
/// them through from_array_batch for stack-merge normalization.
/// See `Runs::from_sorted_ints` for deduplication and sortedness contracts.
pub fn[T : FromRange + Spanning + Mergeable] Rle::from_sorted_ints(
  ints : Array[Int],
) -> Rle[T]
```

**Algorithm:**

```text
1. Walk the sorted array, tracking group_start and group_count.
2. For each ints[i]:
   a. If ints[i] == ints[i-1], skip (deduplicate).
   b. If ints[i] != ints[i-1] + 1 (gap found):
      - Emit T::from_range(group_start, group_count)
      - Start new group: group_start = ints[i], group_count = 1
   c. Otherwise: group_count += 1
3. After the loop, emit the final group.
4. Feed all emitted runs into from_array_batch for stack-merge normalization.
```

Step 4 ensures the no-adjacent-mergeable-runs invariant. For types where `can_merge` is always true (dense runs), `from_array_batch` collapses everything into a single run. For types with position-dependent merging (LvRange), distinct groups remain separate because `can_merge` returns false across gaps.

**Complexity:** O(n) — single pass over input + O(m) `from_array_batch` where m = number of groups.

#### 3. `iter_units` — expand compressed runs into individual integers

```moonbit
///| Expand each run into individual domain integer values.
///
/// Uses prefix sums to derive global_start for each run, then calls
/// Addressable::address for each offset 0..span-1 within the run.
pub fn[T : Addressable + Spanning] Rle::iter_units(self : Rle[T]) -> Iter[Int]
```

**Algorithm:**

```text
0. Call ensure_prefix() to rebuild prefix sums if stale.
1. For each run at index i:
   global_start = prefix.span_before(i)
   for offset = 0 to span(run) - 1:
     yield T::address(run, global_start, offset)
```

**Complexity:** O(total_span) — yields every unit. This is inherently linear in the expanded size, which is the cost of expansion.

## Consumer Examples

### CRDT: LvRange (index-carrying)

```moonbit
struct LvRange { start : Int; count : Int }

impl FromRange for LvRange with from_range(start, count) { { start, count } }
impl Addressable for LvRange with address(self, _global_start, offset) {
  self.start + offset
}
impl HasLength for LvRange with length(self) { self.count }
impl Spanning for LvRange with span(self) { self.count }
impl Mergeable for LvRange with can_merge(a, b) { a.start + a.count == b.start }
impl Mergeable for LvRange with merge(a, b) { { start: a.start, count: a.count + b.count } }
impl Sliceable for LvRange with slice(self, start~, end~) {
  if start < 0 || end > self.count || start >= end {
    Err(InvalidRange(...))
  } else {
    Ok({ start: self.start + start, count: end - start })
  }
}
```

Usage:
```moonbit
let sorted_lvs = graph_diff(v1, v2)  // [0, 1, 2, 5, 6, 7]
let rle : Rle[LvRange] = Rle::from_sorted_ints(sorted_lvs)
// => Rle containing [{start:0, count:3}, {start:5, count:3}]

let units = rle.iter_units()
// => Iter yielding [0, 1, 2, 5, 6, 7]
```

`LvRange.start` is a Lamport version (domain identity), not an RLE position. Addressable ignores `global_start` — the domain value comes from the run itself. This is context-free in the domain: moving a `LvRange{start:5, count:3}` to a different array position doesn't change its identity.

### loom: CstElement (index-free, existing traits only)

```moonbit
// In loom — no FromRange or Addressable needed
impl Mergeable for CstElement with can_merge(a, b) {
  match (a, b) {
    (Token(a), Token(b)) => is_trivia(a.kind) && a.kind == b.kind
    _ => false
  }
}
impl HasLength for CstElement with length(self) { self.text_len() }
impl Spanning for CstElement with span(self) { self.text_len() }
```

Usage:
```moonbit
let children : Rle[CstElement] = Rle::from_array_batch(raw_children)
// Consecutive whitespace tokens compressed into runs

// O(log n) child lookup by byte offset (replaces linear scan)
match children.find(byte_offset) {
  Some(pos) => // pos.run = child index, pos.offset = offset within child
  None => // out of bounds
}

// Per-run iteration with byte positions
children.each_with_position(fn(element, start, end) {
  // start/end are byte offsets derived from prefix sums
  // No stored positions — context-free, reusable across edits
})
```

loom uses only `Spanning + Mergeable` (existing traits) plus `each_with_position` (new method). No `FromRange`, no `Addressable` — those are CRDT-specific.

### Dense integer sequence (index-free)

```moonbit
struct DenseRun { count : Int }

impl FromRange for DenseRun with from_range(_start, count) { { count } }
impl Addressable for DenseRun with address(self, global_start, offset) {
  global_start + offset
}
impl HasLength for DenseRun with length(self) { self.count }
impl Spanning for DenseRun with span(self) { self.count }
impl Mergeable for DenseRun with can_merge(_a, _b) { true }
impl Mergeable for DenseRun with merge(a, b) { { count: a.count + b.count } }
```

Usage:
```moonbit
let rle : Rle[DenseRun] = Rle::from_sorted_ints([0, 1, 2, 3, 4])
// => Single run: DenseRun { count: 5 }

rle.iter_units()
// => Iter yielding [0, 1, 2, 3, 4] via global_start + offset
```

For dense sequences, `FromRange` discards `start` and `Addressable` derives values from prefix sums. Everything is index-free. `can_merge` is always true, so `from_sorted_ints` on a dense sequence collapses to a single run — maximum compression.

## Anamorphism Discipline Audit

Applying the four laws from `crdt/docs/architecture/anamorphism-discipline.md`:

```
Boundary:     Raw data → Rle[T] (with new traits/methods)
Producer:     from_array_batch, append, from_sorted_ints (new)
Consumer:     find, value_at, range, cursor, each_with_position (new), iter_units (new)
Intermediate: Rle[T] — runs array + lazy prefix sums

Completeness:     pass — FromRange + Addressable form a round-trip.
                  Construct from integers, compress, expand back.
                  No information lost.
Context-freedom:  pass — library never reads run fields directly.
                  Positions come from prefix sums (global_start parameter),
                  not from stored fields. Whether a type stores positions
                  internally is the consumer's choice, invisible to the library.
Uniform errors:   pass — from_sorted_ints always produces structure
                  (empty input → empty Rle). No error channel.
Transparency:     pass — two traits, three methods. No hidden protocols.
                  Implement the traits, get the algorithms.
```

### Anti-pattern avoidance

| Anti-pattern | How avoided |
|---|---|
| Position Fixup | Library never stores positions. `global_start` is computed per-call from prefix sums. |
| Construction Protocol | No ordering requirement on trait implementations. `from_sorted_ints` handles grouping internally. |
| Type Split | `from_sorted_ints` always returns `Rle[T]`, never `Result`. Empty/invalid input produces empty structure. |
| Retrospective Diff | N/A — no diffing in the compression pipeline. |

## Trait Usage Matrix

| Trait | Required by | CRDT uses | loom uses |
|---|---|---|---|
| `HasLength` | everything | yes | yes |
| `Spanning` | queries, `each_with_position`, `iter_units` | yes | yes |
| `Mergeable` | mutations, `from_sorted_ints` | yes | yes |
| `Sliceable` | positional edits | yes | no |
| `FromRange` (new) | `from_sorted_ints` | yes | no |
| `Addressable` (new) | `iter_units` | yes | no |

Different consumers use different trait subsets. No consumer pays for traits it doesn't implement.

## File Changes

| File | Change |
|---|---|
| `src/traits.mbt` | Add `FromRange` and `Addressable` trait definitions |
| `src/runs.mbt` | Add `Runs::from_sorted_ints` (core grouping + `from_array_batch`) |
| `src/rle.mbt` | Add `Rle::from_sorted_ints` (wraps `Runs` version), `each_with_position`, `iter_units` |
| `src/rle_test.mbt` | Blackbox tests for new methods |
| `src/runs_wbtest.mbt` | Whitebox tests: verify no adjacent mergeable runs after `from_sorted_ints` |
| `src/runs_properties_test.mbt` | QuickCheck: `from_sorted_ints` → `iter_units` round-trip (strictly sorted input) |
| `docs/ARCHITECTURE.md` | Add traits to hierarchy table, document new methods |

No new files. No new packages. No new dependencies.

`from_sorted_ints` follows the existing pattern where the core algorithm lives at the `Runs` layer and `Rle` wraps it (matching `from_array` / `from_array_batch`).

## Invariants Preserved

- **No adjacent mergeable runs**: `from_sorted_ints` feeds groups through `from_array_batch`, which applies the stack-merge cascade. The invariant is restored automatically.
- **Lazy prefix sums**: `each_with_position` and `iter_units` call `ensure_prefix()` before iterating. No prefix rebuild during mutations.
- **Version bumping**: `from_sorted_ints` is a constructor (returns new `Rle`), not a mutation. No version bump needed. `each_with_position` and `iter_units` are read-only — no invalidation.

## What This Design Does NOT Include

- **No concrete `IntRange` type** — consumers define their own (LvRange, DenseRun, etc.)
- **No `from_sorted_ints` without `FromRange`** — the grouping algorithm requires construction
- **No `iter_units` without `Addressable`** — the expansion algorithm requires projection
- **No changes to existing traits** — `Spanning`, `Mergeable`, `Sliceable`, `HasLength` are unchanged
- **No changes to existing methods** — all current API remains intact
