# Example Sub-packages Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the test-block example files with three runnable sub-packages (`example/string/`, `example/authored/`, `example/pixel/`) that demonstrate the rle library via `fn main` + `println`.

**Architecture:** Each sub-package is an independent MoonBit binary package (`is-main: true`) with a single `main.mbt` file. Custom types (AuthoredRun, PixelRun) are defined in the same file as their demos. The existing `example/` package is kept untouched except for removing the three test files added in the previous session.

**Tech Stack:** MoonBit, `dowdiness/rle/rle` (local package import). Run with `moon run --package <path>`.

---

### Task 1: Remove test files from example/

**Files:**
- Delete: `example/string_examples.mbt`
- Delete: `example/authored_run.mbt`
- Delete: `example/pixel_run.mbt`

**Step 1: Delete the three test files**

```bash
rm example/string_examples.mbt example/authored_run.mbt example/pixel_run.mbt
```

**Step 2: Verify the example package still builds**

Run: `moon check`
Expected: exits 0, no errors

**Step 3: Commit**

```bash
git add -u example/
git commit -m "chore(example): remove test-block example files"
```

---

### Task 2: String demo sub-package

**Files:**
- Create: `example/string/moon.pkg`
- Create: `example/string/main.mbt`

**Step 1: Create moon.pkg**

```
import {
  "dowdiness/rle/rle"
}

options(
  "is-main": true
)
```

**Step 2: Create main.mbt**

```moonbit
fn main {
  println("=== Construction & Span ===")
  let rle = @rle.Rle::from_string("hello world")
  rle.span() |> println            //=> 11
  rle.length() |> println          //=> 1  (one run — strings always merge)
  rle.logical_length() |> println  //=> 11

  println("\n=== Find ===")
  rle.find(0) |> println   //=> Some({run: 0, offset: 0})
  rle.find(6) |> println   //=> Some({run: 0, offset: 6})
  rle.find(11) |> println  //=> None  (past end)

  println("\n=== Append (auto-merge) ===")
  let rle2 : @rle.Rle[String] = @rle.Rle::new()
  rle2.append("hello") |> println   //=> Ok(())
  rle2.append(", ") |> println      //=> Ok(())
  rle2.append("world") |> println   //=> Ok(())
  rle2.length() |> println          //=> 1  (all merged)
  rle2.to_string() |> println       //=> hello, world

  println("\n=== Split ===")
  match rle.split(5) {
    Ok((left, right)) => {
      left.to_string() |> println   //=> hello
      right.to_string() |> println  //=> " world"
    }
    Err(e) => e |> println
  }

  println("\n=== Concat ===")
  let a = @rle.Rle::from_string("foo")
  let b = @rle.Rle::from_string("bar")
  let c = a.concat(b)
  c.to_string() |> println  //=> foobar
  c.length() |> println     //=> 1  (merged)

  println("\n=== Range ===")
  let rle3 = @rle.Rle::from_string("hello world")
  match rle3.range(start=6, end=11) {
    Ok(iter) =>
      iter.each(fn(slice) {
        match slice.to_inner() {
          Ok(s) => s |> println  //=> world
          Err(e) => e |> println
        }
      })
    Err(e) => e |> println
  }

  println("\n=== From Array (empty entries skipped) ===")
  let rle4 = @rle.Rle::from_array(["foo", "", "bar", "", "baz"])
  rle4.length() |> println     //=> 1
  rle4.to_string() |> println  //=> foobarbaz

  println("\n=== Cursor ===")
  let rle5 = @rle.Rle::from_string("abcdef")
  let cursor = rle5.cursor()
  cursor.advance(3) |> println      //=> true
  cursor.position() |> println      //=> Some(3)
  cursor.current_item() |> println  //=> Some("abcdef")
  cursor.seek(0) |> println         //=> true
  cursor.position() |> println      //=> Some(0)

  println("\n=== Cursor Staleness ===")
  let rle6 = @rle.Rle::from_string("hello")
  let cursor2 = rle6.cursor()
  rle6.append(" world") |> println  //=> Ok(())
  cursor2.is_stale() |> println     //=> true
  cursor2.next() |> println         //=> None  (stale)

  println("\n=== Error Messages ===")
  match rle.split(99) {
    Ok(_) => println("unexpected Ok")
    Err(e) => e.message() |> println
    //=> Position 99 is outside the document (length: 11)
  }
}
```

