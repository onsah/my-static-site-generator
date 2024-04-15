Hello world, this is my first blog post.

For a while I wanted to start blogging about programming and writing my own blog engine seemed like a good idea to keep it interesting.
While keeping me interested part working as intended, I think I could have published my first post a lot more earlier if I used an existing blog engine. But it's like scripting, doing a task manually sometimes shorter than writing a script for it, but some people do it anyway because manual labor is boring. Also I like doing things from scratch since it forces me to learn about fundamentals. Nowadays, it's rare to work without frameworks or libraries that abstract over the basic primitives (not that this a bad thing) especially in the web development setting so I thought it would be a good opportunity.

## Why OCaml?

I am aware that there are a lot of blog posts about writing a blog engine, but I use OCaml which is not a popular choice among such posts. 
I chose OCaml because it seems close to the ideal language in my mind. I really like Rust, and OCaml is similar to Rust in many aspects such as having good support for functional programming while allowing to escape into imperative style when necessary. 
But OCaml has garbage collector instead of compile time lifetime checking so it's more convenient to use if you can afford to use a garbage collector. And it has some interesting features like [modules](), [GADT]()s and [polymorphic variants](). 
I miss borrow checking from Rust especially when I use mutation. 
I had some bugs while working on this project that would be catched by the borrow checker if it existed.
But [there is a ongoing work]() to implement some sort of borrow checking for OCaml.
I could talk about OCaml's features more in detail, but this post is not about that so I will save this to a future article.
I wanted to try the language in a realistic setting to see how these concepts work in practice.

## Project Structure

[The project]() has two main folders:
* `content`: Blog content. Page templates and the blog posts.
* `site-generator`: OCaml program that generates the website.

`content` folder contains three subfolders:
* `templates`: Html templates for components and pages.
* `pages`: The content for pages such as 'about me' and blog posts. Each post has a metadata json file and a markdown file containing the actual content.
* `css`: As the name implies this contains the css files.

The static site generator generates a simple html5 website.
Basically, it takes each post content in markdown form and converts it to html. 
Then it instantiates the blog post template with the post content.

The program uses [dune]() build system which seems to be the de-facto build system for OCaml.
Instead of the default standard library, I use [Core] because it contains more functionality and it was used in [Real World OCaml] book that I read. 
For html manipulation I use [Lambda soup]() library.
The markdown files are converted to html using [omd].
The post metadata is stored in json files, to parse them I use [yojson].

### Templating
The templating functionality is very simple, it basically find the appropriate element with the element id than replaces it with the actual content. For example, in posts page:
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
For the unexpected thing was, it also mutates the component that is substitued as well, leaving it empty after the operation.
I was expecting that the second argument leaves unmodified.
It's a good example why borrow checking is useful, if OCaml had borrow checking I would know that the second argument is modified by looking at the signature.

