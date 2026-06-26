///| Whitebox tests for Runs internal invariants

///|
test "invariant: no zero-length runs after append" {
  let runs : Runs[String] = Runs::new()
  let _ = runs.append("a")
  let _ = runs.append("b")
  let _ = runs.append("c")
  for item in runs.0 {
    inspect(Spanning::span(item) > 0, content="true")
  }
}

///|
test "invariant: no adjacent mergeable runs" {
  let runs : Runs[String] = Runs::new()
  let _ = runs.append("hello")
  let _ = runs.append(" ")
  let _ = runs.append("world")
  // String always merges, so should be single run
  inspect(runs.0.length(), content="1")
}

///|
test "normalize_tail cascades properly" {
  let runs : Runs[String] = Runs::new()
  let _ = runs.append("a")
  let _ = runs.append("b")
  let _ = runs.append("c")
  let _ = runs.append("d")
  inspect(runs.0.length(), content="1")
  inspect(runs.0[0], content="abcd")
}

///|
test "items array direct access" {
  let runs = Runs::from_string("test")
  inspect(runs.0.length(), content="1")
  inspect(runs.0[0], content="test")
}

///|
test "split preserves invariants" {
  let runs = Runs::from_string("hello world")
  let result = runs.split(5)
  match result {
    Ok((left, right)) => {
      for item in left.0 {
        inspect(Spanning::span(item) > 0, content="true")
      }
      for item in right.0 {
        inspect(Spanning::span(item) > 0, content="true")
      }
    }
    Err(_) => fail("split should succeed")
  }
}

///|
test "range internal slice bounds" {
  let runs = Runs::from_string("abcdefgh")
  match runs.range(start=2, end=6) {
    Ok(iter) =>
      for slice in iter {
        inspect(slice.start >= 0, content="true")
        inspect(slice.end > slice.start, content="true")
      }
    Err(_) => fail("range should succeed")
  }
}

///|
test "prefix_sums internal structure" {
  let runs : Runs[String] = Runs::new()
  let _ = runs.append("abc")
  // Since strings always merge, still one run
  let sums = runs.prefix_sums()
  inspect(sums.spans.length(), content="1")
  inspect(sums.spans[0], content="3")
  inspect(sums.content[0], content="3")
}

///|
test "Rle cache invalidation" {
  let rle : Rle[String] = Rle::Rle()
  let _ = rle.append("hello")
  // Access to trigger cache build
  let _ = rle.span()
  inspect(rle.prefix is Some(_), content="true")
  // Mutation should invalidate
  let _ = rle.append(" world")
  inspect(rle.prefix is None, content="true")
  // Access rebuilds
  let _ = rle.span()
  inspect(rle.prefix is Some(_), content="true")
}

///|
test "Rle clear invalidates cache" {
  let rle = Rle::from_string("hello")
  let _ = rle.span()
  inspect(rle.prefix is Some(_), content="true")
  rle.clear()
  inspect(rle.prefix is None, content="true")
}

///|
test "Rle extend invalidates cache and bumps version" {
  let a = Rle::from_string("hello")
  let b = Rle::from_string(" world")
  let _ = a.span()
  inspect(a.prefix is Some(_), content="true")
  let old_version = a.version
  a.extend(b)
  inspect(a.prefix is None, content="true")
  inspect(a.version > old_version, content="true")
}

///|
test "Rle extend with all-zero-span does not bump version" {
  let a = Rle::from_string("hello")
  let _ = a.span() // build cache
  let old_version = a.version
  // Intentionally create invalid Runs with zero-span items via raw
  // constructor. This bypasses the normalization invariant (no adjacent
  // mergeable, no zero-span) to test that Rle::extend's mutation
  // detection correctly identifies the no-op case: Runs::extend skips
  // all zero-span items, so version and cache should be untouched.
  let zero_span_runs : Runs[String] = Runs(["", "", ""])
  let b : Rle[String] = Rle::from_runs(zero_span_runs)
  a.extend(b)
  // Version should NOT bump — no actual mutation happened
  inspect(a.version == old_version, content="true")
  // Cache should NOT be invalidated
  inspect(a.prefix is Some(_), content="true")
  // Content unchanged
  inspect(a.runs.0[0], content="hello")
}

///|
/// Whitebox test helper: index-carrying range for testing FromRange.
priv struct WbRange {
  start : Int
  count : Int
}

///|
impl FromRange for WbRange with fn from_range(start, count) {
  { start, count }
}

///|
impl HasLength for WbRange with fn length(self) {
  self.count
}

///|
impl Spanning for WbRange with fn span(self) {
  self.count
}

///|
impl Mergeable for WbRange with fn can_merge(a, b) {
  a.start + a.count == b.start
}

///|
impl Mergeable for WbRange with fn merge(a, b) {
  { start: a.start, count: a.count + b.count }
}

///|
test "invariant: from_sorted_ints no adjacent mergeable runs" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7, 10])
  // Verify no adjacent runs are mergeable
  for i = 0; i < runs.0.length() - 1; i = i + 1 {
    inspect(Mergeable::can_merge(runs.0[i], runs.0[i + 1]), content="false")
  }
}

///|
test "invariant: from_sorted_ints no zero-span runs" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7])
  for item in runs.0 {
    inspect(Spanning::span(item) > 0, content="true")
  }
}

///|
test "invariant: from_sorted_ints groups have correct starts" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([0, 1, 2, 5, 6, 7])
  inspect(runs.0.length(), content="2")
  inspect(runs.0[0].start, content="0")
  inspect(runs.0[0].count, content="3")
  inspect(runs.0[1].start, content="5")
  inspect(runs.0[1].count, content="3")
}

///|
test "invariant: from_sorted_ints dedup produces correct groups" {
  let runs : Runs[WbRange] = Runs::from_sorted_ints([1, 1, 1, 2, 3, 5, 5])
  inspect(runs.0.length(), content="2")
  inspect(runs.0[0].start, content="1")
  inspect(runs.0[0].count, content="3")
  inspect(runs.0[1].start, content="5")
  inspect(runs.0[1].count, content="1")
}
