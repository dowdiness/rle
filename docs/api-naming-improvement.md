# API Naming Improvement Proposal

**Status**: Draft Proposal
**Created**: 2026-02-19
**Target Version**: 1.0.0 (current: 0.1.0 in moon.mod.json)
**Breaking Changes**: Yes (pre-release, no migration needed)

---

## Executive Summary

This proposal suggests renaming core API methods to follow standard naming conventions before the initial 1.0.0 release. Since the library has not been publicly released yet, we can make these changes without migration concerns.

## Background

### Current Implementation Analysis

The RLE library's trait design is **already correct**:
```moonbit
pub(open) trait HasLength {
  length(Self) -> Int
}

pub(open) trait Spanning: HasLength {
  span(Self) -> Int = _
  content_len(Self) -> Int
}
```

The inheritance relationship `Spanning: HasLength` properly reflects the semantic hierarchy: all space-occupying elements have a length.

### Problems with Current Naming

1. **`count()` vs `length()`**: Non-standard terminology
   - Standard libraries use `length()` for element count
   - `count()` typically means "count occurrences"

2. **`len()` abbreviation**: Creates confusion
   - Abbreviated form is less clear
   - Conflicts with existing trait method name `span()`

3. **`content_len()` ambiguity**: Unclear meaning
   - "content" is vague
   - Doesn't clearly distinguish from `span()`

4. **`is_empty()` not exposed via trait**: `Runs` and `Rle` both have `is_empty()` but it is not
   part of the `HasLength` trait, so generic code constrained to `HasLength` cannot call it

## Why Fix This Now (Pre-Release)

### Perfect Timing

- **No public release yet**: Zero migration burden
- **Clean slate**: 1.0.0 will have the right API from day one
- **No technical debt**: Avoid locking in poor naming
- **Professional launch**: Strong first impression

### Comparison: Fix Now vs Later

| Aspect | Fix Pre-Release | Fix Post-Release |
|--------|----------------|------------------|
| Migration needed | ❌ No | ✅ Yes |
| Breaking changes | ✅ Free | ❌ Requires v2.0.0 |
| User impact | ✅ None | ❌ Significant |
| Implementation cost | ✅ Low | ❌ High (deprecation) |
| API quality | ✅ Clean 1.0 | ❌ Technical debt |

## Proposed Changes

### 1. Method Renaming

| Current API | Proposed API | Rationale |
|-------------|--------------|-----------|
| `Rle::count()` | `Rle::length()` | Standard terminology (Array, List) |
| `Runs::count()` | `Runs::length()` | Consistency |
| `Rle::len()` | `Rle::span()` | No abbreviation, matches trait |
| `Runs::len()` | `Runs::span()` | Consistency |
| `Rle::content_len()` | `Rle::logical_length()` | Logical vs physical distinction |
| `Runs::content_len()` | `Runs::logical_length()` | Consistency |
| `PrefixSums::len()` | `PrefixSums::span()` | Consistency |
| `PrefixSums::content_len()` | `PrefixSums::logical_length()` | Consistency |
| `PrefixSums::count()` | `PrefixSums::length()` | Consistency |

### 2. New Trait Methods

#### HasLength Enhancement
```moonbit
pub(open) trait HasLength {
  /// Returns the number of elements or size
  length(Self) -> Int

  /// Returns true if length is zero
  /// Default implementation checks if length equals zero
  /// Can be overridden for performance optimization
  is_empty(Self) -> Bool {
    self.length() == 0
  }
}
```

#### Spanning Enhancement
```moonbit
pub(open) trait Spanning: HasLength {
  /// Total span in index space
  /// Default: delegates to length()
  span(Self) -> Int = _

  /// Logical content length
  /// Default: delegates to span() (no hidden elements)
  logical_length(Self) -> Int {
    self.span()
  }
}

impl Spanning with span(self) {
  HasLength::length(self)
}
```

**Rationale for `logical_length()` default**:
- Most types have no hidden elements, so logical == physical
- `logical_length() == span()` is the common case
- Reduces boilerplate for simple types; override only when logical size differs from span

### 3. Implementation Changes

#### traits.mbt
```moonbit
///|
/// **HasLength** - Basic length for any measurable type
pub(open) trait HasLength {
  /// Returns the number of elements or size
  length(Self) -> Int

  /// Returns true if length is zero
  is_empty(Self) -> Bool {
    self.length() == 0
  }
}

///|
/// **Spanning** - Dual-length semantics for elements occupying space
pub(open) trait Spanning: HasLength {
  /// Total span in index/position space (includes hidden elements)
  span(Self) -> Int = _

  /// Logical content length (excludes hidden elements)
  /// Default: same as span (no hidden elements)
  logical_length(Self) -> Int {
    self.span()
  }
}

impl Spanning with span(self) {
  HasLength::length(self)
}
```

