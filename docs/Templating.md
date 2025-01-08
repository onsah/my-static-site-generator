# Templating

Files under `templates` folder it instantiated for tempating. The language of templating is defined in [here](./Templating%20Engine.md).

## Context

The context provided to the template is derived from the content in `pages` directory. The directory is automatically turned into a context object where keys are the filenames before the extension or the directory name.

Files are converted into an object with `content` field set if a Markdown file exists by that name and other fields populated from the Json file with the same name if exists.

Directories are converted into a list object where the items are recursivly created in the same way as described.

### Page property
A special `page` property is set to an object if either a Markdown or a Json file with the same name of the template appears under `pages` directory. 

