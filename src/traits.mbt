///|
/// **Mergeable** — determines when two adjacent runs compress into one.
///
/// The RLE structure stores a sequence as an array of "runs." Whenever two
/// adjacent runs satisfy `can_merge`, they are automatically combined via
/// `merge`. This is the core compression mechanism.
///
/// ## Contract
///
/// Implementors **must** ensure:
///
/// 1. **`merge` is associative**: `merge(merge(a, b), c) == merge(a, merge(b, c))`.
///    The library's stack-based batch merge processes elements left-to-right and
///    cascades merges backward. Without associativity, different insertion orders
///    could produce different results.
///
/// 2. **`merge` preserves content**: the merged run must represent the same
///    logical sequence as the two original runs placed side by side.
///
/// 3. **`can_merge` is consistent with `merge`**: if `can_merge(a, b)` returns
///    `true`, then `merge(a, b)` must produce a valid element with
///    `span(merge(a,b)) == span(a) + span(b)`.
///
/// ## Examples
///
/// - Strings: `can_merge` always returns `true`; `merge` concatenates.
/// - Authored text: `can_merge` checks `a.author == b.author`.
/// - Pixel runs: `can_merge` checks `a.color == b.color`; `merge` sums counts.
pub(open) trait Mergeable {
  can_merge(Self, Self) -> Bool
  merge(Self, Self) -> Self
}

///|
/// **Sliceable** — extract a sub-range `[start, end)` from a run.
///
/// This trait is **optional**. Without it, you can still use `append`, `find`,
/// `concat`, `extend`, `value_at`, and `range`. You need `Sliceable` to unlock
/// positional editing operations: `split`, `insert`, `delete`, and `splice`.
/// Note: `range()` returns `Slice[T]` values that work without `Sliceable`,
/// but calling `Slice::to_inner()` to materialize them requires it.
///
/// Uses half-open interval `[start, end)` — start inclusive, end exclusive.
/// Indices are in the same units as `span()` (e.g., UTF-16 code units for
/// strings, pixel count for pixel runs).
///
/// ## String Warning
///
/// For `String`, indices are **UTF-16 code units**, not Unicode codepoints.
/// Emoji like "😀" occupy 2 code units (a surrogate pair). Slicing at an
/// index inside a surrogate pair returns `Err(InvalidSlice(InvalidIndex))`.
/// Always slice on valid character boundaries.
pub(open) trait Sliceable {
  slice(Self, start~ : Int, end~ : Int) -> Result[Self, RleError]
}

///|
/// **HasLength** — basic size of a value (number of runs for containers,
/// character count for strings, etc.).
///
/// Provides `is_empty()` with a default implementation (`length() == 0`).
pub(open) trait HasLength {
  length(Self) -> Int

  /// Returns true if length is zero
  is_empty(Self) -> Bool = _
}

///|
/// Default is_empty delegates to length.
impl HasLength with is_empty(self) {
  self.length() == 0
}

///|
/// **Spanning** — two notions of size for position-aware data structures.
///
/// ## Default Chain
///
/// The three size methods form a defaulting chain:
///
/// ```text
/// HasLength::length  ←──  Spanning::span  ←──  Spanning::logical_length
///        (base)          (defaults to length)    (defaults to span)
/// ```
///
/// If you only implement `HasLength::length`, all three return the same value.
/// Override `span()` to diverge from `length()`, or override `logical_length()`
/// to diverge from `span()`.
///
/// ## When to Override
///
/// - **Simple types** (strings, pixel runs): implement `span()` returning the
///   same value as `length()`. MoonBit requires an explicit `impl Spanning`
///   declaration even when using the default behavior.
///
/// - **CRDT tombstones / gap buffers**: override `logical_length` to return
///   visible content size, while `span` counts all elements including deleted
///   or hidden ones. The library uses `span` for position lookup and
///   `logical_length` for content metrics.
///
/// ## Units
///
/// `span` defines the coordinate space for `find`, `split`, `range`, etc.
/// For strings, this is UTF-16 code units. For pixel runs, pixel count.
/// Choose units that match your indexing needs.
pub(open) trait Spanning: HasLength {
  span(Self) -> Int = _
  logical_length(Self) -> Int = _
}

///|
/// Default span delegates to plain length.
impl Spanning with span(self) {
  HasLength::length(self)
}

///|
/// Default logical_length delegates to span.
impl Spanning with logical_length(self) {
  self.span()
}

///|
/// **FromRange** — construct a run value from an integer range `[start, start+count)`.
///
/// Consumers decide what to do with `start`:
/// - Index-carrying types store it: `LvRange { start, count }`
/// - Index-free types discard it: `DenseRun { count }`
///
/// Used by `Rle::from_sorted_ints` and `Runs::from_sorted_ints` to construct
/// runs from groups of consecutive integers.
pub(open) trait FromRange {
  from_range(start : Int, count : Int) -> Self
}

///|
/// **Addressable** — map a position within a run to a domain integer value.
///
/// `global_start` is the run's start position derived from prefix sums.
/// `offset` is 0-based within the run (`0 <= offset < span`).
///
/// Consumers decide the mapping:
/// - Index-carrying: `self.start + offset` (ignores `global_start`)
/// - Index-free: `global_start + offset` (derives from prefix sums)
///
/// Used by `Rle::iter_units` to expand compressed runs into individual integers.
pub(open) trait Addressable {
  address(Self, global_start : Int, offset : Int) -> Int
}
