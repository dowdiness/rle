// PixelRun: a run of `count` pixels of a single `color` (0xRRGGBB).
// Adjacent runs of the same color merge by summing their counts.
// Demonstrates a numeric custom type with no Sliceable.

///|
struct PixelRun {
  color : Int
  count : Int
} derive(Debug, Eq)

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
/// span() delegates to length() here — both return pixel count.
/// Override span() only when it should differ from length (e.g., CRDT tombstones).
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
fn print_pixel(run : PixelRun) -> Unit {
  println("{color: \{run.color}, count: \{run.count}}")
}

///|
fn print_pixel_opt(run : PixelRun?) -> Unit {
  match run {
    Some(run) => println("Some({color: \{run.color}, count: \{run.count}})")
    None => println("None")
  }
}

///|
fn print_run_pos(pos : @rle.RunPos?) -> Unit {
  match pos {
    Some(pos) => println("Some({run: \{pos.run}, offset: \{pos.offset}})")
    None => println("None")
  }
}

///|
fn print_position(position : Int?) -> Unit {
  match position {
    Some(position) => println("Some(\{position})")
    None => println("None")
  }
}

///|
fn main {
  println("=== Same-Color Merge ===")
  let rle : @rle.Rle[PixelRun] = @rle.Rle::Rle()
  rle.append(pixel(red, 10)) |> println //=> Ok(())
  rle.append(pixel(red, 5)) |> println //=> Ok(())
  rle.length() |> println //=> 1  (merged)
  print_pixel_opt(rle.get(0)) //=> Some({color: 16711680, count: 15})

  println("\n=== Multi-Color Scanline ===")
  let rle2 : @rle.Rle[PixelRun] = @rle.Rle::Rle()
  rle2.append(pixel(red, 10)) |> println
  rle2.append(pixel(green, 20)) |> println
  rle2.append(pixel(blue, 30)) |> println
  rle2.length() |> println //=> 3
  rle2.span() |> println //=> 60  (10+20+30)

  println("\n=== Find Run at Position ===")
  // red: 0-9, green: 10-29, blue: 30-59
  print_run_pos(rle2.find(0)) //=> Some({run: 0, offset: 0})
  print_run_pos(rle2.find(25)) //=> Some({run: 1, offset: 15})
  print_run_pos(rle2.find(59)) //=> Some({run: 2, offset: 29})

  println("\n=== Value At Position ===")
  match rle2.value_at(25) {
    Ok(run) => print_pixel(run) //=> {color: 65280, count: 20}  (green)
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
  print_pixel_opt(rle3.get(0)) //=> Some({color: 16711680, count: 8})
  print_pixel_opt(rle3.get(1)) //=> Some({color: 65280,    count: 20})
  print_pixel_opt(rle3.get(2)) //=> Some({color: 255,      count: 1})

  println("\n=== Cursor ===")
  let rle4 : @rle.Rle[PixelRun] = @rle.Rle::Rle()
  rle4.append(pixel(red, 10)) |> println
  rle4.append(pixel(green, 20)) |> println
  let cursor = rle4.cursor()
  cursor.advance(10) |> println //=> true  (moved past red)
  print_position(cursor.position()) //=> Some(10)
  print_pixel_opt(cursor.current_item()) //=> Some({color: 65280, count: 20})  (green)
}