#### rle.mbt
```moonbit
///| HasLength impl — number of runs
pub impl[T] HasLength for Rle[T] with length(self : Rle[T]) -> Int {
  self.runs.0.length()
}

///| HasLength impl — is_empty (already exists as standalone; move into trait impl)
pub impl[T] HasLength for Rle[T] with is_empty(self : Rle[T]) -> Bool {
  self.runs.0.is_empty()
}

///| Spanning impl — total span, O(1) with cache
pub impl[T : Spanning] Spanning for Rle[T] with span(self : Rle[T]) -> Int {
  self.ensure_prefix().span()
}

///| Spanning impl — logical content length, O(1) with cache
pub impl[T : Spanning] Spanning for Rle[T] with logical_length(self : Rle[T]) -> Int {
  self.ensure_prefix().logical_length()
}
```

#### runs.mbt
```moonbit
///| HasLength impl — number of runs
pub impl[T] HasLength for Runs[T] with length(self : Runs[T]) -> Int {
  self.0.length()
}

///| HasLength impl — is_empty (already exists as standalone; move into trait impl)
pub impl[T] HasLength for Runs[T] with is_empty(self : Runs[T]) -> Bool {
  self.0.is_empty()
}

///| Spanning impl — total span, O(n)
pub impl[T : Spanning] Spanning for Runs[T] with span(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::span(item) })
}

///| Spanning impl — total logical length, O(n)
pub impl[T : Spanning] Spanning for Runs[T] with logical_length(self : Runs[T]) -> Int {
  self.0.fold(init=0, fn(acc, item) { acc + T::logical_length(item) })
}
```

#### prefix_sums.mbt
```moonbit
pub(all) struct PrefixSums {
  spans : Array[Int]
  content : Array[Int]
}

impl PrefixSums {
  /// Total span - O(1)
  pub fn span(self : PrefixSums) -> Int {
    match self.spans.last() {
      Some(total) => total
      None => 0
    }
  }

  /// Total logical length - O(1)
  pub fn logical_length(self : PrefixSums) -> Int {
    match self.content.last() {
      Some(total) => total
      None => 0
    }
  }

  /// Number of runs
  pub fn length(self : PrefixSums) -> Int {
    self.spans.length()
  }
}
```

#### runs_string.mbt

No change needed. With `logical_length()` defaulting to `self.span()` and `String::span()` delegating to `HasLength::length(self)`, the default already returns the correct value. The previous explicit `content_len` override is simply removed.

## Implementation Plan

### Timeline: 1 Week to 1.0.0

#### Day 1-2: Core Implementation

- [ ] **traits.mbt**
  - [ ] Add `is_empty()` default to `HasLength`
  - [ ] Add `logical_length()` default to `Spanning`
  - [ ] Rename trait method `content_len()` to `logical_length()`

- [ ] **rle.mbt**
  - [ ] Rename `count()` → `length()`
  - [ ] Rename `len()` → `span()`
  - [ ] Rename `content_len()` → `logical_length()`
  - [ ] `is_empty()` already exists — add to `pub impl HasLength for Rle[T]` block
  - [ ] Add explicit `pub impl HasLength for Rle[T]` block
  - [ ] Add explicit `pub impl Spanning for Rle[T]` block
  - [ ] Update all internal method calls

- [ ] **runs.mbt**
  - [ ] Rename `count()` → `length()`
  - [ ] Rename `len()` → `span()`
  - [ ] Rename `content_len()` → `logical_length()`
  - [ ] `is_empty()` already exists — add to `pub impl HasLength for Runs[T]` block
  - [ ] Add explicit `pub impl HasLength for Runs[T]` block
  - [ ] Add explicit `pub impl Spanning for Runs[T]` block
  - [ ] Update all internal method calls

- [ ] **prefix_sums.mbt**
  - [ ] Rename `len()` → `span()`
  - [ ] Rename `content_len()` → `logical_length()`
  - [ ] Rename `count()` → `length()`

- [ ] **runs_string.mbt**
  - [ ] Remove `content_len` impl — `logical_length()` default is now sufficient

- [ ] **rle_benchmark.mbt** *(trait impl — compile blocker)*
  - [ ] Remove `pub impl Spanning for BenchRun with content_len` — default `logical_length()` is sufficient (same as `String` case)

- [ ] **rle_cursor.mbt**
  - [ ] Rename 4 calls of `self.rle.len()` → `self.rle.span()` (lines 64, 76, 149, 183)

- [ ] **slice.mbt** — no changes needed (verified: no calls to renamed methods)

- [ ] **arbitrary.mbt** — no changes needed (verified: no calls to renamed methods)

#### Day 3-4: Testing

