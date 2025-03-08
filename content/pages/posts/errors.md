
Proper error handling is hard. It's a concept since the inception of programming, yet solutions we have are hardly satisfying. When one tries to add proper error handling into their code it gets much more complicated than just implementing the happy path. Part of it is inescapable because it's [Essential Complexity]() but part of the complication is not necessary hence [Accidental Complexity](). A lot of production code either ignores errors or simply accumulate them to the top level with a generic error message. It's very rare that all possible error cases are even considered before implementation, let alone reflected in the code.

Strangely, mainstream languages still suck at providing tools for good error handling. The main issues I see are: 

- Not differentiating between bugs and recoverable errors (more on that later).
- Increasing the [cognitive load](https://minds.md/zakirullin/cognitive) unnecessarily.
- Poor composability.
- Too restrictive type systems.

In this article series, I will try to describe what "error" really means in programming context. Then I will go about mainstream approaches to error handling, argue about their strengths and weaknesses. I won't say anything novel or groundbreaking. It will be more like documentation of what we know about error handling. It's also to help myself to organize my thoughts about error handling.

## Bugs and Recoverable Errors

When we say "error", we actually possibly mean one of the two things:

1. A bug in the system.
2. A faulty situation that can't be avoided.

These two things are [fundamentally different](https://joeduffyblog.com/2016/02/07/the-error-model/#bugs-arent-recoverable-errors). However, many programming languages don't make a clear differentiation between the two when they are designing their error model. This causes complications because they are very different in nature. When one tries to deal with two very different things with the same tools the tool becomes unnecessarily complex. Instead it would be better two build two separate tools that solve each of them well.

Bugs cause your system to go into a unanticipated state. Because you didn't actually think that this case would happen in reality and your whole design is based on that assumption. Naturally this means that all your previous assumptions are not true anymore. Invariants may be violated or state may be corrupted. 

A recoverable error on the other hand, are the things that may happen and usually it's outside of the control of the system. The system has to interact with the outside world and outside world is a lot of the times unpredictible. Therefore, the system should have a way to handle these errors. A download manage should retry when a network error occurs, a text editor should not crash if it  fails to save.

If the system continues to operate in the face of a bug, it will likely to start behaving in weird ways. There is no proper way to "handle" a bug other immediately stopping and reporting it. That's why "did you turn it on and off again?" is such a popular thing with computer. By restarting a system, we reset the state and it goes back to a case which doesn't break our assumptions about the system. We did't actually solve the issue, it's still possible to go into the undesired state.

But you can be saying "If I kill my application everytime there was a division by zero or null pointer dereference it would restart every second". I don't imply that you should restart all your system when a bug occurs. But you should reset _all the affected components_. If two threads share a memory region and one encounters a bug, the second is also potentially buggy. You need to reset both. We have problems with restarting only because we can't easily restart a granular part of a system. If components are properly isolated, restarting a process in the face of a bug doesn't bring down the whole system and this prevents cascading failures in the downstream. You end up with a more reliable system. Also one of the issues with just continuing in the face of a bug, it makes it _easier to not to fix the bug than to fix the bug_. This leads to a [Pit of Despair](https://blog.codinghorror.com/falling-into-the-pit-of-success/) where you ironically end up with a less reliable system that always runs but not it's not certain that it's actually in a well defined state. 

I believe Java especially made significant harms into the understanding of error handling because they don't clearly separate bugs and recoverable errors. A `NullPointerException` is handled the same way an `IOException` is handled. This blurs the line and makes it harder to notice the fundamental differences. Also Java doesn't provide a functionality like Rust's `unwrap` to ignore error cases for dirty hacking. Which makes people to hate checked exceptions.

When we try to deal with both bugs and recoverable errors in the same way, error handling sucks more than necessary.

## The Philosophy of Error Handling

As far as I know, there are two main philosophical approaches to error handling. First one acknowledges that error handling is too hard and complex to manage it in a type system. Therefore they either use special error values or runtime exceptions. There are further divisions in this camp (like Go's approach vs. unchecked exception approach) but I won't go into detail about them. All of those subcamps has the same belief that it's not worth encoding errors into the types.

The other camp believes that error handling is complex, but it can be somewhat tracked in the type system even if it's not possible for every case. They think that many trivial errors (like famous `NullPointerException`) could be prevented with encoding more information into type system.

Both camps have their advantages and shortcomings. First approach is good when you want to focus on the happy path and reliability is not that important. Many times we want to write a hacky proptotype before we actually want to write a proper system. We can save a lot of time by just throwing the ball (such as terminating the program or whatever appropriate unit of execution) when a failure case occurs. But when it comes to seriously building a system, it shouldn't be hard to become stricter with error handling. It should be easy to spot where we are not dealing with a possible error so that we can build reliable and robust systems. That's why I especially find Rust's approach really good. Because if you are doing hacky prototype you can just `unwrap` errors and let the program panic if an error happens. When you return you can rewrite your code to handle these errors. It's very easy to figure out where you should look. Compared to this if you use Java for instance, any function can throw a runtime exception and there is no way of telling it from the signature. In order to be sure you have to read the whole implementation of the function. This is really bad because it causes unnecessary [Cognitive Load](https://minds.md/zakirullin/cognitive).

Second approach is good that it lets you abstract over failure modes by incorporating into type system. This way you can just look at the signature and not have to read the implementation to see what errors are possible. It provides better abstraction and reduces [Cognitive Load](). However, in the way it's currently implemented in programming languages it's usually painful write. Particularly, it's hard or impossible to compose error cases from multiple functions or narrow cases by partially handling some of the errors. So composability suffers. I will talk about this in the next article when we discuss monadic errors.

## Conclusion

We reached the end of the first part in this series. I hope it helped you to understand the purpose of error handling and different approaches to it. In the next article, I will delve on different types of error handling models of mainstream programming languages and some cutting-edge ones. We will learn pros and cons of each approach.
