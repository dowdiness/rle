# CLAUDE.md

RLE library in MoonBit — compressed sequences with O(log n) lookup via lazy prefix sums. For detailed type/file reference see [ARCHITECTURE.md](ARCHITECTURE.md).

## Build Commands

```bash
moon check            # Type check
moon test             # Run all tests
moon test --package rle        # Tests with output
moon bench --package rle --release  # Benchmarks (release mode required)
moon build            # Build
moon update           # Update dependencies
```

All code lives in `rle/` — single package, no sub-packages.

## Architecture Rules

**Layering is strict and bottom-up.** Dependencies flow downward only:
Traits → Errors → Runs → PrefixSums → Rle → RleCursor → Slice. No upward or circular deps.

**Runs invariant: no adjacent mergeable runs.** Every mutation must restore this via `normalize_tail()` (append) or stack-merge loop (concat/extend/from_array_batch). Never mutate the internal array without normalization.

**Rle mutations must invalidate + version-bump.** Always call both `self.invalidate()` and `self.bump_version()`. Omitting either breaks cache consistency or cursor staleness detection.

**Trait impls in dedicated files.** `String` → `runs_string.mbt`. New types → `runs_<typename>.mbt`.

**Test file conventions.** `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox), `*_properties_test.mbt` (QuickCheck), `*_benchmark.mbt`. Don't mix blackbox and whitebox.

**Error handling: Result-based, no panics.** Public APIs return `Result[T, RleError]`. Use `PositionOutOfBounds`, `InvalidRange`, `InvalidSlice` for user errors; `Internal` for invariant violations. Never `abort`/`panic` on user input.

## Known Mistakes

**Breaking merge cascade.** Don't add early returns before `normalize_tail()` or reorder the pop-merge-push loop. After changes to append/concat/extend/from_array_batch, run whitebox tests (`runs_wbtest.mbt`).

**Forgetting bump_version.** Every `invalidate()` call must pair with `bump_version()`. Copy the pattern from `append()`.

**String indices ≠ character offsets.** MoonBit strings are UTF-16 code units. Wrap string view slicing in try/catch converting `@builtin.InvalidIndex` → `RleError::InvalidSlice`. Test with "😀" (2 units) and "A😀B" (4 units).

**Skipping zero-span rejection.** Every entry point adding elements must reject `span <= 0`. `append()` returns error; batch/concat/extend silently skip.

**Accessing prefix sums without ensure_prefix().** Always call `self.ensure_prefix()` before reading `self.prefix`. See `find()`, `span()`, `logical_length()`, `range()`.

**Split-then-concat run count.** Round-trip may change run count — this is expected. Don't assert on run count after split+concat.

## Constraints

**Performance.** `Rle::find()` must use O(log n) binary search. Prefix sums are lazy — never rebuild inside mutations. `from_array_batch()` must stay O(n) single-pass. Benchmarks require `--release`.

**Safety.** No panics on user input — always `Result`. Bounds-check new direct array access patterns. Stale cursors return `None`, never wrong data.

**Cost.** Single package, minimal deps (`moonbitlang/quickcheck`, core bench). Keep property test generators bounded and test suite fast.
