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
fn print_string(value : String?) -> Unit {
  match value {
    Some(value) => println("Some(\"\{value}\")")
    None => println("None")
  }
}

///|
fn main {
  println("=== Construction & Span ===")
  let rle = @rle.Rle::from_string("hello world")
  rle.span() |> println //=> 11
  rle.length() |> println //=> 1  (one run — strings always merge)
  rle.logical_length() |> println //=> 11

  println("\n=== Find ===")
  print_run_pos(rle.find(0)) //=> Some({run: 0, offset: 0})
  print_run_pos(rle.find(6)) //=> Some({run: 0, offset: 6})
  print_run_pos(rle.find(11)) //=> None  (past end)

  println("\n=== Append (auto-merge) ===")
  let rle2 : @rle.Rle[String] = @rle.Rle::Rle()
  rle2.append("hello") |> @debug.debug //=> Ok(())
  rle2.append(", ") |> @debug.debug //=> Ok(())
  rle2.append("world") |> @debug.debug //=> Ok(())
  rle2.length() |> println //=> 1  (all merged)
  rle2.to_string() |> println //=> hello, world

  println("\n=== Split ===")
  match rle.split(5) {
    Ok((left, right)) => {
      left.to_string() |> println //=> hello
      right.to_string() |> println //=>  world  (note: leading space)
    }
    Err(e) => e |> @debug.debug
  }

  println("\n=== Concat ===")
  let a = @rle.Rle::from_string("foo")
  let b = @rle.Rle::from_string("bar")
  let c = a.concat(b)
  c.to_string() |> println //=> foobar
  c.length() |> println //=> 1  (merged)

  println("\n=== Range ===")
  let rle3 = @rle.Rle::from_string("hello world")
  match rle3.range(start=6, end=11) {
    Ok(iter) =>
      iter.each(fn(slice) {
        match slice.to_inner() {
          Ok(s) => s |> println //=> world
          Err(e) => e |> println
        }
      })
    Err(e) => e |> println
  }

  println(
    "\n=== From Array (zero-span entries skipped; non-empty strings merge) ===",
  )
  let rle4 = @rle.Rle::from_array(["foo", "", "bar", "", "baz"])
  rle4.length() |> println //=> 1
  rle4.to_string() |> println //=> foobarbaz

  println("\n=== Cursor ===")
  let rle5 = @rle.Rle::from_string("abcdef")
  let cursor = rle5.cursor()
  cursor.advance(3) |> println //=> true
  print_position(cursor.position()) //=> Some(3)
  print_string(cursor.current_item()) //=> Some("abcdef")  (full run — strings always merge into one)
  cursor.seek(0) |> println //=> true
  print_position(cursor.position()) //=> Some(0)

  println("\n=== Cursor Staleness ===")
  let rle6 = @rle.Rle::from_string("hello")
  let cursor2 = rle6.cursor()
  rle6.append(" world") |> @debug.debug //=> Ok(())
  cursor2.is_stale() |> println //=> true
  print_string(cursor2.next()) //=> None  (stale)

  println("\n=== Error Messages ===")
  match rle.split(99) {
    Ok(_) => println("unexpected Ok")
    Err(e) => e.message() |> println
    //=> Position 99 is outside the document (length: 11)
  }
}
