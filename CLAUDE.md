# CLAUDE.md

## Project Overview

RLE library in MoonBit — compressed sequences with O(log n) lookup via lazy prefix sums. For detailed type/file reference see [ARCHITECTURE.md](docs/ARCHITECTURE.md).

## MoonBit Language Notes

- `pub` vs `pub(all)` visibility modifiers have different semantics — check current docs before using
- `._` syntax is deprecated, use `.0` for tuple access
- `try?` does not catch `abort` — use explicit error handling
- `?` operator is not always supported — use explicit match/error handling when it fails
- `ref` is a reserved keyword — do not use as variable/field names
- Blackbox tests cannot construct internal structs — use whitebox tests or expose constructors
- For cross-target builds, use per-file conditional compilation rather than `supported-targets` in moon.pkg.json

## Build Commands

```bash
moon check            # Type check
moon test             # Run all tests
moon bench --release  # Benchmarks (release mode required)
moon build            # Build
moon update           # Update dependencies
```

Core library lives in `src/` (package `dowdiness/rle`). Example sub-packages under `src/example/{string,pixel,authored}` each have their own `moon.pkg`.

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

**String indices ≠ character offsets.** MoonBit strings are UTF-16 code units. `slice_string_view` validates bounds and surrogate pair boundaries, returning `SliceError::InvalidIndex` for mid-pair cuts. Test with "😀" (2 units) and "A😀B" (4 units).

**Skipping zero-span rejection.** Every entry point adding elements must reject `span <= 0`. `append()` returns error; batch/concat/extend silently skip.

**Accessing prefix sums without ensure_prefix().** Always call `self.ensure_prefix()` before reading `self.prefix`. See `find()`, `span()`, `logical_length()`, `range()`.

**Split-then-concat run count.** Round-trip may change run count — this is expected. Don't assert on run count after split+concat.

## Constraints

**Performance.** `Rle::find()` must use O(log n) binary search. Prefix sums are lazy — never rebuild inside mutations. `from_array_batch()` must stay O(n) single-pass. Benchmarks require `--release`.

**Safety.** No panics on user input — always `Result`. Bounds-check new direct array access patterns. Stale cursors return `None`, never wrong data.

**Cost.** Single package, minimal deps (`moonbitlang/quickcheck`, core bench). Keep property test generators bounded and test suite fast.

## Package Map

| Package | Purpose |
|---------|---------|
| `src/` | Core library — traits, runs, prefix sums, rle wrapper, cursor, slice, errors |
| `src/example/` | Basic string usage demo |
| `src/example/string/` | String-specific operations demo |
| `src/example/pixel/` | Custom `PixelRun` type demo (no Sliceable) |
| `src/example/authored/` | Custom `AuthoredRun` type demo (with Sliceable) |

## Documentation

- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — type descriptions, algorithms, design rationale
- **Plans:** `docs/plans/` — implementation design documents

## MoonBit Conventions

- **Block-style:** Code organized in `///|` separated blocks
- **Testing:** Use `inspect` for snapshots, `@qc` for properties
- **Files:** `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox), `*_benchmark.mbt`
- **Format:** Always `moon info && moon fmt` before committing
- **Trait impl:** `pub impl Trait for Type with method(self) { ... }` — one method per impl block
- **Arrow functions:** `() => expr`, `() => { stmts }`. Empty body: `() => ()` not `() => {}`

## Code Review Standards

- Never dismiss a review request — always do a thorough line-by-line review even if changes seem minor
- Check for: integer overflow, zero/negative inputs, boundary validation, generation wrap-around
- Do not suggest deleting public API types (Id structs, etc.) as 'unused' — they may be needed by downstream consumers
- Verify method names match actual API before writing tests (e.g., check if it's `insert` vs `add_local_op`)

## Development Workflow

1. Make edits
2. `moon check` — Lint
3. `moon test` — Run tests
4. `moon test --update` — Update snapshots (if behavior changed)
5. `moon info` — Update `.mbti` interfaces
6. Check `git diff *.mbti` — Verify API changes
7. `moon fmt` — Format

## Git Workflow

- Always check if git is initialized before running git commands
- After rebase operations, verify files are in the correct directories
- When asked to 'commit remaining files', interpret generously even if phrasing is unclear
