# Changelog

## [1.0.0] - 2026-02-19

Initial stable release with clean, consistent API.

### Breaking Changes

- `Rle::count()` → `Rle::length()`
- `Runs::count()` → `Runs::length()`
- `Rle::len()` → `Rle::span()`
- `Runs::len()` → `Runs::span()`
- `Rle::content_len()` → `Rle::logical_length()`
- `Runs::content_len()` → `Runs::logical_length()`
- `PrefixSums::len()` → `PrefixSums::span()`
- `PrefixSums::content_len()` → `PrefixSums::logical_length()`
- `PrefixSums::count()` → `PrefixSums::length()`
- `Spanning::content_len` trait method renamed to `logical_length` (now has default)
- `HasLength::is_empty()` added as trait method (default: `length() == 0`)

### Features

- Generic run-length encoding with O(log n) position lookup
- Lazy prefix sum caching for efficient queries
- Dual-length semantics (`span` vs `logical_length`)
- Cursor-based sequential traversal with staleness detection
- Comprehensive trait system (`HasLength`, `Spanning`, `Mergeable`, `Sliceable`)
- Full Unicode support (UTF-16 code units)
- Property-based testing with QuickCheck
- Batch construction and convenience operations (`insert`, `delete`, `splice`, `value_at`)
