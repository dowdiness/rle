///| Blackbox tests for Runs public API

///|
test "Runs::new creates empty" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  inspect(runs.is_empty(), content="true")
  inspect(runs.count(), content="0")
}

///|
test "Runs::from_string creates single run" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.count(), content="1")
  inspect(runs.to_string(), content="hello")
}

///|
test "Runs::from_string with empty string" {
  let runs = @rle.Runs::from_string("")
  inspect(runs.is_empty(), content="true")
  inspect(runs.count(), content="0")
}

///|
test "Runs::append merges adjacent runs" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  let _ = runs.append("hello")
  let _ = runs.append(" world")
  inspect(runs.count(), content="1")
  inspect(runs.to_string(), content="hello world")
}

///|
test "Runs::append rejects empty element" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  let result = runs.append("")
  inspect(result, content="Err(Internal(EmptyElement))")
}

///|
test "Runs::len returns total span length" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.len(), content="5")
}

///|
test "Runs::logical_length returns total logical length" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.logical_length(), content="5")
}

///|
test "Runs::find finds correct position" {
  let runs = @rle.Runs::from_string("abcdef")
  inspect(runs.find(3), content="Some({run: 0, offset: 3})")
}

///|
test "Runs::find at boundaries" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.find(0), content="Some({run: 0, offset: 0})")
  inspect(runs.find(4), content="Some({run: 0, offset: 4})")
  inspect(runs.find(5), content="None")
  inspect(runs.find(-1), content="None")
}

///|
test "Runs::range full range" {
  let runs = @rle.Runs::from_string("hello")
  match runs.range(start=0, end=5) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="1")
      match slices[0].to_inner() {
        Ok(value) => inspect(value, content="hello")
        Err(_) => fail("slice should succeed")
      }
    }
    Err(_) => fail("range should succeed")
  }
}

///|
test "Runs::range partial range" {
  let runs = @rle.Runs::from_string("hello")
  match runs.range(start=1, end=4) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="1")
      match slices[0].to_inner() {
        Ok(value) => inspect(value, content="ell")
        Err(_) => fail("slice should succeed")
      }
    }
    Err(_) => fail("range should succeed")
  }
}

///|
test "Runs::range empty range" {
  let runs = @rle.Runs::from_string("hello")
  match runs.range(start=2, end=2) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="0")
    }
    Err(_) => fail("range with start==end should succeed")
  }
}

///|
test "Runs::range out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let result = runs.range(start=0, end=10)
  inspect(result is Err(_), content="true")
}

///|
test "Runs::range_clamped clamps bounds" {
  let runs = @rle.Runs::from_string("hello")
  let slices = runs.range_clamped(start=-5, end=100).collect()
  inspect(slices.length(), content="1")
  match slices[0].to_inner() {
    Ok(value) => inspect(value, content="hello")
    Err(_) => fail("slice should succeed")
  }
}

///|
test "Runs::split at mid" {
  let runs = @rle.Runs::from_string("hello")
  match runs.split(2) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="he")
      inspect(right.to_string(), content="llo")
    }
    Err(_) => fail("split should succeed")
  }
}

///|
test "Runs::split at start" {
  let runs = @rle.Runs::from_string("hello")
  match runs.split(0) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="")
      inspect(right.to_string(), content="hello")
    }
    Err(_) => fail("split(0) should succeed")
  }
}

///|
test "Runs::split at end" {
  let runs = @rle.Runs::from_string("hello")
  match runs.split(5) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="hello")
      inspect(right.to_string(), content="")
    }
    Err(_) => fail("split(total) should succeed")
  }
}

///|
test "Runs::split out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let result = runs.split(10)
  inspect(result is Err(_), content="true")
}

///|
test "Runs::concat merges adjacent" {
  let a = @rle.Runs::from_string("hello")
  let b = @rle.Runs::from_string(" world")
  let result = a.concat(b)
  inspect(result.count(), content="1")
  inspect(result.to_string(), content="hello world")
}

///|
test "Runs::extend merges in-place" {
  let a = @rle.Runs::from_string("hello")
  let b = @rle.Runs::from_string(" world")
  a.extend(b)
  inspect(a.count(), content="1")
  inspect(a.to_string(), content="hello world")
}

///|
test "Runs::clear empties the runs" {
  let runs = @rle.Runs::from_string("hello")
  runs.clear()
  inspect(runs.is_empty(), content="true")
  inspect(runs.len(), content="0")
}

///|
test "Runs::get retrieves run by index" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.get(0), content="Some(\"hello\")")
  inspect(runs.get(1), content="None")
  inspect(runs.get(-1), content="None")
}

///|
test "Runs::iter_chars iterates codepoints" {
  let runs = @rle.Runs::from_string("hello")
  let chars = runs.iter_chars().collect()
  inspect(chars, content="['h', 'e', 'l', 'l', 'o']")
}