- [ ] **Update all tests**
  - [ ] `rle_test.mbt` (75 tests)
  - [ ] `runs_test.mbt` (54 tests)
  - [ ] `runs_properties_test.mbt` (18 property tests)
  - [ ] `runs_wbtest.mbt` (10 whitebox tests)
  - [ ] `rle_benchmark.mbt` — benchmark call sites only (trait impl handled in Day 1-2)

- [ ] **Add new test coverage**
  - [ ] Test `is_empty()` — no runs
  - [ ] Test `HasLength::is_empty()` via generic constraint
  - [ ] Test default implementations

- [ ] **Run full test suite**
```bash
  moon check
  moon test
  moon bench --release
```

#### Day 5: Documentation

- [ ] **README.md**
  - [ ] Update Quick Start section
  - [ ] Update API Overview table
  - [ ] Update all code examples

- [ ] **ARCHITECTURE.md** *(does not exist yet — create or skip)*
  - [ ] Document method names and complexity in type descriptions


- [ ] **CLAUDE.md**
  - [ ] Update known patterns
  - [ ] Update examples

- [ ] **Create CHANGELOG.md**
```markdown
  # Changelog

  ## [1.0.0] - 2026-MM-DD

  Initial stable release with clean, consistent API.

  ### Features

  - Generic run-length encoding with O(log n) position lookup
  - Lazy prefix sum caching for efficient queries
  - Dual-length semantics (span vs logical_length)
  - Cursor-based sequential traversal with staleness detection
  - Comprehensive trait system (HasLength, Spanning, Mergeable, Sliceable)
  - Full Unicode support (UTF-16 code units)
  - Property-based testing with QuickCheck
  - Batch construction and operations

  ### API

  - `Rle::new()` - Create empty sequence
  - `Rle::from_array()` - Batch construction with merging
  - `Rle::from_string()` - Create from string
  - `Rle::length()` - Number of runs
  - `Rle::span()` - Total span (O(1) cached)
  - `Rle::logical_length()` - Logical content length (O(1) cached)
  - `Rle::is_empty()` - Check if empty
  - `Rle::find()` - O(log n) position lookup
  - `Rle::append()` - Append with auto-merge
  - `Rle::split()` - Split at position
  - `Rle::concat()` - Concatenate sequences
  - `Rle::extend()` - In-place extension
  - `Rle::range()` - Iterate slices in range
  - `Rle::cursor()` - Create traversal cursor

  See README.md for full API documentation.
```

#### Day 6-7: Release Preparation

- [ ] **Version Updates**
  - [ ] Set `moon.mod.json` to `"version": "1.0.0"`
  - [ ] Verify all dependencies

- [ ] **Quality Assurance**
  - [ ] Run full test suite: `moon test`
  - [ ] Run benchmarks: `moon bench --release`
  - [ ] Verify no performance issues
  - [ ] Manual testing with examples

- [ ] **Git Operations**
  - [ ] Commit all changes
  - [ ] Tag release: `git tag -a v1.0.0 -m "Release v1.0.0"`
  - [ ] Push tag: `git push origin v1.0.0`

- [ ] **Publish**
  - [ ] Publish to mooncakes.io
  - [ ] Update repository description
  - [ ] Create GitHub release with CHANGELOG

## Benefits

### 1. Professional 1.0.0 Launch

- Clean, consistent API from day one
- No "legacy" naming to explain
- Strong first impression for new users

### 2. Standards Compliance
```moonbit
// Matches MoonBit conventions
let arr = [1, 2, 3]
arr.length()  // Standard

let rle = Rle::from_string("hello")
rle.length()  // ✓ Consistent
rle.span()    // ✓ Clear
rle.logical_length()  // ✓ Explicit
```

### 3. Self-Documenting API
```moonbit
// Before: requires explanation
rle.len()          // Total? Visible? Run count?
rle.content_len()  // What content?

// After: obvious meaning
rle.span()            // Total space occupied (physical)
rle.logical_length()  // Meaningful payload (logical)
rle.length()          // Number of runs
```

### 4. Generic Empty Check
```moonbit
// is_empty() is now part of HasLength — works in generic contexts
fn process_if_nonempty[T : HasLength](container : T) -> Unit {
  if container.is_empty() { return }  // complexity depends on T's length() impl
  ...
}

// Works uniformly for Rle, Runs, or any future HasLength implementor
process_if_nonempty(rle)
process_if_nonempty(runs)
```

## Implementation Details

### Files to Modify

#### Core Implementation (Day 1-2)
- `rle/traits.mbt` - Add `is_empty()` default to `HasLength`, add `logical_length()` default to `Spanning`, rename `content_len()`
- `rle/rle.mbt` - Rename methods, add explicit trait impl blocks
- `rle/runs.mbt` - Rename methods, add explicit trait impl blocks
- `rle/prefix_sums.mbt` - Rename methods
- `rle/runs_string.mbt` - Remove `content_len` impl (default is now sufficient)
- `rle/rle_cursor.mbt` - Rename 4 calls of `len()` → `span()` (lines 64, 76, 149, 183)

