Hello world! This is my first blog post.

For a while, I wanted to start blogging about programming, and writing my own blog engine seemed like a good idea to keep it interesting.
While keeping me interested in working as intended, I think I could have published my first post much earlier if I used an existing blog engine. But it's like scripting, doing a task manually sometimes shorter than writing a script for it, but programmers still choose scripting. Also, I like the idea of being familiar with every stack of my projects. Nowadays, it's rare to work without frameworks or libraries that abstract over the basic primitives (not that this is a bad thing), especially in the web development setting. I thought it would be interesting if I learned web frontend fundamentals from scratch. Thanks to [Uğur](https://www.rugu.dev) for helping me with HTML/CSS.

If you would like to check out the source code, the repository is [here](https://github.com/onsah/my-static-site-generator).

## Why OCaml?

I am aware that there are a lot of blog posts about writing a blog engine, but I didn't see anyone using OCaml. 
I chose OCaml because it seems close to the ideal language in my mind. I really like Rust, and OCaml is similar to Rust in many aspects such as having good support for functional programming while allowing to escape into imperative style when necessary. 
But OCaml has a garbage collector instead of lifetime analysis so it's more convenient to use if you don't need to control memory management. And it has some interesting features like [modules](https://ocaml.org/docs/modules), [GADT](https://dev.realworldocaml.org/gadts.html)s and [polymorphic variants](https://ocaml.org/manual/5.2/polyvariant.html). However, I miss the guarantees provided by the ownership system.
I had some bugs while working on this project that would be caught by the borrow checker if it existed.
Promisingly, [there is an ongoing work](https://blog.janestreet.com/oxidizing-ocaml-ownership/) to implement some sort of borrow checking for OCaml.

Another good thing about OCaml is that its similar to [Go](https://go.dev/) in the sense that it compiles fast and has a very minimal runtime.
That makes iterations very quick, and also deployment simple since it just requires a single binary.
Furthermore, while it produces very efficient binary executables it still feels like a scripting language thanks to it's type inference.
I could talk about OCaml's features more in detail, but this post is not about that so I will save this to a future article.
I wanted to try the language in a realistic setting to see how this language works in practice.

## Project Structure

[The project](https://github.com/onsah/my-static-site-generator) has two main folders:
* `content`: Blog content. Page templates and blog posts.
* `site-generator`: OCaml program that generates the website.

`content` folder contains three subfolders:
* `templates`: HTML templates for components and pages.
* `pages`: The content for pages such as 'about me' and blog posts. For each post, there is a `.json` file (metadata) and a `.md` (content) with the same name before the extension.
* `css`: As the name implies this contains the css files.

The static site generator generates a static HTML website.
Basically, it takes each post's content in markdown form and converts it to HTML.
Then it instantiates the blog post template with the post content.

### Tech Stack
I use the following tech stack:
* For the build system I chose [dune](https://dune.build/) which is the de-facto build system for OCaml.
* Instead of the default standard library, I use [Core](https://opensource.janestreet.com/core/) because it contains more functionality and it was used in [Real World OCaml](https://dev.realworldocaml.org/) book that I read. 
* For HTML manipulation I use [Lambda soup](https://ocaml.org/p/lambdasoup/latest) library.
* The markdown files are converted to HTML using [omd](https://ocaml.org/p/omd/latest).
* The post metadata is stored in json files, to parse them I use [yojson](https://ocaml.org/p/yojson/latest). Though I would prefer to have them as [YAML Front Matter](https://jekyllrb.com/docs/front-matter/), I couldn't find a library for it and didn't want to spend time implementing myself. Maybe in the future, I can work on that.
* CLI interface is implemented using [core_unix](https://ocaml.org/p/core_unix/latest/doc/index.html).

Unfortunately, while OCaml ecosystem is active it's worse than mainstream languages in terms of library support.
You may be disappointed if you expect to find a library for everything.

### Code Structure
The project is mainly organized by [Modules](#modules).
* `main`: Programs entry point.
* `DiskIO`: Wraps the disk related functionality so the underlying IO library can be changed easily. All actual IO functionality is constrained here.
* `SiteGenerator`: Reads the content and generates the website files but doesn't actually write them.
* `SiteDirectory`: Writes generated website files into the disk.

## Templating
The templating functionality is very simple, it basically finds the appropriate element with the element id and then replaces it with the actual content. For example, in posts page:
```html
<main class="container">
    <!-- ... -->
    <div id="blog-content"></p>
</main>
```

The `blog-content` is substituted with actual content with the following code:
```ocaml
let page =
    DiskIO.read_all
        (Path.join content_path (Path.from_parts [ "templates"; "post.html" ]))
    |> Soup.parse
in
Soup.replace (page $ "#blog-content") post_component;
```

Notice that `Soup.replace` API has side effects, it doesn't return the modified page but updates the target **in place**.
The unexpected thing was, it also mutates _the component that is substituted_ as well, leaving it empty after the operation.
I was expecting that the second argument left unmodified.
It's a good example why borrow checking is useful, if OCaml had borrow checking I would know that the second argument is mutated by looking at the signature and didn't have this surprise.
An immutable API would also prevent such mistakes.

## Modules

OCaml has a concept called [modules](https://ocaml.org/docs/modules) which can be used as a substitute for [interfaces](https://docs.oracle.com/javase/tutorial/java/IandI/createinterface.html) in other languages.
I find the module system in general better than classic OO-style interfaces.
One reason is that a module can have multiple related types defined together and not necessarily tied into a single type.
Though for this project, there were no cases where I really needed a module.
All of my modules signatures in the project resembles interfaces.

## Conclusion

In short, I liked my experience with OCaml though since this project is very simple it wouldn't matter if I used any
other reasonable language.
Unfortunately, some libraries are not well maintained and lack documentation
but tooling is very straightforward and easy to use.
But it's very much an alive ecosystem with a lot of efforts to improve the language.

