# Example Package Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an `example/` package with practical, runnable examples for the `rle` library covering built-in String usage and two custom types.

**Architecture:** Single flat package at `example/`, three `.mbt` files, all examples expressed as `test` blocks using `inspect()` so `moon test --package example` runs them all without a `main` entry point.

**Tech Stack:** MoonBit, `dowdiness/rle/rle` (local package import)

---

### Task 1: Scaffold the example package

**Files:**
- Create: `example/moon.pkg.json`

**Step 1: Create moon.pkg.json**

```json
{
  "import": ["dowdiness/rle/rle"]
}
```

**Step 2: Verify the package is recognized**

Run: `moon check`
Expected: exits 0, no errors about the new package

**Step 3: Commit**

```bash
git add example/moon.pkg.json
git commit -m "feat(example): scaffold example package"
```

---

### Task 2: String examples

**Files:**
- Create: `example/string_examples.mbt`

This file demonstrates every major Rle API using the built-in String type.

**Step 1: Write the test file**

```moonbit
/// String examples for the rle library

///|
test "basic construction and span" {
  let rle = @rle.Rle::from_string("hello world")
  inspect(rle.span(), content="11")
  inspect(rle.length(), content="1") // one run — strings always merge
  inspect(rle.logical_length(), content="11")
}

///|
test "append auto-merges adjacent strings" {
  let rle : @rle.Rle[String] = @rle.Rle::new()
  let _ = rle.append("hello")
  let _ = rle.append(", ")
  let _ = rle.append("world")
  inspect(rle.length(), content="1") // all merged
  inspect(rle.to_string(), content="hello, world")
}

///|
test "find returns run index and offset" {
  let rle = @rle.Rle::from_string("abcdef")
  inspect(rle.find(0), content="Some({run: 0, offset: 0})")
  inspect(rle.find(3), content="Some({run: 0, offset: 3})")
  inspect(rle.find(6), content="None") // past end
}

///|
test "range extracts a substring slice" {
  let rle = @rle.Rle::from_string("hello world")
  match rle.range(start=6, end=11) {
    Ok(iter) =>
      match iter.collect()[0].to_inner() {
        Ok(s) => inspect(s, content="world")
        Err(_) => fail("unexpected slice error")
      }
    Err(_) => fail("unexpected range error")
  }
}

///|
test "range_clamped silently clamps out-of-bounds" {
  let rle = @rle.Rle::from_string("hello")
  let slices = rle.range_clamped(start=-10, end=999).collect()
  match slices[0].to_inner() {
    Ok(s) => inspect(s, content="hello")
    Err(_) => fail("unexpected slice error")
  }
}

///|
test "split divides at position" {
  let rle = @rle.Rle::from_string("hello world")
  match rle.split(5) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="hello")
      inspect(right.to_string(), content=" world")
    }
    Err(_) => fail("unexpected split error")
  }
}

///|
test "concat produces new Rle" {
  let a = @rle.Rle::from_string("foo")
  let b = @rle.Rle::from_string("bar")
  let c = a.concat(b)
  inspect(c.to_string(), content="foobar")
  inspect(c.length(), content="1") // merged
}

///|
test "extend mutates in place" {
  let rle = @rle.Rle::from_string("foo")
  rle.extend(@rle.Rle::from_string("bar"))
  inspect(rle.to_string(), content="foobar")
}

///|
test "insert at position" {
  let rle = @rle.Rle::from_string("helo")
  let ins = @rle.Rle::from_string("l")
  match rle.insert(3, ins) {
    Ok(result) => inspect(result.to_string(), content="hello")
    Err(_) => fail("unexpected insert error")
  }
}

///|
test "delete a range" {
  let rle = @rle.Rle::from_string("hello world")
  match rle.delete(start=5, end=6) {
    Ok(result) => inspect(result.to_string(), content="helloworld")
    Err(_) => fail("unexpected delete error")
  }
}

///|
test "splice replaces a range" {
  let rle = @rle.Rle::from_string("hello world")
  let replacement = @rle.Rle::from_string("MoonBit")
  match rle.splice(start=6, end=11, replacement) {
    Ok(result) => inspect(result.to_string(), content="hello MoonBit")
    Err(_) => fail("unexpected splice error")
  }
}

///|
test "from_array batch construction" {
  let rle = @rle.Rle::from_array(["foo", "", "bar", "", "baz"])
  inspect(rle.length(), content="1") // all merged, empty entries skipped
  inspect(rle.to_string(), content="foobarbaz")
}

///|
test "cursor sequential traversal" {
  let rle = @rle.Rle::from_string("abcdef")
  let cursor = rle.cursor()
  inspect(cursor.is_stale(), content="false")
  let _ = cursor.advance(3)
  inspect(cursor.position(), content="Some(3)")
  inspect(cursor.current_item(), content="Some(\"abcdef\")")
}

///|
test "cursor becomes stale after mutation" {
  let rle = @rle.Rle::from_string("hello")
  let cursor = rle.cursor()
  let _ = rle.append(" world")
  inspect(cursor.is_stale(), content="true")
  inspect(cursor.next(), content="None") // stale cursors refuse to operate
}

///|
test "cursor seek jumps to position" {
  let rle = @rle.Rle::from_string("abcdefgh")
  let cursor = rle.cursor()
  inspect(cursor.seek(5), content="true")
  inspect(cursor.position(), content="Some(5)")
}

///|
test "error messages are user-friendly" {
  let rle = @rle.Rle::from_string("hello")
  match rle.split(99) {
    Ok(_) => fail("should have failed")
    Err(e) =>
      inspect(
        e.message(),
        content="Position 99 is outside the document (length: 5)",
      )
  }
}
```

