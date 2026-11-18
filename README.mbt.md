# rle

Generic run-length encoded sequence for MoonBit with O(log n) position lookup.

## Quick Start

### Working with Strings

Strings implement all required traits out of the box:

```mbt check
///|
test {
  // Create from a string
  let rle = @rle.Rle::from_string("hello world")

  // Length and lookup
  inspect(rle.span(), content="11")
  match rle.find(6) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="6")
    }
    None => fail("find should succeed")
  }
}
```

Append merges automatically (strings always merge into one run):

```mbt check
///|
test {
  let rle : @rle.Rle[String] = @rle.Rle::Rle()
  rle.append("hello")
  rle.append(" world")
  inspect(rle.length(), content="1")
  inspect(rle.to_string(), content="hello world")
}
```

Split at any position:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello world")
  let (left, right) = rle.split(5)
  inspect(left.to_string(), content="hello")
  inspect(right.to_string(), content=" world")
}
```

Range iteration returns lazy slices without copying:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello world")
  let slices = rle.range(start=1, end=4).collect()
  inspect(slices.length(), content="1")
  inspect(slices[0].to_inner(), content="ell")
}
```

### Batch Construction

Build from an array in a single O(n) pass. Empty elements are skipped and adjacent ones merged:

```mbt check
///|
test {
  let rle = @rle.Rle::from_array(["a", "", "b", "", "c"])
  inspect(rle.length(), content="1")
  inspect(rle.to_string(), content="abc")
}
```

### Editing Operations

Insert, delete, and splice at any position. These produce new `Rle` values:

```mbt check
///|
test {
  // Insert at position
  let rle = @rle.Rle::from_string("helo")
  let elem = @rle.Rle::from_string("l")
  let result = rle.insert(2, elem)
  inspect(result.to_string(), content="hello")
}
```

```mbt check
///|
test {
  // Delete a range
  let rle = @rle.Rle::from_string("hello world")
  let result = rle.delete(start=5, end=6)
  inspect(result.to_string(), content="helloworld")
}
```

```mbt check
///|
test {
  // Splice: replace a range with new content
  let rle = @rle.Rle::from_string("hello world")
  let replacement = @rle.Rle::from_string("beautiful ")
  let result = rle.splice(start=6, end=11, replacement)
  inspect(result.to_string(), content="hello beautiful ")
}
```

### Cursor for Sequential Traversal

Cursors track position and detect mutations:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("abcdef")
  let cursor = rle.cursor()

  inspect(cursor.advance(3), content="true")
  match cursor.position() {
    Some(position) => inspect(position, content="3")
    None => fail("cursor position should be available")
  }
  match cursor.current_item() {
    Some(item) => inspect(item, content="abcdef")
    None => fail("cursor item should be available")
  }

  // seek() uses binary search — O(log n)
  inspect(cursor.seek(1), content="true")
  match cursor.position() {
    Some(position) => inspect(position, content="1")
    None => fail("cursor position should be available")
  }
}
```

Mutation invalidates the cursor:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("abcdef")
  let cursor = rle.cursor()
  let _ = cursor.advance(3)

  rle.append("ghi")
  inspect(cursor.is_stale(), content="true")
  inspect(cursor.next() is None, content="true")
}
```

### Concatenation and Extension

```mbt check
///|
test {
  // Non-mutating concat — returns a new Rle
  let a = @rle.Rle::from_string("hello")
  let b = @rle.Rle::from_string(" world")
  let c = a.concat(b)
  inspect(c.to_string(), content="hello world")
}
```

```mbt check
///|
test {
  // In-place extend — mutates the receiver
  let rle = @rle.Rle::from_string("hello")
  rle.extend_from(@rle.Rle::from_string(" world"))
  inspect(rle.to_string(), content="hello world")
}
```

## Position Lookup

`find` returns the run index and offset within that run:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.find(0) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="0")
    }
    None => fail("find should succeed")
  }
  match rle.find(4) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="4")
    }
    None => fail("find should succeed")
  }
  inspect(rle.find(5) is None, content="true")
  inspect(rle.find(-1) is None, content="true")
}
```

`value_at` returns the full run containing a position:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  inspect(rle.value_at(2), content="hello")
  // Invalid positions raise RleError; optional lookup remains available via find.
  inspect(rle.find(5) is None, content="true")
}
```

