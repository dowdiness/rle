// PixelRun: a run of `count` pixels of a single `color` (0xRRGGBB).
// Adjacent runs of the same color merge by summing their counts.
// Demonstrates a numeric custom type with no Sliceable.

///|
struct PixelRun {
  color : Int
  count : Int
} derive(Show, Eq)

///|
impl @rle.Mergeable for PixelRun with can_merge(a : PixelRun, b : PixelRun) -> Bool {
  a.color == b.color
}

///|
impl @rle.Mergeable for PixelRun with merge(a : PixelRun, b : PixelRun) -> PixelRun {
  { color: a.color, count: a.count + b.count }
}

///|
impl @rle.HasLength for PixelRun with length(self : PixelRun) -> Int {
  self.count
}

///|
impl @rle.Spanning for PixelRun with span(self : PixelRun) -> Int {
  self.count
}

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

///|
fn main {
  println("=== Same-Color Merge ===")
  let rle : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle.append(pixel(red, 10)) |> println //=> Ok(())
  rle.append(pixel(red, 5)) |> println //=> Ok(())
  rle.length() |> println //=> 1  (merged)
  rle.get(0) |> println //=> Some({color: 16711680, count: 15})

  println("\n=== Multi-Color Scanline ===")
  let rle2 : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle2.append(pixel(red, 10)) |> println
  rle2.append(pixel(green, 20)) |> println
  rle2.append(pixel(blue, 30)) |> println
  rle2.length() |> println //=> 3
  rle2.span() |> println //=> 60  (10+20+30)

  println("\n=== Find Run at Position ===")
  // red: 0-9, green: 10-29, blue: 30-59
  rle2.find(0) |> println //=> Some({run: 0, offset: 0})
  rle2.find(25) |> println //=> Some({run: 1, offset: 15})
  rle2.find(59) |> println //=> Some({run: 2, offset: 29})

  println("\n=== Value At Position ===")
  match rle2.value_at(25) {
    Ok(run) => run |> println //=> {color: 65280, count: 20}  (green)
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
  rle3.length() |> println //=> 3  (red=8, green=20, blue=1)
  rle3.get(0) |> println //=> Some({color: 16711680, count: 8})
  rle3.get(1) |> println //=> Some({color: 65280,    count: 20})
  rle3.get(2) |> println //=> Some({color: 255,      count: 1})

  println("\n=== Cursor ===")
  let rle4 : @rle.Rle[PixelRun] = @rle.Rle::new()
  rle4.append(pixel(red, 10)) |> println
  rle4.append(pixel(green, 20)) |> println
  let cursor = rle4.cursor()
  cursor.advance(10) |> println //=> true  (moved past red)
  cursor.position() |> println //=> Some(10)
  cursor.current_item() |> println //=> Some({color: 65280, count: 20})  (green)
}
