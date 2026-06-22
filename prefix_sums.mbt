///|
/// **PrefixSums** — cumulative span and content arrays for O(log n) lookup.
///
/// Built from a `Runs[T]` in O(n) by `Runs::prefix_sums()`. Once built:
///
/// - **`spans[i]`** = total span of runs 0 through i (inclusive).
///   Enables binary search in `find_fast` and O(1) total span via `spans.last()`.
///
/// - **`content[i]`** = total logical length of runs 0 through i.
///   Enables O(1) total logical length via `content.last()`.
///
/// The library caches this inside `Rle` (as `prefix: PrefixSums?`). The cache
/// is set to `None` on mutation and rebuilt lazily on the next query.
pub(all) struct PrefixSums {
  spans : Array[Int] // cumulative span lengths
  content : Array[Int] // cumulative content lengths
} derive(Debug, Eq)

///|
pub impl Show for PrefixSums with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
/// Create an empty prefix sum table.
pub fn PrefixSums::PrefixSums() -> PrefixSums {
  { spans: [], content: [] }
}

///|
/// Create an empty prefix sum table.
#deprecated("Use PrefixSums::PrefixSums() instead", skip_current_package=true)
pub fn PrefixSums::new() -> PrefixSums {
  PrefixSums()
}

///|
/// Total span length - O(1)
pub impl Spanning for PrefixSums with span(self : PrefixSums) -> Int {
  match self.spans.last() {
    Some(total) => total
    None => 0
  }
}

///|
/// Total logical length - O(1)
pub impl Spanning for PrefixSums with logical_length(self : PrefixSums) -> Int {
  match self.content.last() {
    Some(total) => total
    None => 0
  }
}

///|
/// Number of runs
pub impl HasLength for PrefixSums with length(self : PrefixSums) -> Int {
  self.spans.length()
}

///|
/// Get span offset at run index (end of run i) with bounds checking.
pub fn PrefixSums::span_at(self : PrefixSums, index : Int) -> Int? {
  if index < 0 || index >= self.spans.length() {
    None
  } else {
    Some(self.spans[index])
  }
}

///|
/// Get span offset before run index (start of run i)
pub fn PrefixSums::span_before(self : PrefixSums, index : Int) -> Int {
  if index <= 0 {
    0
  } else {
    self.spans[index - 1]
  }
}
