# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-05-14

### Added
- Added `Rle::Rle()` and `PrefixSums::PrefixSums()` as the preferred constructors.

### Deprecated
- Deprecated `Rle::new()` and `PrefixSums::new()` in favor of `Rle::Rle()` and `PrefixSums::PrefixSums()`.

### Fixed
- Removed the stale generated `Runs::inner(Self[T]) -> Array[T]` API entry. Use `Runs::to_array()` to copy runs into a new array.
- Refreshed stale snapshot and README doctest expectations after output format changes.
- Removed warning-producing old constructor usage so checks pass with warnings denied.

## [0.2.0] - 2026-04-24

### Breaking
- Import path changed from `dowdiness/rle/rle` to `dowdiness/rle` (source relocated to `src/` via `moon.mod.json` `source: "src"`). Consumers must update import paths.
- `Show` derives migrated to `Debug` on `Rle`, `RleCursor`, `Runs`, and `Slice` (MoonBit v0.9). Consumers using `Show` on these types must switch to `Debug`.
- `BenchRun` removed from the public API (benchmarking-only type; now private).

### Added
- `Rle::iter_units` and `Runs::iter_units` — iterate individual logical units with per-run value caching.
- `Rle::each_with_position` — position-aware iteration over runs.
- `Rle::from_sorted_ints` and `Runs::from_sorted_ints` — construct from a sorted integer sequence; duplicates are skipped.
- `FromRange` and `Addressable` traits enabling algorithm-by-trait patterns on RLE structures.
- `README.mbt.md` — runnable doc tests alongside the README.

### Changed
- Source layout moved to `src/`; example sub-packages (`string`, `pixel`, `authored`) now live under `src/example/`.
- Per-run value caching in `iter_units` / `each_with_position` reduces redundant computation during unit-level iteration.

## [0.1.0] - 2026-03-15

Initial public release.

### Features

**Core Data Structure**
- Generic run-length encoded sequence (`Rle[T]`) with automatic compression of adjacent mergeable elements
- O(log n) position lookup via lazily-cached prefix sums (binary search on cumulative span array)
- O(1) amortized `append` with cascade merge normalization
- O(n) single-pass batch construction (`from_array_batch`) using stack-based merge

**Trait System**
- `Mergeable` — define when adjacent runs compress into one (`can_merge` + `merge`)
- `Sliceable` — extract sub-ranges from a run (optional; unlocks `split`/`insert`/`delete`/`splice`)
- `HasLength` — basic size with `is_empty()` default
- `Spanning : HasLength` — dual-length semantics: `span()` (index space, includes tombstones) and `logical_length()` (visible payload, defaults to `span()`)

**Operations**
- `find(pos)` — O(log n) position-to-run lookup
- `value_at(pos)` — O(log n) get the run containing a position
- `split(pos)` — divide at any position
- `insert(pos, elem)` — insert at position (returns new Rle)
- `delete(start~, end~)` — remove a range (returns new Rle)
- `splice(start~, end~, replacement)` — replace a range (returns new Rle)
- `concat(other)` — non-mutating concatenation with boundary merge
- `extend(other)` — in-place extension with boundary merge
- `range(start~, end~)` — O(log n + k) range iteration via lazy `Slice[T]` views
- `range_clamped(start~, end~)` — range with auto-clamped bounds (never errors)

**Cursor**
- `RleCursor[T]` for efficient sequential traversal with `advance`/`retreat`/`seek`
- O(log n) random access via `seek(pos)` (binary search)
- Automatic staleness detection via monotonic version counter — stale cursors return `None`, never wrong data

**String Support**
- Built-in `Mergeable`, `Sliceable`, `Spanning`, `HasLength` implementations for `String`
- UTF-16 code unit indexing with surrogate pair boundary validation
- `slice_string_view` helper for custom types wrapping strings
- `from_string`, `to_string`, `iter_chars` convenience methods

**Error Handling**
- Result-based API — no panics on user input
- `RleError` variants: `PositionOutOfBounds`, `InvalidRange`, `InvalidSlice`, `Internal`
- User-friendly error messages via `RleError::message()`

**Testing**
- 164 tests: blackbox, whitebox, and property-based (QuickCheck)
- Property tests verify: merge associativity, split/concat round-trip, length preservation, no adjacent mergeable runs, range coverage, splice equivalence

**Examples**
- `example/` — basic string operations and cursor usage
- `example/string/` — string-specific operations (find, split, range, staleness)
- `example/pixel/` — custom `PixelRun` type (numeric, no Sliceable)
- `example/authored/` — custom `AuthoredRun` type (with Sliceable, selective merging)

### Design Notes

This library is designed for document-editor and CRDT workloads where sequences are built incrementally and queried by position. The dual-length `span`/`logical_length` distinction supports tombstone-based data structures where index space and visible content differ.

The lazy prefix sum cache means mutations are cheap (O(1), no rebuild) and reads pay the amortized cost of a single O(n) rebuild followed by O(log n) lookups. This fits write-heavy, read-periodic access patterns like text editors.