**Step 2: Run tests**

Run: `moon test --package example`
Expected: all tests PASS

**Step 3: Commit**

```bash
git add example/string_examples.mbt
git commit -m "feat(example): add string usage examples"
```

---

### Task 3: AuthoredRun custom type

**Files:**
- Create: `example/authored_run.mbt`

Demonstrates a custom type with author-scoped merging — a minimal collaborative-text scenario.

**Step 1: Write the type, trait impls, and tests**

```moonbit
/// AuthoredRun: a run of text attributed to a single author.
/// Adjacent runs from the same author merge automatically.

///|
pub struct AuthoredRun {
  author : String
  text : String
} derive(Show, Eq)

///|
/// Two runs merge only when they share the same author.
pub impl @rle.Mergeable for AuthoredRun with can_merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> Bool {
  a.author == b.author
}

///|
/// Merge by concatenating the text, keeping the shared author.
pub impl @rle.Mergeable for AuthoredRun with merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> AuthoredRun {
  { author: a.author, text: a.text + b.text }
}

///|
/// Length is the UTF-16 code-unit count of the text.
pub impl @rle.HasLength for AuthoredRun with length(self : AuthoredRun) -> Int {
  self.text.length()
}

///|
/// Span equals length (no tombstones in this example).
pub impl @rle.Spanning for AuthoredRun with span(self : AuthoredRun) -> Int {
  self.text.length()
}

///|
/// Slice by extracting a substring of the text.
pub impl @rle.Sliceable for AuthoredRun with slice(
  self : AuthoredRun,
  start~ : Int,
  end~ : Int,
) -> Result[AuthoredRun, @rle.RleError] {
  match @rle.slice_string_view(self.text, start~, end~) {
    Ok(sliced) => Ok({ author: self.author, text: sliced })
    Err(_) =>
      Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
}

// ── helpers ──────────────────────────────────────────────────────────

///|
fn authored(author : String, text : String) -> AuthoredRun {
  { author, text }
}

// ── examples ─────────────────────────────────────────────────────────

///|
test "same-author runs merge" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("alice", ", world"))
  inspect(rle.length(), content="1") // merged
  match rle.get(0) {
    Some(run) => {
      inspect(run.author, content="alice")
      inspect(run.text, content="Hello, world")
    }
    None => fail("expected a run")
  }
}

///|
test "different-author runs stay separate" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", ", world"))
  inspect(rle.length(), content="2") // kept separate
}

///|
test "split at author boundary" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", " world"))
  match rle.split(5) {
    Ok((left, right)) => {
      inspect(left.length(), content="1")
      inspect(right.length(), content="1")
      match left.get(0) {
        Some(r) => inspect(r.author, content="alice")
        None => fail("expected left run")
      }
      match right.get(0) {
        Some(r) => inspect(r.author, content="bob")
        None => fail("expected right run")
      }
    }
    Err(_) => fail("unexpected split error")
  }
}

///|
test "range extracts slice across runs" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", " world"))
  // Extract positions 3..8 ("lo wo") — spans both runs
  match rle.range(start=3, end=8) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="2") // one slice per run
      match slices[0].to_inner() {
        Ok(r) => {
          inspect(r.author, content="alice")
          inspect(r.text, content="lo")
        }
        Err(_) => fail("unexpected slice error")
      }
      match slices[1].to_inner() {
        Ok(r) => {
          inspect(r.author, content="bob")
          inspect(r.text, content=" wo")
        }
        Err(_) => fail("unexpected slice error")
      }
    }
    Err(_) => fail("unexpected range error")
  }
}

///|
test "from_array merges same-author adjacent runs" {
  let runs = [
    authored("alice", "foo"),
    authored("alice", "bar"),
    authored("bob", "baz"),
  ]
  let rle = @rle.Rle::from_array(runs)
  inspect(rle.length(), content="2") // alice merged, bob separate
  match rle.get(0) {
    Some(r) => inspect(r.text, content="foobar")
    None => fail("expected run 0")
  }
}
```