**Step 3: Run the demo**

Run: `moon run --package example/string`
Expected: output matching the `//=>` comments, no panics

**Step 4: Commit**

```bash
git add example/string/
git commit -m "feat(example/string): add runnable string demo"
```

---

### Task 3: AuthoredRun demo sub-package

**Files:**
- Create: `example/authored/moon.pkg`
- Create: `example/authored/main.mbt`

**Step 1: Create moon.pkg**

```
import {
  "dowdiness/rle/rle"
}

options(
  "is-main": true
)
```

**Step 2: Create main.mbt**

Define the type, trait impls, and demo all in one file:

```moonbit
// AuthoredRun: a run of text attributed to a single author.
// Adjacent runs from the same author merge automatically.

struct AuthoredRun {
  author : String
  text : String
} derive(Show, Eq)

impl @rle.Mergeable for AuthoredRun with can_merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> Bool {
  a.author == b.author
}

impl @rle.Mergeable for AuthoredRun with merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> AuthoredRun {
  { author: a.author, text: a.text + b.text }
}

impl @rle.HasLength for AuthoredRun with length(self : AuthoredRun) -> Int {
  self.text.length()
}

impl @rle.Spanning for AuthoredRun with span(self : AuthoredRun) -> Int {
  self.text.length()
}

impl @rle.Sliceable for AuthoredRun with slice(
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

fn authored(author : String, text : String) -> AuthoredRun {
  { author, text }
}

fn main {
  println("=== Same-Author Merge ===")
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  rle.append(authored("alice", "Hello")) |> println   //=> Ok(())
  rle.append(authored("alice", ", world")) |> println //=> Ok(())
  rle.length() |> println  //=> 1  (merged)
  rle.get(0) |> println    //=> Some({author: "alice", text: "Hello, world"})

  println("\n=== Different-Author Separation ===")
  let rle2 : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  rle2.append(authored("alice", "Hello")) |> println
  rle2.append(authored("bob", " world")) |> println
  rle2.length() |> println  //=> 2  (kept separate)
  rle2.get(0) |> println    //=> Some({author: "alice", text: "Hello"})
  rle2.get(1) |> println    //=> Some({author: "bob",   text: " world"})

  println("\n=== Split at Author Boundary ===")
  match rle2.split(5) {
    Ok((left, right)) => {
      left.length() |> println   //=> 1
      right.length() |> println  //=> 1
      left.get(0) |> println     //=> Some({author: "alice", text: "Hello"})
      right.get(0) |> println    //=> Some({author: "bob",   text: " world"})
    }
    Err(e) => e |> println
  }

  println("\n=== Range Across Runs ===")
  // "Hello" (alice, 0-4) + " world" (bob, 5-10)
  // range(3, 8) → "lo" from alice, " wo" from bob
  match rle2.range(start=3, end=8) {
    Ok(iter) =>
      iter.each(fn(slice) {
        match slice.to_inner() {
          Ok(r) => println("\{r.author}: \{r.text}")
          Err(e) => e |> println
        }
      })
      //=> alice: lo
      //=> bob:  wo
    Err(e) => e |> println
  }

  println("\n=== From Array (same-author merges) ===")
  let runs = [
    authored("alice", "foo"),
    authored("alice", "bar"),
    authored("bob", "baz"),
  ]
  let rle3 = @rle.Rle::from_array(runs)
  rle3.length() |> println  //=> 2  (alice merged, bob separate)
  rle3.get(0) |> println    //=> Some({author: "alice", text: "foobar"})
  rle3.get(1) |> println    //=> Some({author: "bob",   text: "baz"})
}
```

**Step 3: Run the demo**

Run: `moon run --package example/authored`
Expected: output matching the `//=>` comments, no panics

**Step 4: Commit**

```bash
git add example/authored/
git commit -m "feat(example/authored): add runnable AuthoredRun demo"
```

