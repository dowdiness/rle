# Architecture Reference

Detailed type descriptions, design rationale, algorithms, and file map for the RLE library. See [CLAUDE.md](../CLAUDE.md) for rules and constraints.

## Core Concept

The library stores sequences as an array of "runs" — adjacent elements that can be merged. A run-length encoded sequence of 1000 identical characters uses one run instead of 1000 individual values. Position lookup uses lazily-cached prefix sums for O(log n) binary search.

## Layering (strict bottom-up)

```text
Traits          Foundation trait definitions
  ↓
Errors          Error types (no dependencies on other layers)
  ↓
Runs ──→ Slice  Core run array; Slice is a simple view struct used by range()
  ↓
PrefixSums      Cumulative span/content arrays
  ↓
Rle             Caching wrapper (lazy prefix sums + version counter)
  ↓
RleCursor       Sequential traversal with staleness detection
```

Dependencies flow strictly downward. No circular or upward references.

## Core Types

### 1. Traits (`traits.mbt`)

Six traits govern what types can be stored in the RLE structure:

| Trait | Purpose | Required For |
|-------|---------|--------------|
| `HasLength` | Basic `length()` and `is_empty()` | Everything |
| `Spanning : HasLength` | `span()` and `logical_length()` | Queries: `find`, `span`, `range`, `value_at`, `cursor` |
| `Mergeable` | `can_merge()` and `merge()` | Mutations: `append`, `concat`, `extend`, `from_array` |
| `Sliceable` | `slice(start~, end~)` | Positional edits: `split`, `insert`, `delete`, `splice` |
| `FromRange` | `from_range(start, count)` | Constructors: `from_sorted_ints` |
| `Addressable` | `address(global_start, offset)` | Expansion: `iter_units` |

**Default chain**: `HasLength::length` ← `Spanning::span` ← `Spanning::logical_length`. If you only implement `length`, all three return the same value. Override `span()` to diverge from `length()`, or `logical_length()` to diverge from `span()`.

**Mergeable contract**: `merge` must be associative. The stack-based batch merge processes elements left-to-right and cascades merges backward — without associativity, different insertion orders produce different results. Property tests verify associativity for `String`.

### 2. Runs[T] (`runs.mbt`)

`pub struct Runs[T](Array[T])` — a newtype wrapping an array.

**Central invariant**: No two adjacent elements satisfy `can_merge()`. Every mutation restores this.

**Key operations**:

- `from_array_batch(arr)` — O(n) stack-merge construction
- `from_sorted_ints(ints)` — O(n) grouping + stack-merge, requires `FromRange`
- `append(elem)` — O(1) amortized with `normalize_tail` cascade
- `find(pos)` — O(n) linear scan
- `find_fast(sums, pos)` — O(log n) upper-bound binary search on prefix sums
- `split(pos)` — O(n), requires `Sliceable`
- `concat(other)` — O(n), uses stack-merge at boundary
- `extend(other)` — O(m) in-place, same stack-merge pattern
- `range(start~, end~)` — O(n) linear scan producing `Iter[Slice[T]]`
- `insert(pos, elem)` / `delete(start~, end~)` / `splice(start~, end~, replacement)` — composed from `split` and `concat`

### 3. Rle[T] (`rle.mbt`)

Wraps `Runs[T]` with two pieces of mutable state:

- **`prefix: PrefixSums?`** — cached cumulative arrays. `None` = stale. Rebuilt lazily by `ensure_prefix()` on the next query. Multiple consecutive mutations pay zero rebuild cost.

- **`version: Int`** — monotonically increasing counter. Bumped on every mutation. Cursors capture this at creation and compare on every operation.

**Mutation protocol**: Every mutating method must call both `bump_version()` and `invalidate()`. Omitting either breaks cursor detection or cache consistency.

**Key operations** (in addition to `Runs` operations):

- `from_sorted_ints(ints)` — wraps `Runs` version
- `each_with_position(f)` — per-run iteration with prefix-sum-derived positions
- `iter_units()` — expand runs to individual integers, requires `Addressable`

**Query advantage over Runs**: `Rle::range` uses `find_fast` to binary-search for the starting run (O(log n + k)), while `Runs::range` scans linearly from the beginning (O(n)).

### 4. PrefixSums (`prefix_sums.mbt`)

