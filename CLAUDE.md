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