---

### Task 4: PixelRun demo sub-package

**Files:**
- Create: `example/pixel/moon.pkg`
- Create: `example/pixel/main.mbt`

**Step 1: Create moon.pkg**

```
import {
  "dowdiness/rle/rle"
}

options(
  "is-main": true
)
```

**Step 2: Create main.mbt**

```moonbit
// PixelRun: a run of `count` pixels of a single `color` (0xRRGGBB).
// Adjacent runs of the same color merge by summing their counts.
// Demonstrates a numeric custom type with no Sliceable.

struct PixelRun {
  color : Int
  count : Int
} derive(Show, Eq)

impl @rle.Mergeable for PixelRun with can_merge(
  a : PixelRun,
  b : PixelRun,
) -> Bool {
  a.color == b.color
}

impl @rle.Mergeable for PixelRun with merge(
  a : PixelRun,
  b : PixelRun,
) -> PixelRun {
  { color: a.color, count: a.count + b.count }
}

impl @rle.HasLength for PixelRun with length(self : PixelRun) -> Int {
  self.count
}

impl @rle.Spanning for PixelRun with span(self : PixelRun) -> Int {
  self.count
}

let red : Int = 0xFF0000
let green : Int = 0x00FF00
let blue : Int = 0x0000FF

fn pixel(color : Int, count : Int) -> PixelRun {
  { color, count }
}

fn main {
  println("=== Same-Color Merge ===")
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle.append(pixel(red, 10)) |> println  //=> Ok(())
  rle.append(pixel(red, 5)) |> println   //=> Ok(())
  rle.length() |> println                //=> 1  (merged)
  rle.get(0) |> println                  //=> Some({color: 16711680, count: 15})

  println("\n=== Multi-Color Scanline ===")
  let rle2 : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle2.append(pixel(red, 10)) |> println
  rle2.append(pixel(green, 20)) |> println
  rle2.append(pixel(blue, 30)) |> println
  rle2.length() |> println  //=> 3
  rle2.span() |> println    //=> 60  (10+20+30)

  println("\n=== Find Run at Position ===")
  // red: 0-9, green: 10-29, blue: 30-59
  rle2.find(0) |> println   //=> Some({run: 0, offset: 0})
  rle2.find(25) |> println  //=> Some({run: 1, offset: 15})
  rle2.find(59) |> println  //=> Some({run: 2, offset: 29})

  println("\n=== Value At Position ===")
  match rle2.value_at(25) {
    Ok(run) => run |> println  //=> {color: 65280, count: 20}  (green)
    Err(e) => e |> println
  }

  println("\n=== Iter All Runs ===")
  rle2.iter().each(fn(r) { println("\{r.color} x\{r.count}") })
  //=> 16711680 x10  (red)
  //=> 65280 x20     (green)
  //=> 255 x30       (blue)

  println("\n=== From Array (batch merge) ===")
  let pixels = [
    pixel(red, 5),
    pixel(red, 3),
    pixel(green, 10),
    pixel(green, 10),
    pixel(blue, 1),
  ]
  let rle3 = @rle.Rle::from_array(pixels)
  rle3.length() |> println  //=> 3  (red=8, green=20, blue=1)
  rle3.get(0) |> println    //=> Some({color: 16711680, count: 8})
  rle3.get(1) |> println    //=> Some({color: 65280,    count: 20})
  rle3.get(2) |> println    //=> Some({color: 255,      count: 1})

  println("\n=== Cursor ===")
  let rle4 : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle4.append(pixel(red, 10)) |> println
  rle4.append(pixel(green, 20)) |> println
  let cursor = rle4.cursor()
  cursor.advance(10) |> println     //=> true  (moved past red)
  cursor.position() |> println      //=> Some(10)
  cursor.current_item() |> println  //=> Some({color: 65280, count: 20})  (green)
}
```

**Step 3: Run the demo**

Run: `moon run --package example/pixel`
Expected: output matching the `//=>` comments, no panics

**Step 4: Commit**

```bash
git add example/pixel/
git commit -m "feat(example/pixel): add runnable PixelRun demo"
```
