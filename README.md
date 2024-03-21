[![Version](https://img.shields.io/gem/v/minitest-proptest)][badges:0-gem]
[![Build](https://img.shields.io/github/actions/workflow/status/wuest/minitest-proptest/ci.yaml?branch=main)][badges:1-CI]
[![License](https://img.shields.io/github/license/wuest/minitest-proptest)][badges:2-license]

# Property Testing in Minitest

Minitest-Proptest allows tests to be expressed in terms of universal properties,
and will generate test cases to try to disprove them the cases listed
automatically.  This library is heavily inspired by
[QuickCheck][intro-1:quickcheck] and [Hypothesis][intro-2:hypothesis].

## Writing Tests

Tests should be written to express a universal property in the simplest manner
achievable.  Properties can be expressed via `property` within any context where
an assertion is allowed.

### Goal of Property Testing

Property tests should aim to express **universal properties** of the code under
test - the framework will generate test cases to try to find counter-examples
to properties listed.

### Test Structure

Tests should usually follow the following sequence:

1. Allocate arbitrary primitives
2. Build necessary data structures from the primitives
3. Provide predicates to filter out inappropriate data generation
4. Express assertions and return a boolean
  - All Minitest assertions are available within a property.  They will
    conveniently return a boolean.
  - The block provided to the `property` method is an implicit assertion - the
    assertion will fail if the return value is not truthy.

A trivial example can be seen below:

```ruby
class PropertyTest < Minitest::Test
  def test_average_list
    # Allocate a list of Integers
    xs = arbitrary Array, UInt8

    # The list must contain at least one value
    where { !xs.empty? }

    # Calculate the list's average
    average = xs.reduce(&:+) / xs.length.to_f

    # Conclude the block with the core assertion of universal property:
    xs.min <= average <= xs.max
  end
end
```

This can also be expressed with `assert`:

```ruby
class PropertyTest < Minitest::Test
  def test_average_list
    # Allocate a list of Integers
    xs = arbitrary Array, UInt8

    # The list must contain at least one value
    where { !xs.empty? }

    # Calculate the list's average
    average = xs.reduce(&:+) / xs.length.to_f

    # Conclude the block with the core assertion of universal property:
    assert xs.min <= average <= xs.max
  end
end
```

Using Minitest assertions is particularly useful when a long chain of logic
would otherwise be necessary to express a success case.

### Test Tips

In order for tests and shrinking to work as expected, the two following tips
will set a test writer up for success:

* Allocate everything you might need up front
* Allocate everything you need in the same place

Allocating everything that will be needed up front avoids the possibility of
predicating allocation on other allocations.  This breaks the shrinking logic
and must be avoided.

Allocating everything in the same place makes it easier to parse
counter-examples when they're found.

## Built-in Types

The following types are provided by Minitest-Proptest:

* Unbounded `Integer`
* Unsigned Integers
  * `UInt8`
  * `UInt16`
  * `UInt32`
  * `UInt64`
* Signed Integers
  * `Int8`
  * `Int16`
  * `Int32`
  * `Int64`
* Floating Point
  * `Float32`
  * `Float64`
  * `Float` - identical to `Float64`
* `Complex` numbers
* `Rational` numbers
* Text types
  * `Char` - any single character 0x00-0xff
  * `ASCIIChar` - any character 0x00-0x7f
  * `String` - arbitrary length string of `Char`s
* `Bool`
* Polymorphic types
  * `Array a` - array of arbitrary length of another type
  * `Hash a b` - hash of arbitrary size from type `a` to type `b`
  * `Range a` - range between two values whose classes implement `<=>`

## Writing Generators

Generators provide the machinery through which arbitrary values are provided,
scored, and shrunk when a counterexample is found.  It is typically only
relatively primitive data which require generators, while non-primitive objects
are generally constructed from arbitrary data.

Writing high quality generators for primitive types can make or break property
tests' ability to provide reliable results.  While a large number of built-in
primitive generators are provided, cases will arise for which additional
generators are required to improve tests' clarity.

### Generating Simple Values

Generators are written with the `generator_for` method, which is available
globally.  The simplest case is to create a generator for a type which generates
data directly.

#### Generator Helpers

* The `sized` method provides a random Integer from 0 to the provided value,
  inclusive.  This provides direct access to entropy for the purpose of
  primitive generation.
  ```ruby
  BoxedUInt8 = Struct.new(:value)
  generator_for(BoxedUInt8) do
    i = sized(0xff)
    BoxedUInt8.new(i)
  end

  # ...
  boxed = arbitrary BoxedUInt8
  ```
* The `one_of` method will produce a random selection of a set of values.  The
  set may be given as any collection which implements `to_a`.  This provides
  indirect access to entropy via the selection of value.
  ```ruby
  Dice = Struct.new(:value)
  generator_for(Dice) do
    Dice.new(one_of(1..6))
  end

  # ...
  one_d_six = arbitrary Dice
  ```

### Scoring and Shrinking

Finding counter-examples is made more helpful when the counter-examples are able
to be meaningfully reduced to an easier failure case about which to reason.
Built-in generators which provide numeric values will tend towards zero as they
are shrunk (n.b. `Float` types will consider `NaN` and `Infinity` as having an
equal score to 0), and types which are list-like will try to drop elements while
shrinking the elements' respective values.  The default behavior of any custom
generator will be to convert the value to an integer via `to_i` and take its
absolute value.

If a scoring and shrink function are provided to the generator, any failure
condition will be retried in forms which are generated according to the
functions in question until the score closest to zero is obtained.

The `BoxedUInt8` definition can be rewritten for shrinking with the following
shrink and score functions:

```ruby
BoxedUInt8 = Struct.new(:value)

generator_for(BoxedUInt8) do
  i = sized(0xff)
  BoxedUInt8.new(i)
end.with_shrink_function do |i|
  candidates = []
  y = i.value

  until y.zero?
    candidates << BoxedUInt8.new(i.value - y)
    candidates << BoxedUInt8.new(y)
    y = (y / 2.0).to_i
  end

  candidates
end.with_score_function do |i|
  i.value
end
```

### Parametric Polymorphism

In cases where a type might be inhabited by various other types, the block
provided to `generator_for` can take arguments.  This block will be treated as
equivalent to a curried constructor, e.g.

```ruby
Twople = Struct.new(:fst, :snd) do
generator_for(Twople) do |fst, snd|
  Twople.new(fst, snd)
end.with_shrink_function do |ffst, fsnd, t|
  f_candidates = ffst.call(t.fst)
  s_candidates = fsnd.call(t.snd)

  f_candidates.reduce([]) do |candidates, fst|
    candidates + s_candidates.map { |snd| Twople.new(fst, snd) }
  end
end.with_score_function do |ffst, fsnd, t|
  ffst.call(t.fst) + fsnd.call(t.snd)
end

# ...
tuple = arbitrary Twople, Int8, Int8
```

Note that the functions for shrinking and scoring should be parameterized to
accept functions for shrinking or scoring the contained data.  These can be used
to further refine the generation of minimal counterexamples.

### Variable-Size Data

In cases where a given datatype can be arbitrarily sized and it's useful to
generate varying sizes of data for tests, functions for appending and generating
an empty/initial state of the datatype with the `with_append` and `with_empty`
methods respectively.

The append and empty functions for generating Arrays can serve as a reasonable
example:

```ruby
generator_for(Array) do |x|
  [x]
end.with_append(0, 0x10) do |xs, ys|
  xs + ys
end.with_empty { [] }
```

Note that `with_append` requires a minimum and maximum size which is acceptable
to generate to be supplied.

Additional examples of generators are available in
[lib/minitest/proptest/gen.rb][generators-1:gen.rb]

## Requirements

Minitest-Proptest is designed to work with Minitest 5.0 or greater.  Non-EOL
Rubies are tested to work; older rubies may work as well.

## License

Minitest-Proptest is released under the [MIT License][license-1:MIT]

## Contributions

Whether the contribution concerns code, documentation, bug reports, or something
else entirely, contributions are welcome and appreciated!

If the contribution is relating to a security concern, please see
[SECURITY.md][SECURITY].

For all other contributions, please see
[CONTRIBUTING.md][CONTRIBUTING].  In short:

  * Fork the project.
  * Add tests for any new functionality/to verify that bugs have been fixed.
  * Send a pull request on GitHub.

## Code of Conduct

The Minitest-Proptest project is governed by a
[Code of Conduct][code-of-conduct].

[badges:0-gem]: https://rubygems.org/gems/minitest-proptest
[badges:1-CI]: https://github.com/wuest/minitest-proptest/actions/workflows/ci.yaml
[badges:2-license]: https://github.com/wuest/minitest-proptest/blob/main/LICENSE
[intro-1:quickcheck]: https://hackage.haskell.org/package/QuickCheck
[intro-2:hypothesis]: https://github.com/HypothesisWorks/hypothesis
[generators-1:gen.rb]: https://github.com/wuest/minitest-proptest/blob/main/lib/minitest/proptest/gen.rb
[license-1:MIT]: https://github.com/wuest/minitest-proptest/blob/main/LICENSE
[SECURITY]: https://github.com/wuest/minitest-proptest/blob/main/SECURITY.md
[CONTRIBUTING]: https://github.com/wuest/minitest-proptest/blob/main/CONTRIBUTING.md
[code-of-conduct]: https://github.com/wuest/minitest-proptest/blob/main/CODE_OF_CONDUCT.md
