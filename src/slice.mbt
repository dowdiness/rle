///|
/// **Slice** — a lazy view into a run, representing the sub-range `[start, end)`.
///
/// `range()` operations return `Iter[Slice[T]]` instead of `Iter[T]`. Each
/// `Slice` holds a reference to the original run plus the sub-range bounds,
/// but does **not** materialize the sliced value until `to_inner()` is called.
///
/// This enables zero-copy iteration: if you only need to count matching runs,
/// check a condition, or read metadata, you can inspect `Slice` fields without
/// ever allocating new strings or sub-runs.
pub struct Slice[T] {
  value : T
  start : Int
  end : Int
} derive(Debug, Eq)

///|
pub impl[T : Debug] Show for Slice[T] with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
/// Materializes the sliced value by calling `T::slice(value, start, end)`.
///
/// This is the point where allocation happens (e.g., creating a substring).
/// Returns `Err` if the slice bounds are invalid (e.g., inside a UTF-16
/// surrogate pair for strings).
pub fn[T : Sliceable] Slice::to_inner(self : Slice[T]) -> Result[T, RleError] {
  T::slice(self.value, start=self.start, end=self.end)
}
