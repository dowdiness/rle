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
  fn can_merge(Self, Self) -> Bool
  fn merge(Self, Self) -> Self
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
  fn slice(Self, start~ : Int, end~ : Int) -> Result[Self, RleError]
}

///|
/// **HasLength** — basic size of a value (number of runs for containers,
/// character count for strings, etc.).
///
/// Provides `is_empty()` with a default implementation (`length() == 0`).
pub(open) trait HasLength {
  fn length(Self) -> Int

  /// Returns true if length is zero
  fn is_empty(Self) -> Bool = _
}

///|
/// Default is_empty delegates to length.
impl HasLength with fn is_empty(self) {
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
  fn span(Self) -> Int = _
  fn logical_length(Self) -> Int = _
}

///|
/// Default span delegates to plain length.
impl Spanning with fn span(self) {
  HasLength::length(self)
}

///|
/// Default logical_length delegates to span.
impl Spanning with fn logical_length(self) {
  self.span()
}

///|
/// **FromRange** — construct a run value from an integer range `[start, start+count)`.
///
/// This trait enables the generic `from_sorted_ints` algorithm: given sorted
/// integers like `[0, 1, 2, 5, 6, 7]`, the library groups consecutive values
/// into ranges (`[0..3)` and `[5..8)`) and calls `from_range` to build each run.
///
/// The library does not prescribe what your run type looks like — it only needs
/// to know how to construct one from a start value and a count.
///
/// ## Index-Carrying vs Index-Free
///
/// Your type decides whether to store the `start` value or discard it:
///
/// - **Index-carrying** (e.g., `LvRange { start, count }`): stores `start`
///   as a domain identifier. The run knows its own position in the value space.
///   Use this when values have gaps (e.g., Lamport version ranges in a CRDT).
///
/// - **Index-free** (e.g., `DenseRun { count }`): discards `start` — the
///   library's prefix sums will compute positions when needed. Use this when
///   values are dense from zero (no gaps).
///
/// This follows the **algorithm-by-trait** pattern: the library provides the
/// algorithm (`from_sorted_ints`), your type provides the behavior
/// (`from_range`). Just as `Compare` lets you write a generic sort without
/// knowing the element type, `FromRange` lets the library compress sorted
/// integers without knowing your run type.
pub(open) trait FromRange {
  fn from_range(start : Int, count : Int) -> Self
}

///|
/// **Addressable** — map a position within a run to a domain integer value.
///
/// This trait enables the generic `iter_units` algorithm: given compressed
/// runs, expand them back into individual integers. For each unit offset
/// within a run, `address` returns the corresponding domain value.
///
/// ## Parameters
///
/// - `global_start`: the run's start position in the RLE, derived from prefix
///   sums (the cumulative span of all preceding runs). The library computes
///   this automatically — you don't need to store or track it.
///
/// - `offset`: 0-based index within the current run (`0 <= offset < span`).
///
/// ## Index-Carrying vs Index-Free
///
/// Your type decides which parameter to use:
///
/// - **Index-carrying** (e.g., `LvRange`): `self.start + offset` — the run
///   knows its own start, so `global_start` is ignored.
///
/// - **Index-free** (e.g., `DenseRun`): `global_start + offset` — the run
///   doesn't store a start, so positions are derived from prefix sums.
///
/// Both approaches produce correct results. The library doesn't know or care
/// which one your type uses — it just calls `address` and gets an `Int` back.
pub(open) trait Addressable {
  fn address(Self, global_start : Int, offset : Int) -> Int
}
