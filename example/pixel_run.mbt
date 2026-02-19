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