///|
test "Runs::from_array merges and skips empty" {
  let runs = @rle.Runs::from_array(["a", "", "b", "", "c"])
  inspect(runs.count(), content="1")
  inspect(runs.to_string(), content="abc")
}

///|
test "Runs unicode handling" {
  let runs = @rle.Runs::from_string("こんにちは")
  inspect(runs.len(), content="5")
  inspect(runs.find(2), content="Some({run: 0, offset: 2})")
}

///|
test "Runs unicode split" {
  let runs = @rle.Runs::from_string("日本語")
  match runs.split(1) {
    Ok((left, right)) => {
      inspect(left.to_string(), content="日")
      inspect(right.to_string(), content="本語")
    }
    Err(_) => fail("split should work with unicode")
  }
}

///|
test "Runs slice with surrogate pairs uses code unit indices" {
  let runs = @rle.Runs::from_string("A🤣B")
  match runs.split(3) {
    Ok((left, right)) => {
      inspect(left.to_string().length(), content="3")
      inspect(left.to_string().unsafe_get(0), content="65")
      inspect(left.to_string().unsafe_get(1), content="55358")
      inspect(left.to_string().unsafe_get(2), content="56611")
      inspect(right.to_string().length(), content="1")
      inspect(right.to_string().unsafe_get(0), content="66")
    }
    Err(_) => fail("split should use code unit indices")
  }
}

///|
test "Runs::prefix_sums builds correct sums" {
  let runs = @rle.Runs::from_string("hello")
  let sums = runs.prefix_sums()
  inspect(sums.spans, content="[5]")
  inspect(sums.content, content="[5]")
}

///|
test "Runs::find_fast matches find" {
  let runs = @rle.Runs::from_string("hello world")
  let sums = runs.prefix_sums()
  for i = 0; i < 11; i = i + 1 {
    let slow = runs.find(i)
    let fast = runs.find_fast(sums, i)
    inspect(slow == fast, content="true")
  }
}

///|
test "Runs split surrogate pair" {
  let s = "😀" // len 2
  let runs = @rle.Runs::from_string(s)
  match runs.split(1) {
    Ok(_) => fail("split should fail on invalid boundary")
    Err(err) => inspect(err, content="InvalidSlice(reason=InvalidIndex)")
  }
}

// ============== value_at tests ==============

///|
test "Runs::value_at middle position" {
  let runs = @rle.Runs::from_string("hello")
  match runs.value_at(2) {
    Ok(value) => inspect(value, content="hello")
    Err(_) => fail("value_at should succeed")
  }
}

///|
test "Runs::value_at start position" {
  let runs = @rle.Runs::from_string("hello")
  match runs.value_at(0) {
    Ok(value) => inspect(value, content="hello")
    Err(_) => fail("value_at(0) should succeed")
  }
}

///|
test "Runs::value_at last position" {
  let runs = @rle.Runs::from_string("hello")
  match runs.value_at(4) {
    Ok(value) => inspect(value, content="hello")
    Err(_) => fail("value_at(4) should succeed")
  }
}

///|
test "Runs::value_at out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.value_at(5) is Err(_), content="true")
  inspect(runs.value_at(-1) is Err(_), content="true")
}

///|
test "Runs::value_at empty runs" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  inspect(runs.value_at(0) is Err(_), content="true")
}

// ============== insert tests ==============

///|
test "Runs::insert at middle" {
  let runs = @rle.Runs::from_string("helo")
  let elem = @rle.Runs::from_string("ll")
  match runs.insert(2, elem) {
    Ok(result) => {
      inspect(result.to_string(), content="helllo")
      inspect(result.len(), content="6")
    }
    Err(_) => fail("insert should succeed")
  }
}

///|
test "Runs::insert at start (prepend)" {
  let runs = @rle.Runs::from_string("world")
  let elem = @rle.Runs::from_string("hello ")
  match runs.insert(0, elem) {
    Ok(result) => inspect(result.to_string(), content="hello world")
    Err(_) => fail("insert(0) should succeed")
  }
}

///|
test "Runs::insert at end (append)" {
  let runs = @rle.Runs::from_string("hello")
  let elem = @rle.Runs::from_string(" world")
  match runs.insert(5, elem) {
    Ok(result) => inspect(result.to_string(), content="hello world")
    Err(_) => fail("insert(len) should succeed")
  }
}

///|
test "Runs::insert out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let elem = @rle.Runs::from_string("x")
  inspect(runs.insert(10, elem) is Err(_), content="true")
  inspect(runs.insert(-1, elem) is Err(_), content="true")
}

