# rle

Generic run-length encoded sequence for [MoonBit](https://www.moonbitlang.com/) with O(log n) position lookup.

Adjacent elements that can be merged are automatically compressed into single runs, and a lazily-cached prefix sum index enables fast positional queries without scanning.

## Install

```bash
moon add dowdiness/rle
```

## Quick Start

### Working with Strings

Strings implement all required traits out of the box, so you can start immediately:

```moonbit
// Create from a string
let rle = @rle.Rle::from_string("hello world")

// Length and lookup
rle.span() |> println   //=> 11
match rle.find(6) {
  Some(pos) => println("Some({run: \{pos.run}, offset: \{pos.offset}})")
  None => println("None")
}

// Append merges automatically (strings always merge)
let rle = @rle.Rle::Rle()
rle.append("hello") |> println   // Ok(())
rle.append(" world") |> println  // Ok(()) — merged into one run
rle.length() |> println          //=> 1
rle.to_string() |> println       //=> "hello world"

// Split at any position
let (left, right) = rle.split(5).unwrap()
left.to_string() |> println   //=> "hello"
right.to_string() |> println  //=> " world"

// Range iteration returns slices without copying
let slices = rle.range(start=1, end=4).unwrap().collect()
let ell = match slices[0].to_inner() {
  Ok(value) => value  //=> "ell"
  Err(_) => ""
}
println(ell)
```

### Batch Construction

Build from an array in a single O(n) pass. Empty elements are skipped and adjacent ones merged:

```moonbit
let rle = @rle.Rle::from_array(["a", "", "b", "", "c"])
rle.length()      //=> 1  (all merged into "abc")
rle.to_string()   //=> "abc"
```

### Editing Operations

Insert, delete, and splice at any position:

```moonbit
// Insert at position
let rle = @rle.Rle::from_string("helo")
let elem = @rle.Rle::from_string("l")
let result = rle.insert(2, elem).unwrap()
result.to_string()  //=> "hello"

// Delete a range
let rle = @rle.Rle::from_string("hello world")
let result = rle.delete(start=5, end=6).unwrap()
result.to_string()  //=> "helloworld"

// Splice: replace a range with new content
let rle = @rle.Rle::from_string("hello world")
let replacement = @rle.Rle::from_string("beautiful ")
let result = rle.splice(start=6, end=11, replacement).unwrap()
result.to_string()  //=> "hello beautiful "
```

These operations produce **new** `Rle` values — the original is not modified.

### Cursor for Sequential Traversal

Cursors track their position and detect mutations:

```moonbit
let rle = @rle.Rle::from_string("abcdef")
let cursor = rle.cursor()

cursor.advance(3)          //=> true
match cursor.position() {
  Some(position) => println("Some(\{position})")
  None => println("None")
}
match cursor.current_item() {
  Some(item) => println("Some(\"\{item}\")")
  None => println("None")
}

// seek() uses binary search — O(log n)
cursor.seek(1)             //=> true
match cursor.position() {
  Some(position) => println("Some(\{position})")
  None => println("None")
}

// Mutation invalidates the cursor
rle.append("ghi")
cursor.is_stale()          //=> true
match cursor.next() {
  Some(item) => println("Some(\"\{item}\")")
  None => println("None")
}
```

After a mutation, create a new cursor to continue traversal.

### Concatenation and Extension

```moonbit
// Non-mutating concat — returns a new Rle
let a = @rle.Rle::from_string("hello")
let b = @rle.Rle::from_string(" world")
let c = a.concat(b)
c.to_string()  //=> "hello world"

// In-place extend — mutates the receiver
let rle = @rle.Rle::from_string("hello")
rle.extend(@rle.Rle::from_string(" world"))
rle.to_string()  //=> "hello world"
```

## Custom Types

To use `Rle` with your own types, implement the required traits. The traits you implement determine which operations are available:

### Trait Requirements

| Traits Implemented | Operations Unlocked |
|--------------------|---------------------|
| `HasLength` + `Spanning` | `find`, `span`, `logical_length`, `value_at`, `range`, `cursor` |
| above + `Mergeable` | above + `append`, `concat`, `extend`, `from_array` |
| above + `Sliceable` | above + `split`, `insert`, `delete`, `splice` |

Query operations (`find`, `range`, etc.) only need `Spanning`. You need `Mergeable` to construct and mutate sequences. You only need `Sliceable` for operations that cut a run in half (splitting at a position inside a run). In practice, most types implement all three since you need `Mergeable` to build an `Rle` in the first place.

### Minimal Example: PixelRun (no Sliceable)

A run of pixels with the same color. Adjacent same-color runs merge by summing counts.

```moonbit
struct PixelRun {
  color : Int
  count : Int
}

impl @rle.Mergeable for PixelRun with can_merge(a, b) {
  a.color == b.color
}

impl @rle.Mergeable for PixelRun with merge(a, b) {
  { color: a.color, count: a.count + b.count }
}

impl @rle.HasLength for PixelRun with length(self) {
  self.count
}

// span() delegates to length() here — both return pixel count.
// Override span() only when it should differ from length (e.g., CRDT tombstones).
impl @rle.Spanning for PixelRun with span(self) {
  self.count
}
```

With these four impls, you can use `append`, `find`, `value_at`, `range`, `concat`, `from_array`, and `cursor`. You cannot use `split`/`insert`/`delete`/`splice` because `PixelRun` is not `Sliceable`.

### Full Example: AuthoredRun (with Sliceable)

A run of text attributed to a single author. Adjacent runs from the same author merge.

```moonbit
struct AuthoredRun {
  author : String
  text : String
}

impl @rle.Mergeable for AuthoredRun with can_merge(a, b) {
  a.author == b.author
}

impl @rle.Mergeable for AuthoredRun with merge(a, b) {
  { author: a.author, text: a.text + b.text }
}

impl @rle.HasLength for AuthoredRun with length(self) {
  self.text.length()
}

impl @rle.Spanning for AuthoredRun with span(self) {
  self.text.length()
}

// Sliceable: needed for split, insert, delete, splice.
// Delegates to String's Sliceable impl for bounds and surrogate validation.
impl @rle.Sliceable for AuthoredRun with slice(self, start~, end~) {
  match @rle.Sliceable::slice(self.text, start~, end~) {
    Ok(sliced) => Ok({ author: self.author, text: sliced })
    Err(e) => Err(e)
  }
}
```

For types wrapping strings, delegate to `String`'s `Sliceable` impl which handles bounds checking and UTF-16 surrogate pair validation. For lower-level control, `slice_string_view` is also available and returns `SliceError` directly.

### Implementing Mergeable: Contract

Your `merge` implementation **must** be associative:

```text
merge(merge(a, b), c) == merge(a, merge(b, c))
```

The library's batch merge processes elements left-to-right and cascades merges backward. Without associativity, different insertion orders produce different results. For most types (same-author check, same-color check), this holds naturally.

### Dual-Length Semantics

The `Spanning` trait provides two length notions:

- **`span`** — total size in the position/index space (defaults to `length`). Used for all positional lookups.
- **`logical_length`** — visible payload size (defaults to `span`). May be less than `span`.

This distinction is useful for CRDTs (tombstones occupy index space but have no visible content) and gap buffers:

```moonbit
impl @rle.Spanning for CrdtRun with span(self) {
  self.len  // includes tombstones
}

impl @rle.Spanning for CrdtRun with logical_length(self) {
  if self.deleted { 0 } else { self.len }
}
```

For simple types where both sizes are the same, implement only `HasLength::length` — `span` and `logical_length` both default to it.

## Two-Level API: Runs vs Rle

The library exposes two main types:

| Type | Caching | Use When |
|------|---------|----------|
| `Runs[T]` | None | One-shot operations, managing your own prefix sums, or building blocks for custom structures |
| `Rle[T]` | Lazy prefix sums | Repeated queries between mutations (typical usage) |

`Rle[T]` wraps `Runs[T]` and caches prefix sums. After a mutation (append/extend/clear), the cache is invalidated. The next query (find/span/range) triggers a lazy O(n) rebuild. Multiple consecutive mutations pay zero rebuild cost.

For most users, **use `Rle[T]`**. Use `Runs[T]` directly only if you need fine-grained control over when prefix sums are built.

## API Overview

### Rle[T]

| Method | Complexity | Description |
|--------|-----------|-------------|
| `Rle::Rle()` | O(1) | Empty RLE sequence |
| `Rle::from_array(arr)` | O(n) | Batch construct with merging |
| `Rle::from_string(s)` | O(1) | Create from string |
| `span()` | O(1)* | Total span length |
| `logical_length()` | O(1)* | Total content length |
| `length()` | O(1) | Number of runs |
| `find(pos)` | O(log n)* | Find run containing position |
| `value_at(pos)` | O(log n)* | Get the run at position |
| `append(elem)` | O(1) amortized | Append with auto-merge |
| `split(pos)` | O(n) | Split into two at position |
| `insert(pos, elem)` | O(n) | Insert at position (new Rle) |
| `delete(start~, end~)` | O(n) | Delete range (new Rle) |
| `splice(start~, end~, repl)` | O(n) | Replace range (new Rle) |
| `concat(other)` | O(n) | Non-mutating concatenation (new Rle) |
| `extend(other)` | O(m) | In-place extension |
| `range(start~, end~)` | O(log n + k)* | Iterate slices in range |
| `range_clamped(start~, end~)` | O(log n + k)* | Range with auto-clamped bounds |
| `clear()` | O(1) | Remove all runs |
| `cursor()` | O(1) | Create traversal cursor |
| `iter()` | O(1) | Iterate over runs |

\* *Prefix sums are lazily rebuilt after mutations (O(n) rebuild, then cached). k = number of runs in range.*

### RleCursor[T]

| Method | Complexity | Description |
|--------|-----------|-------------|
| `advance(n)` | O(n) | Move forward by n positions |
| `retreat(n)` | O(n) | Move backward by n positions |
| `seek(pos)` | O(log n) | Jump to absolute position (binary search) |
| `seek_start()` | O(1) | Jump to start |
| `seek_end()` | O(1)* | Jump to end |
| `next()` / `prev()` | O(1) | Get item and move by one |
| `current()` | O(1) | Current (item, offset) pair |
| `current_item()` | O(1) | Current item without offset |
| `position()` | O(1) | Current global position |
| `is_stale()` | O(1) | Whether the underlying Rle has mutated |
| `at_end()` | O(1)* | Whether at end (true if stale) |
| `iter_forward()` | O(1) | Iterator from current position |

\* *Methods marked with \* call `span()` internally, which may trigger a lazy prefix sum rebuild.*

All cursor methods return `None` or `false` when stale. Create a new cursor after mutations.

### Error Handling

Operations return `Result[T, RleError]` with user-friendly messages:

```moonbit
match rle.split(100) {
  Ok((left, right)) => ...
  Err(e) => println(e.message())
  //=> "Position 100 is outside the document (length: 11)"
}
```

Error types:
- `PositionOutOfBounds` — position outside valid range
- `InvalidRange` — invalid start/end (negative, reversed, exceeds length)
- `InvalidSlice` — slice on invalid boundary (e.g., inside UTF-16 surrogate pair)
- `Internal` — invariant violation (indicates a bug — please report)

### UTF-16 String Indices

All string indices are in **UTF-16 code units**, not Unicode codepoints or grapheme clusters:

| String | `span()` | Notes |
|--------|----------|-------|
| `"hello"` | 5 | ASCII: 1 code unit each |
| `"こんにちは"` | 5 | BMP characters: 1 code unit each |
| `"😀"` | 2 | Supplementary: 2 code units (surrogate pair) |
| `"A😀B"` | 4 | 1 + 2 + 1 code units |

Splitting or slicing inside a surrogate pair returns `Err(InvalidSlice(InvalidIndex))`. The library correctly rejects these invalid boundaries.

## Performance

Position lookups use binary search over cached prefix sums, giving O(log n) instead of O(n) linear scans. The cache is rebuilt lazily — only when queried after a mutation — so batch writes don't pay for repeated rebuilds.

**Write-optimized design**: mutations (append, extend) are O(1) amortized and never trigger prefix sum rebuilds. Reads (find, span, range) pay the cost of rebuilding when needed. This fits workloads where mutations happen frequently and queries happen periodically (e.g., text editors, CRDT sync).

Run benchmarks with:

```bash
moon bench --release
```

## Examples

The `src/example/` directory contains runnable demos:

- **`src/example/`** — Basic string operations, cursor usage
- **`src/example/string/`** — String-specific operations (find, split, range, cursor staleness)
- **`src/example/pixel/`** — Custom `PixelRun` type (numeric, no Sliceable)
- **`src/example/authored/`** — Custom `AuthoredRun` type (with Sliceable, demonstrates selective merging)

Run any example with:

```bash
moon run src/example           # Basic demo
moon run src/example/pixel     # PixelRun demo
moon run src/example/authored  # AuthoredRun demo
moon run src/example/string    # String demo
```

## License

Apache-2.0
