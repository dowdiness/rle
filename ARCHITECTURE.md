# Architecture Reference

Detailed type descriptions, design rationale, and file map for the RLE library. See [CLAUDE.md](CLAUDE.md) for rules and constraints.

## Core Types (layered bottom-up)

1. **Traits** (`traits.mbt`) — `Mergeable`, `Sliceable`, `HasLength`, `Spanning: HasLength`. `Spanning` provides dual-length: `span` (index space, includes tombstones/gaps) vs `content_len` (visible payload).

2. **Runs[T]** (`runs.mbt`) — Array of mergeable runs. Invariant: no two adjacent runs satisfy `can_merge()`. Key ops: `from_array_batch` (O(n) stack-merge), `append` (O(1) amortized), `find`/`find_fast`, `split`, `concat`, `extend`, `range`.

3. **Rle[T]** (`rle.mbt`) — Wraps `Runs[T]` with lazy prefix sum cache (`prefix: PrefixSums?`, `None` = stale) and monotonic `version` counter for cursor staleness.

4. **PrefixSums** (`prefix_sums.mbt`) — Cumulative span/content arrays for O(log n) binary search.

5. **RleCursor[T]** (`rle_cursor.mbt`) — Sequential traversal cursor. Returns `MayStale[T]` (`T?`) when underlying data has mutated.

6. **Slice[T]** (`slice.mbt`) — Lazy view into a run with bounds. `to_inner()` materializes on demand.

## Supporting Files

- `errors.mbt` — `RleError` enum: `PositionOutOfBounds`, `InvalidRange`, `InvalidSlice`, `Internal`
- `run_pos.mbt` — `RunPos` struct (run index + offset within run)
- `runs_string.mbt` — `String` trait implementations
- `arbitrary.mbt` — QuickCheck `Arbitrary` generators

## Design Decisions

- **Lazy prefix sums**: Rebuilt only when queried after mutation, not on every mutation.
- **Dual-length**: `span` vs `content_len` supports CRDT tombstones and gap buffers.
- **Stack-based batch merge**: `from_array_batch` cascades merges in a single pass.
- **Cursor staleness**: Conservative — returns `None` rather than potentially wrong data.

## Test Files

- `rle_test.mbt` — Blackbox `Rle` API tests
- `runs_test.mbt` — Blackbox `Runs` API tests
- `runs_properties_test.mbt` — QuickCheck property tests
- `runs_wbtest.mbt` — Whitebox invariant tests (accesses `runs.0`)
- `rle_benchmark.mbt` — Benchmarks (run with `--release`)

## Dependencies

- `moonbitlang/quickcheck` (0.9.9), `moonbitlang/core/bench`, `moonbitlang/core/quickcheck`
