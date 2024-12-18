
Proper error handling is hard. It's maybe one of the hardest problems in programming. A program could be very easy when only programming for the happy path, but incredibly difficult and costly when considering all the failure cases and gracefully handling them. A lot of production code either ignores errors or simply accumulate them to the top level with a generic error message. It's very rare that all possible error cases are even mentioned in the documentation, let alone reflected in the code.

Strangely, while many believe that error handling is very important I believe that mainstream languages really suck at providing tools for error handling. The main issues I see are: relying on conventions, restrictive type systems and poor composability. However, I think that there is actually an approach that can be enforced without putting too much mental load into the programmer's mind while still being composable and applicable to real code.

In this article, I go about main approaches to error handling, argue about their strengths and weaknesses. Then I propose the approach that I think the best we have yet, which is not really too much different than one of the approaches I discuss before.

## The Philosophy of Error Handling

As far as I know, there are two main philosophical approaches to error handling. First one acknowledges that error handling is too hard and complex to manage it in a type system. Therefore they either use special error values or runtime exceptions. There are further divisions in this camp (like Go's approach vs. Java's runtime exception approach) but I won't go into detail about them. All of those subcamps has the same belief that it's not worth encoding errors into the types.

The other camp believes that error handling is complex, but it can be somewhat tracked in the type system even if it's not possible for every case. They think that many trivial errors could be prevented with encoding more information into type system like famous `NullPointerException` and also other mistakes like using a value before checking if it's a special value indicating an error.

I place myself into the second camp. The main point of this article is not to convince you that this approach is better. There are many great articles arguing for both takes. But nevertheless we need to discuss various approaches and argue about their weaknesses to understand what they lack.

## Error handling approaches in mainstream languages

- Brief description. Maybe reference other posts.
- Why they suck.

### Special Values

This approach essentially uses some values of a type to have special meanings. For example, [open](https://www.man7.org/linux/man-pages/man2/open.2.html#RETURN_VALUE) syscall in Linux returns an integer. This integer is normally the file descriptor, but on error it has a special value `-1`. It purely relies on convention that users will check the return value before using it so they don't use `-1` as a valid file descriptor.

This approach has couple advantages. First, it's easy to implement because it requires literally zero language support. It can be achieved purely by using existing language constructs. Another advantage is that it's easy to understand: if you have a special value then it's an error, otherwise it's not. It's a simple if-else check.

However, there are serious disadvantages as well. Most pressing issue is simply relying on human convention and putting all burden to the users. Users must memorize all the special values they use or they need to constantly check the documentation which slows them down. Also it's possible that documentation is not clear on which values are special or worse it's not even documented! 

Another problem is that it's not possible to be sure that a value is already checked or not. You can say that "Why? If the checks are passed, then surely it's a valid value after". This is true when you have no functions and all code is in one place. But what if you write a function? How do you enforce that user doesn't pass an invalid value if you only want to operate on valid values? The answer is that you can't. You acknowledge that you can't prevent from user from passing invalid values, thus you need to write [defensive checks](https://en.wikipedia.org/wiki/Defensive_programming). This leads to duplicate checks and a lot of boilerplate code. Also it creates unnecessary maintenance burden for the extra cases you have to deal with. 

The last problem is that when you change the code so that some assumptions about a variable changes, you need to mentally propagate new conditions into rest of the code. As with everything that relies on people it's error prone and causes unnecessary mental load. When you do a mistake during propagation you end up with new bugs that you are not aware. For example, you check a variable is valid, then perform some operation on it. But later if you add a code that mutates that variable in between, you will probably forget to check it after the mutation. It is easy to do this mistake when there are many variables involved or there are deep call chains.

The drawbacks are obvious in [open](https://www.man7.org/linux/man-pages/man2/open.2.html#RETURN_VALUE). Whenever you take a file descriptor as an argument you have to consider the case that passed file descriptor is not actually valid. User may have forgotten to check if file descriptor is not equal to `-1`. And there is no way to restrict the argument type into _only valid_ file descriptor values. This causes a lot of unnecessary lines of codes when you want to just operate on valid values. Which causes more maintenance burden and also more tests.

TODO: check if there is research behind it.

Because of the drawbacks, this approach is ver unpopular these days. However, there are still some new languages that prefer this approach (looking at you Go).

### Exceptions

### Errors as Values

## Proposed approach

- composability
- Compile time checking
- Techniques 
    - Structural type systems
- Weaknesses
- the reasons why mainstream languages still don't have them. 

[^1]: https://engineering.fb.com/2022/11/22/developer-tools/meta-java-nullsafe/