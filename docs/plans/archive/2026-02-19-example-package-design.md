# Example Package Design

**Date:** 2026-02-19
**Scope:** Add an `example/` package demonstrating practical use of the `rle` library.

## Package Layout

Single flat package — matches the project's existing single-package style:

```
example/
  moon.pkg.json          — imports dowdiness/rle
  string_examples.mbt    — string use-cases
  authored_run.mbt       — AuthoredRun custom type (collaborative text)
  pixel_run.mbt          — PixelRun custom type (image scanline)
```

## File Content

### `moon.pkg.json`
Import `dowdiness/rle` (the sibling package at `rle/`).

### `string_examples.mbt`
Demonstrates the built-in String use-cases:
- `from_string`, `span`, `find`, `to_string`
- `append` with auto-merge
- `split` and reassembly
- `range` / `range_clamped` for substring extraction
- `concat` and `extend`
- `insert`, `delete`, `splice`
- `cursor` traversal (advance, seek, stale detection)
- `from_array` batch construction
- Error handling patterns (`Result` matching)

### `authored_run.mbt`
Custom type `AuthoredRun { author: String, text: String }`:
- Implements `Mergeable` (merge only same-author adjacent runs)
- Implements `HasLength` / `Spanning` (UTF-16 code units)
- Implements `Sliceable` (substring slice)
- Demonstrates: building a multi-author document, `range` to extract per-author segments, `split` at a boundary

### `pixel_run.mbt`
Custom type `PixelRun { color: Int, count: Int }`:
- Implements `Mergeable` (merge same-color adjacent runs)
- Implements `HasLength` / `Spanning` (count as span)
- No `Sliceable` needed (demonstrates append/find without split)
- Demonstrates: building a scanline, `find` to look up pixel at position, `iter` to enumerate runs, `value_at` for direct lookup

## Testing Convention

Examples are expressed as `test` blocks using `inspect()` — same pattern as the existing test files. No separate `main` entry point needed; `moon test --package example` runs them all.

## Non-Goals

- No sub-packages
- No benchmarks in the example package
- No QuickCheck — examples are deterministic
