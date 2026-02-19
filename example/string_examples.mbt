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
