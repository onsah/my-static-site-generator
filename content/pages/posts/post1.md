Hello world! This is my first blog post.

For a while I wanted to start blogging about programming and writing my own blog engine seemed like a good idea to keep it interesting.
While keeping me interested part working as intended, I think I could have published my first post a lot more earlier if I used an existing blog engine. But it's like scripting, doing a task manually sometimes shorter than writing a script for it, but programmers still choose scripting. Also I like the idea of being familiar with the every stack of my projects. Nowadays, it's rare to work without frameworks or libraries that abstract over the basic primitives (not that this a bad thing) especially in the web development setting. I thought it would be interesting if I learned web frontend fundamentals from scratch.

## Why OCaml?

I am aware that there are a lot of blog posts about writing a blog engine, but I didn't see anyone using OCaml. 
I chose OCaml because it seems close to the ideal language in my mind. I really like Rust, and OCaml is similar to Rust in many aspects such as having good support for functional programming while allowing to escape into imperative style when necessary. 
But OCaml has garbage collector instead of lifetime analysis so it's more convenient to use if you don't need to control memory management. And it has some interesting features like [modules](), [GADT]()s and [polymorphic variants](). Though I miss the guarantees provided by the ownership system.
I had some bugs while working on this project that would be catched by the borrow checker if it existed.
Promisingly, [there is a ongoing work]() to implement some sort of borrow checking for OCaml.

Another good thing about OCaml is that it's similar to [Go]() in the sense that it compiles fast and has a very minimal runtime.
That makes iterations very quick, and also deployment simple since it just requires a single binary.
Furthermore, while it produces very efficient binary executables it still feels like a scripting language thanks to it's type inference.
I could talk about OCaml's features more in detail, but this post is not about that so I will save this to a future article.
I wanted to try the language in a realistic setting to see how this language work in practice.

## Project Structure

[The project]() has two main folders:
* `content`: Blog content. Page templates and the blog posts.
* `site-generator`: OCaml program that generates the website.

`content` folder contains three subfolders:
* `templates`: Html templates for components and pages.
* `pages`: The content for pages such as 'about me' and blog posts. Each post has a metadata json file and a markdown file containing the actual content.
* `css`: As the name implies this contains the css files.

The static site generator generates a simple html website.
Basically, it takes each post content in markdown form and converts it to html. 
Then it instantiates the blog post template with the post content.

Site generator has the following properties:
* For the build system I chose [dune]() which is the de-facto build system for OCaml.
* Instead of the default standard library, I use [Core] because it contains more functionality and it was used in [Real World OCaml]() book that I read. 
* For html manipulation I use [Lambda soup]() library.
* The markdown files are converted to html using [omd]().
* The post metadata is stored in json files, to parse them I use [yojson](). Though I would prefer to have them as [YAML Front Matter](), I couldn't find a library for it and didn't want to spend time implementing myself. Maybe in the future I can work on that.

Unfortunately while OCaml ecosystem is active it's nowhere near the more mainstream languages in terms of library support.
You may be dissapointed if you expect to find a library for everything.

## Templating
The templating functionality is very simple, it basically finds the appropriate element with the element id than replaces it with the actual content. For example, in posts page:
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
The unexpected thing was, it also mutates _the component that is substitued_ as well, leaving it empty after the operation.
I was expecting that the second argument left unmodified.
It's a good example why borrow checking is useful, if OCaml had borrow checking I would know that the second argument is mutated by looking at the signature and didn't have this surprise. 
An immutable API would also prevent such mistakes.

## Modules

OCaml have a concept called [Modules]() which can be used as a substitute for [Interfaces](). 
I find module system in general better than classic OO-style interfaces.
One reason is that a module can have multiple related types defined together and not necessarily tied into a single type.
Though for this project, there were no cases where I really needed a module. 
All of my modules signatures in the project resembles interfaces.

## Conclusion

In short, I liked my experience with OCaml though since this project is very simple it wouldn't matter if I used any
other reasonable language.
Unfortunately, some libraries are not well maintained and lacks documentation
but tooling is very straightforward and easy to use.
But it's very much an alive ecosystem with a lot of efforts to improve the language.