## Dual-Length Semantics

`span()` and `logical_length()` are equal for strings:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  inspect(rle.span(), content="5")
  inspect(rle.logical_length(), content="5")
  inspect(rle.span() == rle.logical_length(), content="true")
}
```

## Lazy Prefix Sum Caching

Prefix sums are rebuilt lazily — mutations invalidate the cache, queries rebuild it:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  let _ = rle.span() // builds cache
  rle.append(" world") // invalidates cache
  // next query rebuilds automatically
  inspect(rle.span(), content="11")
}
```

## Cursor Version Tracking

The version counter increments on every mutation:

```mbt check
///|
test {
  let rle : @rle.Rle[String] = @rle.Rle::Rle()
  inspect(rle.get_version(), content="0")
  rle.append("a")
  inspect(rle.get_version(), content="1")
  rle.append("b")
  inspect(rle.get_version(), content="2")
  rle.clear()
  inspect(rle.get_version(), content="3")
}
```

## Error Handling

Fallible operations raise `RleError` directly. They propagate automatically to a
caller that can raise, or can be handled with typed `try`/`catch`. Optional
lookups such as `find`, `get`, and cursor access remain `Option`-based.

Successful calls need no `Result` matching or unwrap:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  let (left, right) = rle.split(2)
  inspect(left.to_string(), content="he")
  inspect(right.to_string(), content="llo")
}
```

Handle a specific error variant with `catch`:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  try rle.split(100) catch {
    @rle.RleError::PositionOutOfBounds(position~, length~) =>
      inspect(
        "Position \{position} is outside the document (length: \{length})",
        content="Position 100 is outside the document (length: 5)",
      )
    error => raise error
  } noraise {
    _ => fail("expected an out-of-bounds error")
  }
}
```

Invalid ranges raise `RleError::InvalidRange`; an empty append raises an
`InternalError` wrapped by `RleError::Internal`.

## UTF-16 String Indices

All string indices are in UTF-16 code units. Emoji like "😀" occupy 2 code units:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("A😀B")
  inspect(rle.span(), content="4") // A(1) + 😀(2) + B(1)
}
```

Splitting inside a surrogate pair raises an error:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("😀")
  inspect(rle.span(), content="2")
  try rle.split(1) catch {
    @rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex) =>
      inspect(
        "Slice indices are not on valid boundaries",
        content="Slice indices are not on valid boundaries",
      )
    error => raise error
  } noraise {
    _ => fail("expected an invalid UTF-16 boundary error")
  }
}
```

Valid emoji boundaries work correctly:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("A😀B")
  // Position 3 is after the emoji, before B — valid boundary
  let slices = rle.range(start=0, end=3).collect()
  inspect(slices.length(), content="1")
}
```

## Unicode Support

BMP characters (CJK) work as expected:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("こんにちは")
  inspect(rle.span(), content="5")
  match rle.find(2) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="2")
    }
    None => fail("find should succeed")
  }
  let (left, right) = rle.split(1)
  inspect(left.to_string(), content="こ")
  inspect(right.to_string(), content="んにちは")
}
```

## Empty Ranges and Edge Cases

Empty range (start == end) is valid and returns empty iterator:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  let iter = rle.range(start=2, end=2)
  inspect(iter.collect().length(), content="0")
}
```

Delete empty range is a no-op:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  let result = rle.delete(start=2, end=2)
  inspect(result.to_string(), content="hello")
}
```

Split at boundaries:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  // Split at start
  let (left, right) = rle.split(0)
  inspect(left.to_string(), content="")
  inspect(right.to_string(), content="hello")
}
```

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  // Split at end
  let (left, right) = rle.split(5)
  inspect(left.to_string(), content="hello")
  inspect(right.to_string(), content="")
}
```

## Clamped Range

`range_clamped` auto-clamps bounds instead of returning errors:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  let slices = rle.range_clamped(start=-5, end=100).collect()
  inspect(slices.length(), content="1")
  let s = slices[0]
  inspect(
    @rle.Sliceable::slice(s.value, start=s.start, end=s.end),
    content="hello",
  )
}
```
