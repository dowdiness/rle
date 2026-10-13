///|
test "core Shrink remains available for every RLE test data type" {
  let runs = Runs::from_string("abcd")
  let smaller_runs = @shrink.Shrink::shrink(runs).collect()
  assert_true(smaller_runs[0].is_empty())
  assert_eq(smaller_runs[1].to_string(), "ab")
  let smaller_rle = @shrink.Shrink::shrink(Rle::from_runs(runs)).collect()
  assert_eq(
    smaller_rle.map(r => r.to_string()),
    smaller_runs.map(r => r.to_string()),
  )
  let pos : RunPos = { run: 2, offset: 4, }
  assert_eq(@shrink.Shrink::shrink(pos).collect(), [
    { run: 0, offset: 0, },
    { run: 1, offset: 4, },
    { run: 1, offset: 4, },
    { run: 2, offset: 3, },
    { run: 2, offset: 2, },
  ])
  let sums : PrefixSums = { spans: [1, 3, 6], content: [1, 3, 6], }
  let smaller_sums = @shrink.Shrink::shrink(sums).collect()
  assert_eq(smaller_sums.map(s => s.spans), [[], [1, 3], [1]])
  let slice : Slice[String] = { value: "abc", start: 0, end: 3, }
  let smaller_slices = @shrink.Shrink::shrink(slice).collect()
  assert_true(smaller_slices.map(s => s.to_inner()) is [Ok("a"), Ok("ab")])
}
