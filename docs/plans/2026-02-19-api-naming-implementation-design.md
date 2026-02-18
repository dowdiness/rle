# API Naming Implementation Design

**Date**: 2026-02-19
**Status**: Approved
**Source**: `docs/api-naming-improvement.md`

## What

Rename core API methods across the RLE library before the 1.0.0 release:

| Current | Proposed |
|---------|----------|
| `count()` | `length()` |
| `len()` | `span()` |
| `content_len()` | `logical_length()` |

Add `is_empty()` as a default method on `HasLength`. Make `logical_length()` a default method on `Spanning` (defaulting to `span()`), replacing the previously required `content_len`.

## Why

Pre-release cleanup at zero migration cost. The current names are abbreviated (`len`), non-standard (`count` for element count), or ambiguous (`content_len`). The new names align with MoonBit conventions and the logical/physical distinction standard in CS.

## Approach

Plan-sequential, layer by layer. Each layer is completed and verified with `moon check` before the next begins. This keeps compiler errors focused and progress visible.

## Layers

### Layer 1 — Traits (`traits.mbt`)

- Add `is_empty(Self) -> Bool` default to `HasLength` (`self.length() == 0`)
- Add `logical_length(Self) -> Int` default to `Spanning` (`self.span()`)
- Rename required trait method `content_len` → `logical_length`

Verify: `moon check`

### Layer 2 — Implementations

Files and specific work:

- **`rle.mbt`**: rename `count()` → `length()`, `len()` → `span()`, `content_len()` → `logical_length()`; add explicit `pub impl HasLength for Rle[T]` and `pub impl Spanning for Rle[T]` blocks; update all internal calls
- **`runs.mbt`**: same renames; add explicit trait impl blocks; update 6 internal `self.len()` → `self.span()` calls (lines 227, 276, 294, 420, 468, 509)
- **`prefix_sums.mbt`**: rename `len()` → `span()`, `content_len()` → `logical_length()`, `count()` → `length()`
- **`runs_string.mbt`**: remove `content_len` impl — default `logical_length()` is sufficient
- **`rle_benchmark.mbt`**: remove `pub impl Spanning for BenchRun with content_len` — default is sufficient
- **`rle_cursor.mbt`**: rename 4 calls of `self.rle.len()` → `self.rle.span()` (lines 64, 76, 149, 183)
- **`slice.mbt`**, **`arbitrary.mbt`**: no changes (verified)

Verify: `moon check`

### Layer 3 — Tests

- **`rle_test.mbt`** (75 tests): update method names in assertions
- **`runs_test.mbt`** (54 tests): update method names in assertions
- **`runs_properties_test.mbt`** (18 tests): update method names
- **`runs_wbtest.mbt`** (10 tests): update method names
- **`rle_benchmark.mbt`** call sites: update `count()` → `length()` in `b.keep(...)` calls
- Add new tests: `is_empty()` with no runs; `HasLength::is_empty()` via generic constraint; default `logical_length()` implementation

Verify: `moon check && moon test`

### Layer 4 — Docs and Config

- **`CLAUDE.md`**: update line 43 (`len()`, `content_len()` references → `span()`, `logical_length()`)
- **`README.md`**: update Quick Start, API Overview table, all code examples
- **`CHANGELOG.md`**: create with 1.0.0 entry
- **`moon.mod.json`**: bump version to `"1.0.0"`

### Layer 5 — Generated Files

- Run `moon info` to regenerate `rle/pkg.generated.mbti`
- Verify exported names match new API (`span`, `logical_length`, `length`, `is_empty`)

## Verification Checklist

- [ ] `moon check` passes after each layer
- [ ] `moon test` passes (100%) after Layer 3
- [ ] `moon bench --release` runs without errors
- [ ] `pkg.generated.mbti` exports new names
- [ ] All README examples use new method names
