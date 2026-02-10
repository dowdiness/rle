# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Generic run-length encoding (RLE) library written in MoonBit. Provides compressed sequence storage with O(log n) position lookup via lazy cached prefix sums. Designed for use cases like CRDTs, gap buffers, and text editors where runs of similar elements are common.

## Build Commands

```bash
# Type check
moon check

# Run all tests
moon test

# Run tests with output (useful for debugging)
moon test --package rle

# Run benchmarks (release mode required for meaningful results)
moon bench --package rle --release

# Build
moon build

# Update dependencies
moon update
```

All code lives in the single `rle/` package. There is no multi-package workspace.

## Architecture

### Core Types (layered bottom-up)

1. **Traits** (`traits.mbt`) — Four traits define the generic interface:
   - `Mergeable`: Can two adjacent runs combine? (`can_merge` + `merge`)
   - `Sliceable`: Extract sub-range via `slice(start~, end~)`
   - `HasLength`: Basic `length`
   - `Spanning: HasLength`: Dual-length semantics — `span` (index space, includes tombstones/gaps) vs `content_len` (visible payload). For plain text, both are equal.

2. **Runs[T]** (`runs.mbt`) — Core array of mergeable runs. Maintains the invariant that no two adjacent runs are mergeable. Key operations:
   - `from_array_batch`: Single-pass stack-merge construction
   - `append`: O(1) amortized with tail normalization
   - `find` / `find_fast`: Linear scan or binary search (with prefix sums)
   - `split`, `concat`, `extend`, `range`

3. **Rle[T]** (`rle.mbt`) — Wraps `Runs[T]` with lazy prefix sum cache. Adds:
   - `version`: Monotonic mutation counter for cursor staleness detection
   - `prefix: PrefixSums?`: `None` = stale, rebuilt on-demand via `ensure_prefix()`
   - All mutating methods call `invalidate()` + `bump_version()`

4. **PrefixSums** (`prefix_sums.mbt`) — Cumulative span/content arrays enabling O(log n) binary search in `find_fast`.

5. **RleCursor[T]** (`rle_cursor.mbt`) — Sequential traversal cursor. Captures version at creation; returns `MayStale[T]` (`T?`) to signal when underlying data has mutated.

6. **Slice[T]** (`slice.mbt`) — Lazy view into a run with bounds. `to_inner()` materializes the slice only when needed.

### Supporting Files

- `errors.mbt` — `RleError` enum with `PositionOutOfBounds`, `InvalidRange`, `Internal` variants
- `run_pos.mbt` — `RunPos` struct returned by `find` (run index + offset within run)
- `runs_string.mbt` — `Mergeable + Sliceable + Spanning` implementations for `String`
- `arbitrary.mbt` — QuickCheck `Arbitrary` generators for property-based testing

### Key Design Decisions

- **Lazy invalidation**: Prefix sums are only rebuilt when queried after mutation, not on every mutation.
- **Dual-length (`span` vs `content_len`)**: Supports CRDT tombstones and gap buffers where structural size differs from visible size.
- **Stack-based batch merge**: `from_array_batch` uses a cascading merge loop instead of repeated normalize calls.
- **Cursor staleness**: Cursors capture the Rle version at creation and conservatively signal staleness rather than silently returning wrong data.

### Test Structure

- `rle_test.mbt` — Blackbox tests for `Rle` public API
- `runs_test.mbt` — Blackbox tests for `Runs` public API
- `runs_properties_test.mbt` — QuickCheck property-based tests (merge associativity, slice round-trips, span invariants)
- `runs_wbtest.mbt` — Whitebox tests accessing internal `runs.0` array for invariant checks
- `rle_benchmark.mbt` — Performance benchmarks for range iteration, concat, extend, construction

### Dependencies

- `moonbitlang/quickcheck` (0.9.9) — Property-based testing
- `moonbitlang/core/bench` — Benchmarking framework
- `moonbitlang/core/quickcheck` — Core QuickCheck integration

## Architecture Rules

These rules define how code is structured in this project. Follow them for all changes.

### Layering is strict and bottom-up

Types depend only on layers below them. The dependency order is:

1. Traits (`traits.mbt`) — no internal dependencies
2. Errors (`errors.mbt`) — no internal dependencies
3. Runs (`runs.mbt`) — depends on traits, errors
4. PrefixSums (`prefix_sums.mbt`) — depends on traits
5. Rle (`rle.mbt`) — depends on Runs, PrefixSums
6. RleCursor (`rle_cursor.mbt`) — depends on Rle
7. Slice (`slice.mbt`) — depends on traits

Do not introduce upward or circular dependencies. Runs must never import Rle. PrefixSums must never import Runs.

### One package, one directory

All code lives in `rle/`. Do not create sub-packages or a multi-package workspace. New types and functions go into existing files by layer, or into a new file at the appropriate layer.

### Invariant maintenance through controlled mutation

`Runs[T]` enforces the invariant that no two adjacent runs satisfy `can_merge()`. Every function that modifies the run array must restore this invariant before returning. The pattern is:
- `append()` calls `normalize_tail()` which cascades merges backward
- `concat()` and `extend()` use the same stack-merge loop as `from_array_batch()`
- `split()` constructs new Runs via `append()`, inheriting normalization

Never mutate the internal array directly without calling normalization afterward.

### Rle mutations must invalidate and version-bump

Every mutating method on `Rle[T]` must call both `self.invalidate()` (sets `prefix = None`) and `self.bump_version()` (increments version counter). Doing only one breaks either cache consistency or cursor staleness detection.

