
Proper error handling is hard. It's a concept since the inception of programming, yet solutions we have are hardly satisfying. When one tries to add proper error handling into their code it gets much more complicated than just implementing the happy path. Part of it is inescapable because it's [Essential Complexity]() but part of the complication is not necessary hence [Accidental Complexity](). A lot of production code either ignores errors or simply accumulate them to the top level with a generic error message. It's very rare that all possible error cases are even considered before implementation, let alone reflected in the code.

Strangely, mainstream languages still suck at providing tools for good error handling. The main issues I see are: 

- Not differentiating between bugs and recoverable errors (more on that later).
- Increasing the [cognitive load](https://minds.md/zakirullin/cognitive) unnecessarily.
- Poor composability.
- Too restrictive type systems.

In this article, I go about main approaches to error handling, argue about their strengths and weaknesses. I don't claim to know the best approach but I believe that trying to understand the current situation is necessary to build better mechanisms in the future.

## Bugs and Recoverable Errors

When we say "error", we actually possibly mean one of the two things:

1. A bug in the system.
2. A faulty situation that can't be avoided.

These two things are [fundamentally different](https://joeduffyblog.com/2016/02/07/the-error-model/#bugs-arent-recoverable-errors). However, many programming languages don't make a clear differentiation between the two when they are designing their error model. This causes complications because they are very different in nature. When one tries to deal with two very different things with the same tools the tool becomes unnecessarily complex. Instead it would be better two build two separate tools that solve each of them well.

Bugs cause your system to go into a unanticipated state. Because you didn't actually think that this case would happen in reality and your whole design is based on that assumption. Naturally this means that all your previous assumptions are not true anymore. Invariants may be violated or state may be corrupted. 

A recoverable error on the other hand, are the things that may happen and usually it's outside of the control of the system. The system has to interact with the outside world and outside world is a lot of the times unpredictible. Therefore, the system should have a way to handle these errors. A download manage should retry when a network error occurs, a text editor should not crash if it  fails to save.

If the system continues to operate in the face of a bug, it will likely to start behaving in weird ways. There is no proper way to "handle" a bug other immediately stopping and reporting it. That's why "did you turn it on and off again?" is such a popular thing with computer. By restarting a system, we reset the state and it goes back to a case which doesn't break our assumptions about the system. We did't actually solve the issue, it's still possible to go into the undesired state.

But you can be saying "If I kill my application everytime there was a division by zero or null pointer dereference it would restart every second". I don't imply that you should restart all your system when a bug occurs. But you should reset _all the affected components_. If two threads share a memory region and one encounters a bug, the second is also potentially buggy. You need to reset both. We have problems with restarting only because we can't easily restart a granular part of a system. If components are properly isolated, restarting a process in the face of a bug doesn't bring down the whole system and this prevents cascading failures in the downstream. You end up with a more reliable system. Also one of the issues with just continuing in the face of a bug, it makes it _easier to not to fix the bug than to fix the bug_. This leads to a [Pit of Despair](https://blog.codinghorror.com/falling-into-the-pit-of-success/) where you ironically end up with a less reliable system that always runs but not it's not certain that it's actually in a well defined state. 

I believe Java and C++ especially made significant harms into the culture of error handling because they don't clearly separate bugs and recoverable errors. A `NullPointerException` is handled the same way an `IOException` is handled. This blurs the line and makes it harder to notice the fundamental differences. Also Java doesn't provide a functionality like Rust's `unwrap` to ignore error cases for dirty hacking. Which makes people to hate checked exceptions. C++ has similar problems but I won't go into detail here.

When we try to deal with both bugs and recoverable errors in the same way, error handling sucks more than necessary.

## The Philosophy of Error Handling

As far as I know, there are two main philosophical approaches to error handling. First one acknowledges that error handling is too hard and complex to manage it in a type system. Therefore they either use special error values or runtime exceptions. There are further divisions in this camp (like Go's approach vs. Java's runtime exception approach) but I won't go into detail about them. All of those subcamps has the same belief that it's not worth encoding errors into the types.

The other camp believes that error handling is complex, but it can be somewhat tracked in the type system even if it's not possible for every case. They think that many trivial errors (like famous `NullPointerException`) could be prevented with encoding more information into type system.

My stance on this is nuanced. First approach has it's use. Many times we want to write a hacky proptotype before we actuall want to write a proper system. Then we can save a lot of time by deferring error handling. But when it comes to seriously building a system, it shouldn't be hard to become stricter with error handling. It should be easy to spot where we are not dealing with a possible error so that we can build reliable and robust systems. That's why I especially find Rust's approach really good. Because if you are doing hacky prototype you can just `unwrap` errors and let the program panic if an error happens. When you are back you can rewrite your code to handle these errors. It's very easy to figure out where you should look.

## Error handling approaches in mainstream languages

- Brief description. Maybe reference other posts.
- Why they suck.

### Special Values

This approach essentially uses some values of a type to have special meanings. For example, [open](https://www.man7.org/linux/man-pages/man2/open.2.html#RETURN_VALUE) syscall in Linux returns an integer. This integer is normally the file descriptor, but on error it has a special value `-1`. It purely relies on convention that users will check the return value before using it so they don't use `-1` as a valid file descriptor. Some languages that use this approach are: C, C++ and Go. Java also uses it in some of it's APIs since in a lot of cases `null` is returned when the desired object does not exist for some reason.

This approach has couple advantages. First, it's easy to implement because it requires literally zero language support. It can be achieved purely by using existing language constructs. Another advantage is that it's easy to understand: if you have a special value then it's an error, otherwise it's not. It's a simple if-else check.

However, there are serious disadvantages as well. Most pressing issue is simply relying on human convention and putting all burden to the users. Users must memorize all the special values they use or they need to constantly check the documentation which slows them down. Also it's possible that documentation is not clear on which values are special or worse it's not even documented! 

Another problem is that it's not possible to be sure that a value is already checked or not. You can say that "Why? If the checks are passed, then surely it's a valid value after". This is true when you have no functions and all code is in one place. But what if you write a function? How do you enforce that user doesn't pass an invalid value if you only want to operate on valid values? The answer is that you can't. You acknowledge that you can't prevent from user from passing invalid values, thus you need to write [defensive checks](https://en.wikipedia.org/wiki/Defensive_programming). This leads to duplicate checks and a lot of boilerplate code. Also it creates unnecessary maintenance burden for the extra cases you have to deal with. 

The last problem is that when you change the code so that some assumptions about a variable changes, you need to mentally propagate new conditions into rest of the code. As with everything that relies on people it's error prone and causes unnecessary mental load. When you do a mistake during propagation you end up with new bugs that you are not aware. For example, you check a variable is valid, then perform some operation on it. But later if you add a code that mutates that variable in between, you will probably forget to check it after the mutation. It is easy to do this mistake when there are many variables involved or there are deep call chains.

The drawbacks are obvious in [open](https://www.man7.org/linux/man-pages/man2/open.2.html#RETURN_VALUE). Whenever you take a file descriptor as an argument you have to consider the case that passed file descriptor is not actually valid. User may have forgotten to check if file descriptor is not equal to `-1`. And there is no way to restrict the argument type into _only valid_ file descriptor values. This causes a lot of unnecessary lines of codes when you want to just operate on valid values. Which causes more maintenance burden and also more tests. Debugging is difficult because the information is very little and it's not possible to detect where did the error originate.

Because of the drawbacks, this approach is very unpopular these days at least in the form that appears in C. Go's error handling is very similar though it doesn't use special values and instead returns an additional value for error. Arguably languages like Rust, Haskell also use this method since they also encode error into return types. Though it has significant changes I consider them a separate class of error handling.

### Exceptions

In this approach functions return values when no error occurs, but exceptions are thrown when an error occurs. Throwing an exception immediately stops any further execution of the current block and pops the call stack until a suitable exception handler is found. When a suitable handler is found the program continues from there. 

An example is [Files.copy](https://docs.oracle.com/javase/8/docs/api/java/nio/file/Files.html#copy-java.io.InputStream-java.nio.file.Path-java.nio.file.CopyOption...-) method from Java. When there are no errors, it simply returns the number of bytes copied, otherwise it throws `IOException` which means some I/O error has occured. In this case user need to handle the error using `try/catch` or it's automatically "bubbled up" until there is a `catch` statement that accepts an `IOException`.

Exceptions approach is divided into _checked_ and _unechecked_ exceptions. The main difference is that checked exceptions require that any exception is either handled or specified in the function signature. Unchecked exceptions, as the name suggests, don't require it.

## Unchecked Exceptions

TODO: Invisible contrpl flow

Exceptions I believe are only suitable for very limited cases. They work nicely when you just want to propagate error up in the call stack to log it and move on like in an HTTP server. But for instance they are awkward for errors that you want to check right after the call since you have to wrap it with `try/catch`. Also it simply doesn't work if want to compose errors and treat them as first class values. For instance if you are writing a parser and want to report all the syntax errors at once, you can't implement this with exceptions, since once a `throw` occurs the execution is interrupted and you can't go back.

A specific problem of unchecked exceptions is that every function you don't know the implementation is _potentially throwing_. This means everything can always be interruped, including when you are trying handle an error! This causes a lot boilerplate code and causes unnecessary cognitive load. This problem is aggravated in Java due to many APIs throwing `NullPointerException` and `IllegalArgumentException` all over the place.

Checked exceptions are very limited in practice. There are many famous criticisms. I would suggest to read them if you are curious [^2], TODO. But in short it leaks out implementation details and don't compose.

TODO

### Monadic Errors

## Proposed approach

- composability
- Compile time checking
- Techniques 
    - Structural type systems
- Weaknesses
- the reasons why mainstream languages still don't have them. 

[^1]: https://engineering.fb.com/2022/11/22/developer-tools/meta-java-nullsafe/

[^2]: https://www.artima.com/articles/the-trouble-with-checked-exceptions