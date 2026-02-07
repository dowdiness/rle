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
rle.len()    //=> 11
rle.find(6)  //=> Some({run: 0, offset: 6})

// Append merges automatically (strings always merge)
let rle = @rle.Rle::new()
rle.append("hello")   // Ok(())
rle.append(" world")  // Ok(()) — merged into one run
rle.count()            //=> 1
rle.to_string()        //=> "hello world"

// Split at any position
let (left, right) = rle.split(5).unwrap()
left.to_string()   //=> "hello"
right.to_string()  //=> " world"

// Range iteration returns slices without copying
let slices = rle.range(start=1, end=4).unwrap().collect()
match slices[0].to_inner() {
  Ok(value) => value  //=> "ell"
  Err(_) => ""
}
```

### Batch Construction

Build from an array in a single pass. Empty elements are skipped and adjacent ones merged:

```moonbit
let rle = @rle.Rle::from_array(["a", "", "b", "", "c"])
rle.count()       //=> 1  (all merged into "abc")
rle.to_string()   //=> "abc"
```

### Cursor for Sequential Traversal

Cursors track their position and detect mutations:

```moonbit
let rle = @rle.Rle::from_string("abcdef")
let cursor = rle.cursor()

cursor.advance(3)          //=> true
cursor.position()          //=> Some(3)
cursor.current_item()      //=> Some("abcdef")

// Mutation invalidates the cursor
rle.append("ghi")
cursor.is_stale()          //=> true
cursor.next()              //=> None (stale cursors refuse to operate)
```

### Concatenation and Extension

```moonbit
// Non-mutating concat
let a = @rle.Rle::from_string("hello")
let b = @rle.Rle::from_string(" world")
let c = a.concat(b)
c.to_string()  //=> "hello world"

// In-place extend
let rle = @rle.Rle::from_string("hello")
rle.extend(@rle.Rle::from_string(" world"))
rle.to_string()  //=> "hello world"
```

## Custom Types

To use `Rle` with your own types, implement the required traits:

```moonbit
// Minimal: Mergeable + HasLength + Spanning
pub impl @rle.Mergeable for MyRun with can_merge(a, b) {
  a.author == b.author  // merge runs from the same author
}

pub impl @rle.Mergeable for MyRun with merge(a, b) {
  { author: a.author, text: a.text + b.text }
}

pub impl @rle.HasLength for MyRun with length(self) {
  self.text.length()
}

pub impl @rle.Spanning for MyRun with content_len(self) {
  self.text.length()  // for plain content, same as length
}

// Optional: Sliceable (needed for split and range iteration)
pub impl @rle.Sliceable for MyRun with slice(self, start~, end~) {
  { author: self.author, text: self.text.substring(start~, end~) }
}
```

### Dual-Length Semantics

The `Spanning` trait provides two length notions:

- **`span`** — total size in the position/index space (defaults to `length`). Used for lookups.
- **`content_len`** — visible payload size. May be less than `span`.

This distinction is useful for CRDTs (tombstones occupy index space but have no visible content), gap buffers (gap occupies space but isn't content), and similar structures:

```moonbit
pub impl @rle.Spanning for CrdtRun with span(self) {
  self.len  // includes tombstones
}

pub impl @rle.Spanning for CrdtRun with content_len(self) {
  if self.deleted { 0 } else { self.len }
}
```

## API Overview

### Rle[T]

| Method | Complexity | Description |
|--------|-----------|-------------|
| `Rle::new()` | O(1) | Empty RLE sequence |
| `Rle::from_array(arr)` | O(n) | Batch construct with merging |
| `Rle::from_string(s)` | O(1) | Create from string |
| `len()` | O(1)* | Total span length |
| `content_len()` | O(1)* | Total content length |
| `count()` | O(1) | Number of runs |
| `find(pos)` | O(log n)* | Find run containing position |
| `append(elem)` | O(1) amortized | Append with auto-merge |
| `split(pos)` | O(n) | Split into two at position |
| `concat(other)` | O(n) | Non-mutating concatenation |
| `extend(other)` | O(m) | In-place extension |
| `range(start~, end~)` | O(log n + k)* | Iterate slices in range |
| `range_clamped(start~, end~)` | O(log n + k)* | Range with auto-clamped bounds |
| `clear()` | O(1) | Remove all runs |
| `cursor()` | O(1) | Create traversal cursor |
| `iter()` | O(1) | Iterate over runs |

\* *Amortized O(1) — prefix sums are lazily rebuilt after mutations.*

### RleCursor[T]

| Method | Description |
|--------|-------------|
| `advance(n)` | Move forward by n positions |
| `retreat(n)` | Move backward by n positions |
| `seek(pos)` | Jump to absolute position (uses binary search) |
| `next()` / `prev()` | Get item and move by one |
| `current()` | Current (item, offset) pair |
| `position()` | Current global position |
| `is_stale()` | Whether the underlying Rle has mutated |
| `iter_forward()` | Iterator from current position yielding (item, offset, global_pos) |

All cursor methods return `None` or `false` when stale.

### Error Handling

Operations return `Result[T, RleError]` with user-friendly messages:

```moonbit
match rle.split(100) {
  Ok((left, right)) => ...
  Err(e) => println(e.message())
  //=> "Position 100 is outside the document (length: 11)"
}
```

Slice extraction can now fail if a string slice lands on an invalid UTF-16
boundary. These failures surface as `InvalidSlice`:

```moonbit
match runs.split(1) {
  Ok(_) => ...
  Err(e) => println(e.message())
  //=> "Slice indices are not on valid boundaries"
}
```

## Performance

Position lookups use binary search over cached prefix sums, giving O(log n) instead of O(n) linear scans. The cache is rebuilt lazily — only when queried after a mutation — so batch writes don't pay for repeated rebuilds.

Run benchmarks with:

```bash
moon bench --package rle --release
```

## License

Apache-2.0