///|
test "Runs::insert empty element" {
  let runs = @rle.Runs::from_string("hello")
  let elem : @rle.Runs[String] = @rle.Runs::new()
  match runs.insert(2, elem) {
    Ok(result) => inspect(result.to_string(), content="hello")
    Err(_) => fail("inserting empty should succeed")
  }
}

// ============== delete tests ==============

///|
test "Runs::delete middle" {
  let runs = @rle.Runs::from_string("hello world")
  match runs.delete(start=5, end=6) {
    Ok(result) => inspect(result.to_string(), content="helloworld")
    Err(_) => fail("delete should succeed")
  }
}

///|
test "Runs::delete from start" {
  let runs = @rle.Runs::from_string("hello world")
  match runs.delete(start=0, end=6) {
    Ok(result) => inspect(result.to_string(), content="world")
    Err(_) => fail("delete from start should succeed")
  }
}

///|
test "Runs::delete to end" {
  let runs = @rle.Runs::from_string("hello world")
  match runs.delete(start=5, end=11) {
    Ok(result) => inspect(result.to_string(), content="hello")
    Err(_) => fail("delete to end should succeed")
  }
}

///|
test "Runs::delete empty range" {
  let runs = @rle.Runs::from_string("hello")
  match runs.delete(start=2, end=2) {
    Ok(result) => inspect(result.to_string(), content="hello")
    Err(_) => fail("delete empty range should succeed")
  }
}

///|
test "Runs::delete all" {
  let runs = @rle.Runs::from_string("hello")
  match runs.delete(start=0, end=5) {
    Ok(result) => {
      inspect(result.is_empty(), content="true")
      inspect(result.len(), content="0")
    }
    Err(_) => fail("delete all should succeed")
  }
}

///|
test "Runs::delete invalid range" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.delete(start=-1, end=3) is Err(_), content="true")
  inspect(runs.delete(start=0, end=-1) is Err(_), content="true")
  inspect(runs.delete(start=4, end=2) is Err(_), content="true")
  inspect(runs.delete(start=0, end=10) is Err(_), content="true")
}

///|
test "Runs::delete at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("A😀B") // "A" (1) + "😀" (2) + "B" (1) = len 4
  // Position 2 is inside the surrogate pair
  match runs.delete(start=2, end=3) {
    Ok(_) => fail("delete at surrogate boundary should fail")
    Err(e) => inspect(e, content="InvalidSlice(reason=InvalidIndex)")
  }
}

///|
test "Runs::delete empty range at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("😀") // len 2, position 1 is inside the pair
  match runs.delete(start=1, end=1) {
    Ok(_) => fail("empty delete at surrogate boundary should fail")
    Err(e) => inspect(e, content="InvalidSlice(reason=InvalidIndex)")
  }
}

// ============== splice tests ==============

///|
test "Runs::splice replace middle" {
  let runs = @rle.Runs::from_string("hello world")
  let replacement = @rle.Runs::from_string("beautiful ")
  match runs.splice(start=6, end=11, replacement) {
    Ok(result) => inspect(result.to_string(), content="hello beautiful ")
    Err(_) => fail("splice should succeed")
  }
}

///|
test "Runs::splice insert (empty range)" {
  let runs = @rle.Runs::from_string("helloworld")
  let replacement = @rle.Runs::from_string(" ")
  match runs.splice(start=5, end=5, replacement) {
    Ok(result) => inspect(result.to_string(), content="hello world")
    Err(_) => fail("splice with empty range should succeed")
  }
}

///|
test "Runs::splice delete (empty replacement)" {
  let runs = @rle.Runs::from_string("hello world")
  let replacement : @rle.Runs[String] = @rle.Runs::new()
  match runs.splice(start=5, end=6, replacement) {
    Ok(result) => inspect(result.to_string(), content="helloworld")
    Err(_) => fail("splice with empty replacement should succeed")
  }
}

///|
test "Runs::splice replace all" {
  let runs = @rle.Runs::from_string("hello")
  let replacement = @rle.Runs::from_string("world")
  match runs.splice(start=0, end=5, replacement) {
    Ok(result) => inspect(result.to_string(), content="world")
    Err(_) => fail("splice all should succeed")
  }
}

///|
test "Runs::splice invalid range" {
  let runs = @rle.Runs::from_string("hello")
  let replacement = @rle.Runs::from_string("x")
  inspect(runs.splice(start=-1, end=3, replacement) is Err(_), content="true")
  inspect(runs.splice(start=4, end=2, replacement) is Err(_), content="true")
  inspect(runs.splice(start=0, end=10, replacement) is Err(_), content="true")
}

///|
test "Runs::splice at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("A😀B") // len 4
  let replacement = @rle.Runs::from_string("x")
  match runs.splice(start=2, end=3, replacement) {
    Ok(_) => fail("splice at surrogate boundary should fail")
    Err(e) => inspect(e, content="InvalidSlice(reason=InvalidIndex)")
  }
}
