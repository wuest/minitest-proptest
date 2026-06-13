## [0.5.1] - 2026-06-13
- Fix display bug to ensure Ruby 3.3 - 4.0 are universally supported when shrinking

## [0.5.0] - 2026-05-10
- Supported versions updated:
  - Ruby 3.3 - 4.0
- Fixed display bug under 4.0 where new TracePoint interface caused shrinker to fail to report local variables

## [0.4.0] - 2025-25-28
- Supported versions updated:
  - Ruby 3.2 - 4.0
  - Minitest 5.0 - 6.X

## [0.3.0] - 2024-09-17
- Bug fix: signed integer psuedotypes could produce MAX + 1 (e.g. 128 for Int8)
- Bug fix: failure persistence no longer prevents displaying variable
  assignments in failure messages
- `where` method now short-circuits property checks, reducing runtime
- Add `Time` generator

## [0.2.1] - 2024-09-08
- Added richer feedback when a property is falsified

## [0.2.0] - 2024-03-21

- Added `where` method to discard invalid generated test cases
- Added support for Minitest assertions within properties
- Added types from standard library
  - Complex
  - Range
  - Rational
- Improved assertion count accuracy
- Improved documentation

## [0.1.0] - 2024-03-13

- Added failure persistence to prevent flaky tests

## [0.0.2] - 2022-09-15

- Bugfixes, first useful release
- Added CI via GitHub Actions

## [0.0.1] - 2022-09-15

- Initial release (yanked)