```
pub(all) struct PrefixSums {
  spans : Array[Int]    // cumulative span: spans[i] = Σ span(run_j) for j=0..i
  content : Array[Int]  // cumulative logical_length
}
```

Built in O(n) by `Runs::prefix_sums()`. Enables:
- O(1) total span/logical_length via `.last()`
- O(log n) position lookup via upper-bound binary search on `spans`
- O(1) run-start offset via `span_before(i)` = `spans[i-1]`

### 5. RleCursor[T] (`rle_cursor.mbt`)

Sequential traversal cursor that captures `rle.version` at creation.

**Staleness model**: If `self.version != self.rle.version`, all operations return `None`/`false`. This is optimistic concurrency control — the cursor assumes data is unchanged, checks on every access. The monotonic counter prevents ABA problems.

**Movement**: `advance(n)` and `retreat(n)` walk through runs consuming span positions. `seek(pos)` uses `Rle::find()` for O(log n) random access.

### 6. Slice[T] (`slice.mbt`)

```
pub struct Slice[T] { value: T, start: Int, end: Int }
```

A lazy view — stores bounds without materializing the sub-range. Call `to_inner()` to allocate the sliced value. This enables zero-copy range iteration.

## Supporting Files

- `errors.mbt` — `RleError` hierarchy: `PositionOutOfBounds`, `InvalidRange`, `InvalidSlice`, `Internal`
- `run_pos.mbt` — `RunPos` struct: `{ run: Int, offset: Int }`
- `runs_string.mbt` — `String` trait implementations (all four traits)
- `arbitrary.mbt` — QuickCheck `Arbitrary` and `Shrink` generators

## Algorithms

### Stack-Based Batch Merge

Used by `from_array_batch`, `concat`, and `extend`. Pattern:

```text
for each item:
    skip if span <= 0
    while stack top can merge with item:
        pop, merge into item
    push item
```

Each element is pushed/popped at most once → O(n) amortized total. Guarantees no adjacent mergeable runs in one pass.

### Upper-Bound Binary Search

`find_fast` searches the cumulative `spans` array for the smallest `i` where `spans[i] > pos`. This identifies the run containing position `pos`. Standard upper-bound binary search. After the loop, `lo` is the first index where `spans[lo] > pos`, identifying the run containing `pos`.

### Split-Concat Composition

`insert`, `delete`, and `splice` are composed from `split` and `concat`:

```text
insert(pos, elem)  = split(pos) → concat(left, elem) → concat(result, right)
delete(s, e)       = split(s) → split(e-s) → concat(left, right)
splice(s, e, repl) = split(s) → split(e-s) → concat(left, repl) → concat(result, right)
```

These produce new `Runs`/`Rle` values (functional style). The original is not modified.

## Design Decisions

- **Lazy prefix sums**: Rebuilt only when queried after mutation, not on every mutation. Multiple consecutive mutations pay zero rebuild cost.
- **Dual-length** (`span` vs `logical_length`): Supports CRDT tombstones and gap buffers where index space differs from visible content.
- **Stack-based batch merge**: Single-pass O(n) construction with automatic invariant maintenance.
- **Cursor staleness is conservative**: Returns `None` rather than potentially wrong data. No ABA problem due to monotonic versioning.
- **Functional structural operations**: `split`/`insert`/`delete`/`splice` return new values, avoiding cache invalidation complexity. Only `append`/`extend`/`clear` mutate in place.
- **Lazy `Slice` views**: `range()` returns `Slice[T]` (bounds only), deferring materialization to `to_inner()` to avoid unnecessary allocation.

## Test Files

| File | Style | Purpose |
|------|-------|---------|
| `rle_test.mbt` | Blackbox | `Rle` public API tests |
| `runs_test.mbt` | Blackbox | `Runs` public API tests |
| `runs_wbtest.mbt` | Whitebox | Internal invariant verification (accesses `runs.0`, `rle.prefix`) |
| `runs_properties_test.mbt` | QuickCheck | Algebraic property tests (associativity, length preservation, round-trips) |
| `rle_benchmark.mbt` | Benchmark | Performance tests (run with `--release`) |

## Dependencies

- `moonbitlang/quickcheck` (0.9.9) — property-based testing
- `moonbitlang/core/bench` — benchmark harness
- `moonbitlang/core/quickcheck` — core QuickCheck integration
