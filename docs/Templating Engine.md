# Templating Engine

This website uses a simple home grown template engine. It mostly follows https://shopify.github.io/liquid/.

## Language

A template is a valid HTML file with some strings in a special syntax.

### Item

An identifier between `{{` and `}}` is called a variable. It's replaced with the corresponding item in the context. Otherwise templating function gives a `PropertyNotFound` error.

An identifier is any string that matches with regex `[a-zA-Z][a-zA-Z0-9-_]*`. If an unexpected character is seen between `{{` and `}}`, `UnexpectedCharacter` error is returned. If `{{}}` is occured, `EmptyIdentifier` error is returned.

An item can be a string, an object, a HTML document or a list of items.

#### Example

If template:

```
<div>{{foo}}</div>
```

is called with context `{ "foo": "hello" }`, it returns:

```
<div>hello</div>
```

### Iteration

Iterates over a `Collection` type of item.

#### Example

```
{{foreach post in posts
    {{post.title}}
end}}
```

The body is duplicated for each item in `posts`.

## Important Notes

### HTML Items

When an item is of type `Html`, then it's first recursively instantiated with the same context and then inserted into the template it belongs.

