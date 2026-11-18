///| Blackbox tests for Runs public API

///|
test "Runs::new creates empty" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  inspect(runs.is_empty(), content="true")
  inspect(runs.length(), content="0")
}

///|
test "Runs::from_string creates single run" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.length(), content="1")
  inspect(runs.to_string(), content="hello")
}

///|
test "Runs::from_string with empty string" {
  let runs = @rle.Runs::from_string("")
  inspect(runs.is_empty(), content="true")
  inspect(runs.length(), content="0")
}

///|
test "Runs::append merges adjacent runs" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  runs.append("hello")
  runs.append(" world")
  inspect(runs.length(), content="1")
  inspect(runs.to_string(), content="hello world")
}

///|
test "Runs::append rejects empty element" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  let result = Ok(runs.append("")) catch { error => Err(error) }
  @debug.debug_inspect(result, content="Err(Internal(EmptyElement))")
  inspect(runs.to_string(), content="")
}

///|
test "Runs::span returns total span length" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.span(), content="5")
}

///|
test "Runs::logical_length returns total logical length" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.logical_length(), content="5")
}

///|
test "Runs::find finds correct position" {
  let runs = @rle.Runs::from_string("abcdef")
  match runs.find(3) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="3")
    }
    None => fail("find should succeed")
  }
}

///|
test "Runs::find at boundaries" {
  let runs = @rle.Runs::from_string("hello")
  match runs.find(0) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="0")
    }
    None => fail("find should succeed")
  }
  match runs.find(4) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="4")
    }
    None => fail("find should succeed")
  }
  inspect(runs.find(5) is None, content="true")
  inspect(runs.find(-1) is None, content="true")
}

///|
test "Runs::range full range" {
  let runs = @rle.Runs::from_string("hello")
  let slices = runs.range(start=0, end=5).collect()
  inspect(slices.length(), content="1")
  inspect(slices[0].to_inner(), content="hello")
}

///|
test "Runs::range partial range" {
  let runs = @rle.Runs::from_string("hello")
  let slices = runs.range(start=1, end=4).collect()
  inspect(slices.length(), content="1")
  inspect(slices[0].to_inner(), content="ell")
}

///|
test "Runs::range empty range" {
  let runs = @rle.Runs::from_string("hello")
  let slices = runs.range(start=2, end=2).collect()
  inspect(slices.length(), content="0")
}

///|
test "Runs::range out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let result = Ok(runs.range(start=0, end=10)) catch { error => Err(error) }
  inspect(result is Err(_), content="true")
}

///|
test "Runs::range_clamped clamps bounds" {
  let runs = @rle.Runs::from_string("hello")
  let slices = runs.range_clamped(start=-5, end=100).collect()
  inspect(slices.length(), content="1")
  inspect(slices[0].to_inner(), content="hello")
}

///|
test "Runs::range_clamped keeps lazy slice boundary validation explicit" {
  let runs = @rle.Runs::from_string("A😀B")
  let slices = runs.range_clamped(start=2, end=4).collect()
  inspect(slices.length(), content="1")
  let result = Ok(slices[0].to_inner()) catch { error => Err(error) }
  match result {
    Ok(_) => fail("materializing a slice inside a surrogate pair should fail")
    Err(e) => inspect(e, content="InvalidSlice(reason=InvalidIndex)")
  }
}

///|
test "Runs::split at mid" {
  let runs = @rle.Runs::from_string("hello")
  let (left, right) = runs.split(2)
  inspect(left.to_string(), content="he")
  inspect(right.to_string(), content="llo")
}

///|
test "Runs::split at start" {
  let runs = @rle.Runs::from_string("hello")
  let (left, right) = runs.split(0)
  inspect(left.to_string(), content="")
  inspect(right.to_string(), content="hello")
}

///|
test "Runs::split at end" {
  let runs = @rle.Runs::from_string("hello")
  let (left, right) = runs.split(5)
  inspect(left.to_string(), content="hello")
  inspect(right.to_string(), content="")
}

///|
test "Runs::split out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let result = Ok(runs.split(10)) catch { error => Err(error) }
  inspect(result is Err(_), content="true")
}

///|
test "Runs::concat merges adjacent" {
  let a = @rle.Runs::from_string("hello")
  let b = @rle.Runs::from_string(" world")
  let result = a.concat(b)
  inspect(result.length(), content="1")
  inspect(result.to_string(), content="hello world")
}