### Trait implementations go in dedicated files

`String` trait impls live in `runs_string.mbt`. New type impls (e.g., for a custom CRDT element) should follow the same pattern: `runs_<typename>.mbt`.

### Test file naming conventions

- `*_test.mbt` — blackbox tests using public API only
- `*_wbtest.mbt` — whitebox tests that access internal fields (e.g., `runs.0`)
- `*_properties_test.mbt` — QuickCheck property-based tests
- `*_benchmark.mbt` — benchmarks (run with `--release`)

Do not mix blackbox and whitebox tests in the same file.

### Error handling is Result-based, never panics on user input

All fallible public operations return `Result[T, RleError]`. Internal invariant violations use `RleError::Internal`. User input errors use `PositionOutOfBounds`, `InvalidRange`, or `InvalidSlice`. Never use `abort` or `panic` for conditions reachable from public API input.

## Known Mistakes

Common errors AI assistants make when modifying this codebase, and how to avoid them.

### Breaking the merge cascade in append or concat

**Mistake**: Refactoring `append()` or `concat()` in a way that skips `normalize_tail()` or breaks the stack-merge while loop. For example, adding an early return before normalization, or reordering the pop-merge-push sequence in `concat()`.

**Fix**: After any change to `append()`, `concat()`, `extend()`, or `from_array_batch()`, run the whitebox test `runs_wbtest.mbt` which checks that no adjacent mergeable runs exist. The stack-merge loop must pop from the tail, merge into `cur`, and continue — not break after one merge.

### Forgetting bump_version when adding new Rle mutations

**Mistake**: Adding a new mutating method to `Rle` that calls `invalidate()` but forgets `bump_version()`, or vice versa.

**Fix**: Search for all calls to `invalidate()` — every one must be paired with `bump_version()`. When adding a new mutating method, copy the pattern from `append()`:
```
self.invalidate()
self.bump_version()
```

### Treating string indices as character offsets

**Mistake**: Assuming `slice(start~, end~)` operates on character indices. MoonBit strings are UTF-16; indices are code unit positions. Slicing at a surrogate pair boundary (e.g., position 1 of "😀") causes `@builtin.InvalidIndex`.

**Fix**: The `String` impl in `runs_string.mbt` wraps string view slicing in a try/catch that converts `@builtin.InvalidIndex` to `RleError::InvalidSlice`. Any new string operations must do the same. Test with multi-code-unit characters like "😀" (2 code units) and "A😀B" (4 code units).

### Skipping zero-span element rejection

**Mistake**: Adding a new construction path that doesn't check `T::span(elem) <= 0`, allowing zero-length runs into the array. This violates the core invariant and causes infinite loops in `find()`.

**Fix**: Every entry point that adds elements to Runs must reject elements where `span <= 0`. `append()` returns an error; `from_array_batch()`, `concat()`, and `extend()` silently skip. Follow the existing pattern for the operation type.

### Accessing prefix sums without ensuring they exist

**Mistake**: Using `self.prefix` directly in Rle methods without calling `ensure_prefix()` first, causing a `None` dereference when the cache is stale.

**Fix**: Always call `self.ensure_prefix()` before accessing `self.prefix`. The `find()`, `len()`, `content_len()`, and `range()` methods on Rle all demonstrate this pattern.

### Creating adjacent duplicate runs via split-then-concat

**Mistake**: Splitting a Runs at a position and concatenating back together, expecting identical output. The split may produce partial runs at the boundary that merge differently when re-combined.

**Fix**: This is expected behavior, not a bug. Property tests verify that split-then-concat preserves total content and length, but the number of runs may differ. Do not write assertions on run count after round-trip operations.

## Constraints

Security, performance, and cost limits for this project.

### Performance constraints

- **O(log n) position lookup is required**: `Rle::find()` must use binary search via prefix sums, not linear scan. The `Runs::find()` linear scan exists only as a fallback for contexts without cached prefix sums.
- **Prefix sums are lazy, not eager**: Never rebuild prefix sums inside a mutating method. They are rebuilt on-demand by read methods via `ensure_prefix()`. Eager rebuilding would make bulk mutations (e.g., repeated `append()`) O(n²).
- **Batch construction must be O(n)**: `from_array_batch()` uses a single-pass stack merge. Do not replace it with repeated `append()` calls, which would degrade to O(n²) in the worst case due to cascading normalization.
- **Benchmarks require `--release` mode**: Debug builds do not produce meaningful performance numbers. Always run `moon bench --package rle --release`.

### Safety constraints

- **No panics on user input**: All public API methods must return `Result` for error cases. `abort` and `panic` are only acceptable for internal invariant violations that indicate bugs in this library.
- **Bounds checking before array access**: Binary search and range iteration use direct array indexing for performance. These paths must be proven safe by loop invariants. Add bounds checks when introducing new direct-access patterns.
- **Cursor staleness is conservative**: A stale cursor returns `None` / stops iteration rather than returning potentially wrong data. Never weaken this guarantee (e.g., by making stale cursors continue with cached data).

### Cost constraints

- **Single-package design**: This is a focused library. Do not introduce build complexity (sub-packages, code generation, external tooling) unless absolutely required.
- **Minimal dependencies**: Only `moonbitlang/quickcheck` and core bench are used. Do not add dependencies without clear justification.
- **Tests must stay fast**: Property-based tests use bounded generators. Do not increase generator sizes without verifying test suite runtime stays under a few seconds.
