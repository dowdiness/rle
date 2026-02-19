# Example Sub-packages Design

**Date:** 2026-02-19
**Goal:** Replace the test-block example files with three runnable sub-packages that serve as practical demonstrations of the rle library.

## Context

The `example/` package already exists with a runnable `fn main` demo for strings. Three test-block files were added (`string_examples.mbt`, `authored_run.mbt`, `pixel_run.mbt`) but these are CI tests, not practical demonstrations. They will be removed.

## Structure

```
example/                    ← keep as-is (main.mbt untouched)
example/string/             ← new: string API walkthrough
example/authored/           ← new: AuthoredRun custom type demo
example/pixel/              ← new: PixelRun custom type demo
```

Each sub-package:
- `moon.pkg` — text-format, `is-main: true`, imports `dowdiness/rle/rle`
- `main.mbt` — `fn main` with `println` and inline `//=>` comments

## Demo Style

Follows the existing `example/main.mbt` convention:

```moonbit
fn main {
  let rle = @rle.Rle::from_string("hello world")
  rle.span() |> println        //=> 11
  rle.find(6) |> println       //=> Some({run: 0, offset: 6})
}
```

## Content

**example/string/** — covers the full Rle[String] API: construction, span, find, range, split, concat, extend, insert, delete, splice, from_array, cursor.

**example/authored/** — defines `AuthoredRun` (author + text, merges by author), then demonstrates: append merging, multi-author separation, split, range across runs, from_array batch merge.

**example/pixel/** — defines `PixelRun` (color + count, merges by color), then demonstrates: append merging, multi-color separation, find, value_at, iter, from_array, cursor traversal.

## Cleanup

Remove from `example/`:
- `string_examples.mbt`
- `authored_run.mbt`
- `pixel_run.mbt`