///|
test "Runs::extend_from merges in-place" {
  let a = @rle.Runs::from_string("hello")
  let b = @rle.Runs::from_string(" world")
  a.extend_from(b)
  inspect(a.length(), content="1")
  inspect(a.to_string(), content="hello world")
}

///|
test "Runs::clear empties the runs" {
  let runs = @rle.Runs::from_string("hello")
  runs.clear()
  inspect(runs.is_empty(), content="true")
  inspect(runs.span(), content="0")
}

///|
test "Runs::get retrieves run by index" {
  let runs = @rle.Runs::from_string("hello")
  match runs.get(0) {
    Some(value) => inspect(value, content="hello")
    None => fail("expected run at index 0")
  }
  inspect(runs.get(1) is None, content="true")
  inspect(runs.get(-1) is None, content="true")
}

///|
test "Runs::iter_chars iterates codepoints" {
  let runs = @rle.Runs::from_string("hello")
  let chars = runs.iter_chars().collect()
  inspect(chars.length(), content="5")
  inspect(chars[0] == 'h', content="true")
  inspect(chars[1] == 'e', content="true")
  inspect(chars[2] == 'l', content="true")
  inspect(chars[3] == 'l', content="true")
  inspect(chars[4] == 'o', content="true")
}

///|
test "Runs::from_array merges and skips empty" {
  let runs = @rle.Runs::from_array(["a", "", "b", "", "c"])
  inspect(runs.length(), content="1")
  inspect(runs.to_string(), content="abc")
}

///|
test "Runs unicode handling" {
  let runs = @rle.Runs::from_string("こんにちは")
  inspect(runs.span(), content="5")
  match runs.find(2) {
    Some(pos) => {
      inspect(pos.run, content="0")
      inspect(pos.offset, content="2")
    }
    None => fail("find should succeed")
  }
}

///|
test "Runs unicode split" {
  let runs = @rle.Runs::from_string("日本語")
  let (left, right) = runs.split(1)
  inspect(left.to_string(), content="日")
  inspect(right.to_string(), content="本語")
}

///|
test "Runs slice with surrogate pairs uses code unit indices" {
  let runs = @rle.Runs::from_string("A🤣B")
  let (left, right) = runs.split(3)
  inspect(left.to_string().length(), content="3")
  inspect(left.to_string().unsafe_get(0), content="65")
  inspect(left.to_string().unsafe_get(1), content="55358")
  inspect(left.to_string().unsafe_get(2), content="56611")
  inspect(right.to_string().length(), content="1")
  inspect(right.to_string().unsafe_get(0), content="66")
}

///|
test "Runs::prefix_sums builds correct sums" {
  let runs = @rle.Runs::from_string("hello")
  let sums = runs.prefix_sums()
  @debug.debug_inspect(sums.spans, content="[5]")
  @debug.debug_inspect(sums.content, content="[5]")
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
  try runs.split(1) catch {
    error => inspect(error, content="InvalidSlice(reason=InvalidIndex)")
  } noraise {
    _ => fail("split should fail on invalid boundary")
  }
}

// ============== value_at tests ==============

///|
test "Runs::value_at middle position" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.value_at(2), content="hello")
}

///|
test "Runs::value_at start position" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.value_at(0), content="hello")
}

///|
test "Runs::value_at last position" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.value_at(4), content="hello")
}