**Step 2: Run tests**

Run: `moon test --package example`
Expected: all tests PASS

**Step 3: Commit**

```bash
git add example/authored_run.mbt
git commit -m "feat(example): add AuthoredRun custom type example"
```

---

### Task 4: PixelRun custom type

**Files:**
- Create: `example/pixel_run.mbt`

Demonstrates a numeric custom type: a scanline of colored pixel spans. No `Sliceable` needed — the example focuses on append, find, value_at, and iter.

**Step 1: Write the type, trait impls, and tests**

```moonbit
/// PixelRun: a run of `count` pixels of a single `color` (0xRRGGBB).
/// Adjacent runs of the same color merge by summing their counts.
/// Demonstrates a numeric, non-String custom type with no Sliceable.

///|
pub struct PixelRun {
  color : Int
  count : Int
} derive(Show, Eq)

///|
/// Two pixel runs merge when they share the same color.
pub impl @rle.Mergeable for PixelRun with can_merge(
  a : PixelRun,
  b : PixelRun,
) -> Bool {
  a.color == b.color
}

///|
/// Merge by summing counts, keeping the shared color.
pub impl @rle.Mergeable for PixelRun with merge(
  a : PixelRun,
  b : PixelRun,
) -> PixelRun {
  { color: a.color, count: a.count + b.count }
}

///|
/// Length is the pixel count.
pub impl @rle.HasLength for PixelRun with length(self : PixelRun) -> Int {
  self.count
}

///|
/// Span equals pixel count.
pub impl @rle.Spanning for PixelRun with span(self : PixelRun) -> Int {
  self.count
}

// ── helpers ──────────────────────────────────────────────────────────

///|
let red : Int = 0xFF0000

///|
let green : Int = 0x00FF00

///|
let blue : Int = 0x0000FF

///|
fn pixel(color : Int, count : Int) -> PixelRun {
  { color, count }
}

// ── examples ─────────────────────────────────────────────────────────

///|
test "same-color runs merge" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(red, 5))
  inspect(rle.length(), content="1") // merged
  match rle.get(0) {
    Some(run) => inspect(run.count, content="15")
    None => fail("expected a run")
  }
}

///|
test "different-color runs stay separate" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(green, 20))
  let _ = rle.append(pixel(blue, 30))
  inspect(rle.length(), content="3")
  inspect(rle.span(), content="60") // 10+20+30
}

///|
test "find returns the run at a pixel position" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(green, 20))
  let _ = rle.append(pixel(blue, 30))
  // Position 25 is inside the green run (starts at 10)
  inspect(rle.find(25), content="Some({run: 1, offset: 15})")
}

///|
test "value_at returns the run containing a position" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(green, 20))
  let _ = rle.append(pixel(blue, 30))
  match rle.value_at(25) {
    Ok(run) => {
      inspect(run.color, content="65280") // 0x00FF00 = 65280
      inspect(run.count, content="20")
    }
    Err(_) => fail("unexpected error")
  }
}

///|
test "iter enumerates all runs in order" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(green, 20))
  let _ = rle.append(pixel(blue, 30))
  let colors = rle.iter().map(fn(r) { r.color }).collect()
  inspect(colors, content="[16711680, 65280, 255]")
  // 0xFF0000=16711680, 0x00FF00=65280, 0x0000FF=255
}

///|
test "from_array batch-merges same-color runs" {
  let pixels = [
    pixel(red, 5),
    pixel(red, 3),
    pixel(green, 10),
    pixel(green, 10),
    pixel(blue, 1),
  ]
  let rle = @rle.Rle::from_array(pixels)
  inspect(rle.length(), content="3") // red(8), green(20), blue(1)
  match rle.get(0) {
    Some(r) => inspect(r.count, content="8")
    None => fail("expected run 0")
  }
  match rle.get(1) {
    Some(r) => inspect(r.count, content="20")
    None => fail("expected run 1")
  }
}

///|
test "cursor traverses pixel runs" {
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  let _ = rle.append(pixel(red, 10))
  let _ = rle.append(pixel(green, 20))
  let cursor = rle.cursor()
  inspect(cursor.is_stale(), content="false")
  // advance past the red run
  let _ = cursor.advance(10)
  inspect(cursor.position(), content="Some(10)")
  match cursor.current_item() {
    Some(run) => inspect(run.color, content="65280") // green
    None => fail("expected green run")
  }
}
```

**Step 2: Run tests**

Run: `moon test --package example`
Expected: all tests PASS

**Step 3: Commit**

```bash
git add example/pixel_run.mbt
git commit -m "feat(example): add PixelRun custom type example"
```
