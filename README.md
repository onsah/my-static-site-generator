
## Project Structure

```
.
├── content : HTML templates and blog posts.
├── docs : Documentation.
├── scripts : Scripts.
└── site-generator : The code for the site generator.
    ├── bin : The executable that wraps the library module.
    └── lib : Actual site generator functionality.
```

## Generating the Website

```shell
make generate
```

Resulting website is in `result/dist`.

## Locally serving the website

It's best to locally serve the website to get the best impression on how it will look when deployed.

```shell
make serve
```

It will automatically generate the website before serving. You can find the url to access in the command output.

## Deploying

```shell
make deploy ip=$SERVER_IP
```

## Credits

- Code highlighting: https://highlightjs.org/