///|
test "Runs::value_at out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  inspect(
    (Ok(runs.value_at(5)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.value_at(-1)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
}

///|
test "Runs::value_at empty runs" {
  let runs : @rle.Runs[String] = @rle.Runs::new()
  inspect(
    (Ok(runs.value_at(0)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
}

// ============== insert tests ==============

///|
test "Runs::insert at middle" {
  let runs = @rle.Runs::from_string("helo")
  let elem = @rle.Runs::from_string("ll")
  let result = runs.insert(2, elem)
  inspect(result.to_string(), content="helllo")
  inspect(result.span(), content="6")
}

///|
test "Runs::insert at start (prepend)" {
  let runs = @rle.Runs::from_string("world")
  let elem = @rle.Runs::from_string("hello ")
  inspect(runs.insert(0, elem).to_string(), content="hello world")
}

///|
test "Runs::insert at end (append)" {
  let runs = @rle.Runs::from_string("hello")
  let elem = @rle.Runs::from_string(" world")
  inspect(runs.insert(5, elem).to_string(), content="hello world")
}

///|
test "Runs::insert out of bounds" {
  let runs = @rle.Runs::from_string("hello")
  let elem = @rle.Runs::from_string("x")
  inspect(
    (Ok(runs.insert(10, elem)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.insert(-1, elem)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
}

///|
test "Runs::insert empty element" {
  let runs = @rle.Runs::from_string("hello")
  let elem : @rle.Runs[String] = @rle.Runs::new()
  inspect(runs.insert(2, elem).to_string(), content="hello")
}

// ============== delete tests ==============

///|
test "Runs::delete middle" {
  let runs = @rle.Runs::from_string("hello world")
  inspect(runs.delete(start=5, end=6).to_string(), content="helloworld")
}

///|
test "Runs::delete from start" {
  let runs = @rle.Runs::from_string("hello world")
  inspect(runs.delete(start=0, end=6).to_string(), content="world")
}

///|
test "Runs::delete to end" {
  let runs = @rle.Runs::from_string("hello world")
  inspect(runs.delete(start=5, end=11).to_string(), content="hello")
}

///|
test "Runs::delete empty range" {
  let runs = @rle.Runs::from_string("hello")
  inspect(runs.delete(start=2, end=2).to_string(), content="hello")
}

///|
test "Runs::delete all" {
  let runs = @rle.Runs::from_string("hello")
  let result = runs.delete(start=0, end=5)
  inspect(result.is_empty(), content="true")
  inspect(result.span(), content="0")
}

///|
test "Runs::delete invalid range" {
  let runs = @rle.Runs::from_string("hello")
  inspect(
    (Ok(runs.delete(start=-1, end=3)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.delete(start=0, end=-1)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.delete(start=4, end=2)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.delete(start=0, end=10)) catch { error => Err(error) }) is Err(_),
    content="true",
  )
}

///|
test "Runs::delete at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("A😀B")
  try runs.delete(start=2, end=3) catch {
    error => inspect(error, content="InvalidSlice(reason=InvalidIndex)")
  } noraise {
    _ => fail("delete at surrogate boundary should fail")
  }
}

///|
test "Runs::delete empty range at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("😀")
  try runs.delete(start=1, end=1) catch {
    error => inspect(error, content="InvalidSlice(reason=InvalidIndex)")
  } noraise {
    _ => fail("empty delete at surrogate boundary should fail")
  }
}

// ============== splice tests ==============

///|
test "Runs::splice replace middle" {
  let runs = @rle.Runs::from_string("hello world")
  let replacement = @rle.Runs::from_string("beautiful ")
  inspect(
    runs.splice(start=6, end=11, replacement).to_string(),
    content="hello beautiful ",
  )
}

///|
test "Runs::splice insert (empty range)" {
  let runs = @rle.Runs::from_string("helloworld")
  let replacement = @rle.Runs::from_string(" ")
  inspect(
    runs.splice(start=5, end=5, replacement).to_string(),
    content="hello world",
  )
}

///|
test "Runs::splice delete (empty replacement)" {
  let runs = @rle.Runs::from_string("hello world")
  let replacement : @rle.Runs[String] = @rle.Runs::new()
  inspect(
    runs.splice(start=5, end=6, replacement).to_string(),
    content="helloworld",
  )
}

///|
test "Runs::splice replace all" {
  let runs = @rle.Runs::from_string("hello")
  let replacement = @rle.Runs::from_string("world")
  inspect(runs.splice(start=0, end=5, replacement).to_string(), content="world")
}

///|
test "Runs::splice invalid range" {
  let runs = @rle.Runs::from_string("hello")
  let replacement = @rle.Runs::from_string("x")
  inspect(
    (Ok(runs.splice(start=-1, end=3, replacement)) catch {
      error => Err(error)
    })
    is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.splice(start=4, end=2, replacement)) catch { error => Err(error) })
    is Err(_),
    content="true",
  )
  inspect(
    (Ok(runs.splice(start=0, end=10, replacement)) catch {
      error => Err(error)
    })
    is Err(_),
    content="true",
  )
}

///|
test "Runs::splice at surrogate pair boundary returns error" {
  let runs = @rle.Runs::from_string("A😀B")
  let replacement = @rle.Runs::from_string("x")
  try runs.splice(start=2, end=3, replacement) catch {
    error => inspect(error, content="InvalidSlice(reason=InvalidIndex)")
  } noraise {
    _ => fail("splice at surrogate boundary should fail")
  }
}