#### Tests (Day 3-4)
- `rle/rle_test.mbt` - Update 75 test assertions
- `rle/runs_test.mbt` - Update 54 test assertions
- `rle/runs_properties_test.mbt` - Update 18 property tests
- `rle/runs_wbtest.mbt` - Update 10 whitebox tests
- `rle/rle_benchmark.mbt` - Update benchmark call sites

#### Documentation (Day 5)
- `README.md` - Update all examples and API tables
- `ARCHITECTURE.md` - Create if desired, or skip (file does not exist yet)
- `CLAUDE.md` - Update patterns
- **New**: `CHANGELOG.md` - Create initial entry

#### Configuration (Day 6)
- `moon.mod.json` - Version to 1.0.0

### Verification Checklist

Before tagging v1.0.0:

- [ ] `moon check` passes
- [ ] `moon test` passes (100%)
- [ ] `moon bench --release` runs without errors
- [ ] Regenerate API surface: `moon info` → verify `rle/pkg.generated.mbti` exports new names
- [ ] All examples in README work
- [ ] CHANGELOG is accurate
- [ ] Documentation is consistent

## Success Criteria

### Must Have (Release Blockers)

- ✅ All tests pass
- ✅ No performance regression
- ✅ All documentation updated
- ✅ CHANGELOG complete

### Should Have (High Priority)

- ✅ All method names consistent
- ✅ All trait defaults implemented
- ✅ Examples verified

### Nice to Have (Optional)

- ⭕ Additional examples
- ⭕ Tutorial content
- ⭕ Performance comparison charts

## Risks and Mitigation

### Risk 1: Implementation Bugs

**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Changes are mostly mechanical (renames)
- Comprehensive test suite catches issues
- Property-based tests verify behavior

### Risk 2: Missed Updates

**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Use compiler errors as checklist
- Systematic file-by-file review
- Test suite will catch runtime issues

### Risk 3: Documentation Drift

**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- Update docs in same PR
- Verify all code examples
- Review checklist

## Alternatives Considered

### Alternative 1: Keep Current Naming

**Decision**: ❌ Rejected

**Reasoning**:
- Locks in poor naming forever
- First release is the time to fix
- No users affected yet

### Alternative 2: Minimal Changes

**Decision**: ❌ Rejected

**Reasoning**:
- Incomplete solution
- Will need more changes later
- Better to do it right once

### Alternative 3: This Proposal

**Decision**: ✅ **Selected**

**Reasoning**:
- Perfect timing (pre-release)
- Complete solution
- Professional result
- Zero migration cost

## Timeline Summary
```
Week 1: Final API Stabilization for 1.0.0
├─ Day 1-2: Implementation
├─ Day 3-4: Testing
├─ Day 5:   Documentation
└─ Day 6-7: Release

Target: 1.0.0 release
```

## Conclusion

This proposal represents the final API cleanup before the 1.0.0 release. Since there are no public users yet, we can make these breaking changes at zero cost while establishing a professional, standards-compliant foundation.

**Recommendation**: Approve and implement before 1.0.0 release.

---

## Appendix: Complete File Checklist

### Implementation Files
- [ ] `rle/traits.mbt`
- [ ] `rle/rle.mbt`
- [ ] `rle/runs.mbt`
- [ ] `rle/prefix_sums.mbt`
- [ ] `rle/runs_string.mbt`
- [ ] `rle/rle_cursor.mbt`
- [ ] `rle/rle_benchmark.mbt` *(trait impl — compile blocker)*

### Test Files
- [ ] `rle/rle_test.mbt`
- [ ] `rle/runs_test.mbt`
- [ ] `rle/runs_properties_test.mbt`
- [ ] `rle/runs_wbtest.mbt`

### Documentation Files
- [ ] `README.md`
- [ ] `ARCHITECTURE.md`
- [ ] `CLAUDE.md`
- [ ] `CHANGELOG.md` (create)

### Configuration Files
- [ ] `moon.mod.json`

### Generated Files (regenerate, do not edit manually)
- [ ] `rle/pkg.generated.mbti` — run `moon info` after all renames; verify exported names match new API

### Files Not Modified
- [ ] `.gitignore`
- [ ] `rle/errors.mbt`
- [ ] `rle/run_pos.mbt`
- [ ] `rle/slice.mbt`
- [ ] `rle/arbitrary.mbt` (verify only)
- [ ] `rle/moon.pkg`

---

**Next Steps**: Review, approve, and begin implementation.
