///|
fn main {
  // Create from a string
  let rle = @rle.Rle::from_string("hello world")

  // Length and lookup
  rle.span() |> println //=> 11
  match rle.find(6) {
    Some(pos) => println("Some({run: \{pos.run}, offset: \{pos.offset}})")
    None => println("None")
  }

  // Append merges automatically (strings always merge)
  let rle = @rle.Rle::Rle()
  rle.append("hello") |> @debug.debug // Ok(())
  rle.append(" world") |> @debug.debug // Ok(()) — merged into one run
  rle.length() |> println //=> 1
  rle.to_string() |> println //=> "hello world"

  // Split at any position
  let (left, right) = rle.split(5).unwrap()
  left.to_string() |> println //=> "hello"
  right.to_string() |> println //=> " world"

  // Range iteration returns slices without copying
  let slices = rle.range(start=1, end=4).unwrap().collect()
  let ell = match slices[0].to_inner() {
    Ok(value) => value //=> "ell"
    Err(_) => ""
  }
  println(ell)

  let rle = @rle.Rle::from_array(["a", "", "b", "", "c"])
  rle.length() |> println //=> 1  (all merged into "abc")
  rle.to_string() |> println //=> "abc"

  cursor()
}

///|
/// Cursors track their position and detect mutations:
fn cursor() -> Unit {
  let rle = @rle.Rle::from_string("abcdef")
  let cursor = rle.cursor()

  cursor.advance(3) |> println //=> true
  match cursor.position() {
    Some(position) => println("Some(\{position})")
    None => println("None")
  }
  match cursor.current_item() {
    Some(item) => println("Some(\"\{item}\")")
    None => println("None")
  }

  // Mutation invalidates the cursor
  rle.append("ghi") |> @debug.debug
  cursor.is_stale() |> println //=> true
  match cursor.next() {
    Some(item) => println("Some(\"\{item}\")")
    None => println("None")
  }
  @debug.debug(rle)
}
