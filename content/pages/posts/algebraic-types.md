Every programming language has the concept of types, even the dynamic ones. Even when we don't think about programs in terms of types, we use them without being aware. For instance, when we sum two arguments in a function, we implicitly expect the two values to be summable with each other. This can be an integer or float, or even something else like imaginary numbers.

There is a great deal of research being done on types, which had been an inspiration for many practical languages, especially in the last 20 years. Working programmers can benefit from knowing the very basic concepts about types. This knowledge will teach you what is really essential about types, so you will know what concept should you use when you define value types and interfaces. In my experience, it also helps in learning new programming languages, because when you know the fundamentals, you can map from the language constructs to concepts that you already know.

Algebraic types, sound like a very technical term. However, it's actually very simple and it's related to the concepts you learned in elementary school algebra lectures. In this post, I want to explain it to a working programmer in as simple as possible way.

## Types as Sets

What is a type, really? For instance, when we write `int`, what does it mean? One useful way to think about it is to treat types as sets. In this perspective, every type is treated as a set of possible values that is compatible with the type. For instance, `bool` is a type that has only `true` and `false` values. In OCaml `bool` is defined as:

```ocaml
type bool = true | false
```

In the left hand side we define the type `bool`. The right side provides the possible values, separated with `|`.

For integers, this is `0`, `1` or any other integer value. It's a bit more difficult to define integers directly as a regular type because in this case there are infinitely many values that integer can take. Writing all these is impossible. But assuming it was possible, we could write:

```ocaml
type int = ... | -3 | -2 | -1 | 0 | 1 | 2 | 3 | ...
```

In practice, integer types are usually limited to some finite range (but still too large) but this is not related to what we are discussing here. Strings are very similar to integers from this perspective.

What about `void` type? What are the values that it accepts? In some languages it's not obvious, but we can think `void` as a type with only a single possible value. In OCaml for instance, `unit` corresponds to `void`. It's defined as:

```ocaml
type unit = ()
```

In C, C++ or Java, `void` is treated differently than other types which makes it awkward to use in some cases. If we consider it as just any other type, there is no real need to make an exception for `void`. This simplifies the type system as well as the implementation of the programming language. I will give some examples to this after we understand [Algebraic Types](#algebraic-types-is-not-scary-actually).

Another interesting case is non-termination. What is the type of a while loop that never returns? Well, using the set perspective, if the expression returns no value, maybe it's type is a type which has no possible values? Note that this type is _different_ than `void` because `void` has one value that it can take but this type can take none. Sometimes this type is called `never`, as in it's never possible to have a value of this type. We can also trivially define this type as:

```ocaml
type never
```

## Algebraic Types is Just Elementary School Algebra

TODO

## Conclusion

In short, using this perspective we can have a unified understanding of types that commonly appear in most programming languages.