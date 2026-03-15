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
  inspect(rle.find(6), content="Some({run: 0, offset: 6})")
}
```

Append merges automatically (strings always merge into one run):

```mbt check
///|
test {
  let rle : @rle.Rle[String] = @rle.Rle::new()
  let _ = rle.append("hello")
  let _ = rle.append(" world")
  inspect(rle.length(), content="1")
  inspect(rle.to_string(), content="hello world")
}
```

Split at any position:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello world")
  let (left, right) = rle.split(5).unwrap()
  inspect(left.to_string(), content="hello")
  inspect(right.to_string(), content=" world")
}
```

Range iteration returns lazy slices without copying:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello world")
  let slices = rle.range(start=1, end=4).unwrap().collect()
  inspect(slices.length(), content="1")
  let s = slices[0]
  inspect(
    @rle.Sliceable::slice(s.value, start=s.start, end=s.end),
    content="Ok(\"ell\")",
  )
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
  let result = rle.insert(2, elem).unwrap()
  inspect(result.to_string(), content="hello")
}
```

```mbt check
///|
test {
  // Delete a range
  let rle = @rle.Rle::from_string("hello world")
  let result = rle.delete(start=5, end=6).unwrap()
  inspect(result.to_string(), content="helloworld")
}
```

```mbt check
///|
test {
  // Splice: replace a range with new content
  let rle = @rle.Rle::from_string("hello world")
  let replacement = @rle.Rle::from_string("beautiful ")
  let result = rle.splice(start=6, end=11, replacement).unwrap()
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
  inspect(cursor.position(), content="Some(3)")
  inspect(cursor.current_item(), content="Some(\"abcdef\")")

  // seek() uses binary search — O(log n)
  inspect(cursor.seek(1), content="true")
  inspect(cursor.position(), content="Some(1)")
}
```

Mutation invalidates the cursor:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("abcdef")
  let cursor = rle.cursor()
  let _ = cursor.advance(3)

  let _ = rle.append("ghi")
  inspect(cursor.is_stale(), content="true")
  inspect(cursor.next(), content="None")
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
  rle.extend(@rle.Rle::from_string(" world"))
  inspect(rle.to_string(), content="hello world")
}
```

## Position Lookup

`find` returns the run index and offset within that run:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  inspect(rle.find(0), content="Some({run: 0, offset: 0})")
  inspect(rle.find(4), content="Some({run: 0, offset: 4})")
  inspect(rle.find(5), content="None")
  inspect(rle.find(-1), content="None")
}
```

`value_at` returns the full run containing a position:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  inspect(rle.value_at(2), content="Ok(\"hello\")")
  inspect(rle.value_at(5) is Err(_), content="true")
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
  let _ = rle.append(" world") // invalidates cache
  // next query rebuilds automatically
  inspect(rle.span(), content="11")
}
```

## Cursor Version Tracking

The version counter increments on every mutation:

```mbt check
///|
test {
  let rle : @rle.Rle[String] = @rle.Rle::new()
  inspect(rle.get_version(), content="0")
  let _ = rle.append("a")
  inspect(rle.get_version(), content="1")
  let _ = rle.append("b")
  inspect(rle.get_version(), content="2")
  rle.clear()
  inspect(rle.get_version(), content="3")
}
```

## Error Handling

Operations return `Result[T, RleError]` with user-friendly messages:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.split(100) {
    Ok(_) => fail("should fail")
    Err(e) =>
      inspect(
        e.message(),
        content="Position 100 is outside the document (length: 5)",
      )
  }
}
```

Range validation provides specific reasons:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.range(start=-1, end=3) {
    Ok(_) => fail("should fail")
    Err(e) =>
      inspect(e.message(), content="Range start (-1) cannot be negative")
  }
}
```

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.range(start=0, end=10) {
    Ok(_) => fail("should fail")
    Err(e) =>
      inspect(e.message(), content="Range end (10) exceeds document length (5)")
  }
}
```

Appending an empty string returns an error:

```mbt check
///|
test {
  let rle : @rle.Rle[String] = @rle.Rle::new()
  inspect(rle.append(""), content="Err(Internal(EmptyElement))")
}
```

## UTF-16 String Indices

All string indices are in UTF-16 code units. Emoji like "😀" occupy 2 code units:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("A😀B")
  inspect(rle.span(), content="4") // A(1) + 😀(2) + B(1)
}
```

Splitting inside a surrogate pair returns an error:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("😀")
  inspect(rle.span(), content="2")
  match rle.split(1) {
    Ok(_) => fail("should fail on invalid boundary")
    Err(e) => inspect(e, content="InvalidSlice(reason=InvalidIndex)")
  }
}
```

Valid emoji boundaries work correctly:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("A😀B")
  // Position 3 is after the emoji, before B — valid boundary
  match rle.range(start=0, end=3) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="1")
    }
    Err(_) => fail("range should succeed")
  }
}
```

## Unicode Support

BMP characters (CJK) work as expected:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("こんにちは")
  inspect(rle.span(), content="5")
  inspect(rle.find(2), content="Some({run: 0, offset: 2})")
  match rle.split(1) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="こ")
      inspect(right.to_string(), content="んにちは")
    }
    Err(_) => fail("split should work with unicode")
  }
}
```

## Empty Ranges and Edge Cases

Empty range (start == end) is valid and returns empty iterator:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.range(start=2, end=2) {
    Ok(iter) => inspect(iter.collect().length(), content="0")
    Err(_) => fail("empty range should succeed")
  }
}
```

Delete empty range is a no-op:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  match rle.delete(start=2, end=2) {
    Ok(result) => inspect(result.to_string(), content="hello")
    Err(_) => fail("delete empty range should succeed")
  }
}
```

Split at boundaries:

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  // Split at start
  let (left, right) = rle.split(0).unwrap()
  inspect(left.to_string(), content="")
  inspect(right.to_string(), content="hello")
}
```

```mbt check
///|
test {
  let rle = @rle.Rle::from_string("hello")
  // Split at end
  let (left, right) = rle.split(5).unwrap()
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
    content="Ok(\"hello\")",
  )
}
```
