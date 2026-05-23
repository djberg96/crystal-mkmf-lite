## 0.2.0 - 22-May-2026
* Added `have_library`, including optional function/header checks and support
  for library names with or without a leading `lib`.
* Added `check_offsetof`.
* Allow optional include directories for `check_sizeof` and `check_valueof`.
* Cache public probe results since they are not expected to change between
  calls.
* Reuse a shared compile command builder for probe methods, including
  Homebrew library paths on macOS when present.

## 0.1.0 - 11-Feb-2021
* Initial release
