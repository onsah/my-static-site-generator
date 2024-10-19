[Nix Channels](https://zero-to-nix.com/concepts/channels) is probably one of the most controversial parts of the [Nix](https://wiki.nixos.org/wiki/Nix_package_manager). While Nix claims to be fully reproducible, Nix [derivations](https://wiki.nixos.org/wiki/Derivations) implicitly refer to a [nixpkgs](https://wiki.nixos.org/wiki/Nixpkgs) usually through a channel. This breaks the reproducibility promise because the version of nixpkgs depends on the environment that the derivation is built.

One popular alternative for the traditional Nix derivations is to use flakes. There are even efforts to [stabilize them for a long time](https://discourse.nixos.org/t/an-incremental-strategy-for-stabilizing-flakes/16323). However, they are a whole new approach and require some learning for a traditional Nix user. Moreover, they are still experimental so the API is subject to change in the future.

In this post I will show how you can get rid of channels but still use the traditional nix derivations and pin your nixpkgs for your derivations, [shells](https://wiki.nixos.org/wiki/Development_environment_with_nix-shell), [NixOS configuration](https://nix.dev/tutorials/nix-language.html#nixos-configuration) and [home manager configurations](https://nix-community.github.io/home-manager/index.xhtml#sec-usage-configuration). In the end you will end up with a setting where nixpkgs version is managed via plain text and can easily be updated when desired.

## The Problem
Conventional nix shells contain code snippet similar to the following:
```nix
let pkgs = import <nixpkgs> {}; in
pkgs.mkShell {
  # ...
}
```

You may wonder, what does `<nixpkgs>` mean in this code?. This syntax is called "lookup path"[^1]. When you write a name in angle brackets, it's matched with the corresponding key-value pair in `NIX_PATH` environment variable. The value is typically a Nix channel.

Nix Channels are essentially URLs that point to a nixpkgs[^2]. Conventionally there are certain channels which are listed [here](https://status.nixos.org/). The exact contents of a channel are updated regularly. So they act like package indices which can be found in other traditional package managers. Having a package index has several benefits. First, they allow conveniently updating all installed packages like one does in traditional package managers. Furthermore, having a global version of a dependency is also beneficial for caching purposes, because packages we use that may depend on the same package depend on the same version, so we don't end up with many versions of the dependency with slight differences.

But of course it's not all good. First problem is, having a global version for every dependency makes it hard if we really want multiple different versions of the same package. For example it's not uncommon that one wants multiple versions of JDK installed at the same time. For this, nixpkgs have conventions that exposes several different major versions (for example JDK has many versions such as [jdk8](https://search.nixos.org/packages?channel=unstable&show=jdk8&from=0&size=50&sort=relevance&type=packages&query=jdk) and [jdk17](https://search.nixos.org/packages?channel=unstable&show=jdk17&from=0&size=50&sort=relevance&type=packages&query=jdk)) which solves this issue for many cases but it's still sometimes not enough. Second problem is exact version of the nixpkgs is not specified in the Nix derivation. If someone tries to build your Nix Derivation couple years later it may not build because the channel is updated with breaking changes. This is a really bad UX, because a channel url says nothing about actual version of nixpkgs being returned. For example, if `NIX_PATH` environment variable is set to `nixpkgs-unstable=nixos-24.05`, `<nixpkgs-unstable>` will refer to the NixOS 24.05 stable branch! This can be very unintuitive. Or worse, many use `<nixpkgs>` channel for their default channel but some set it to a stable and others to an unstable channel. Reader has no idea which version `<nixpkgs>` is meant to refer. Also, the exact contents of the channel url changes over time which means that the derivation may get broken in the future.

We can't really fix the first problem with the traditional Nix. I believe that it's an inherent trade-off between space usage and preciseness. But fortunately we can solve the second problem. Therefore ensuring reproducibility and improving the UX.

In order to fix this issue, we have the following options:
1. Don't use `<nixpkgs>` expressions in the code.
2. Keep `<nixpkgs>` but change `NIX_PATH` variable to refer to a specific version of nixpkgs instead of a channel.

We will use both options depending on the use case. But first we need to introduce a new tool.

## First Attempt at a Solution
As I have described above, the problematic line is:
```nix
let pkgs = import <nixpkgs> {}; in
```

We already know that `<nixpkgs>` is supposed return a version of nixpkgs. So one simple solution could be to download a specific commit of nixpkgs instead of using channels via lookup paths. Is this possible?

Yes, fortunately it is possible. The nixpkgs repository is [hosted at GitHub](https://github.com/NixOS/nixpkgs). GitHub has a nice feature that allowing [downloading the source archive of any commit](https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives#source-code-archive-urls). Nix has a builtin called [fetchTarball](https://nix.dev/manual/nix/2.18/language/builtins.html?#builtins-fetchTarball) which, as the name suggests, downloads the tarball and returns it's Nix store path. With this knowledge, we can instead write:
```nix
let pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/$COMMIT_HASH.tar.gz") {}; in
```

This solves the reproducibility issue. So can we know stop and be happy?

Unfortunately not, we have achieved perfect reproducibility. However, how do we update nixpkgs version if we want to? Our current option is to go to nixpkgs repository and pick the latest commit then copy-paste it. But if we have a lot of shell configurations this can easily get very tedious. Can we automate the process a bit?

Well we can. Enter npins.

## Npins
[Npins](https://github.com/andir/npins) is a tool that allows "pinning" a specific commit of the nixpkgs in nix derivations. The version is stored in a text file, therefore you can easily add it to version control. It also lets you conveniently update the version when you want, no manual text editing is required. It's [available in nixpkgs](https://search.nixos.org/packages?channel=24.05&show=npins&from=0&size=50&sort=relevance&type=packages&query=npins).

Once you have it installed, you need to initialize it in the directory you want to use:
```bash
npins init --bare
```
This will create `npins` subdirectory on the current directory. Initially there are no pinned nixpkgs and it needs to be added with another command.

Adding nixpkgs can be done with:
```bash
npins add github nixos $NIXPKGS_NAME --branch $NIXPKGS_BRANCH
```
Where `$NIXPKGS_BRANCH` can be a [Nix Channel](https://wiki.nixos.org/wiki/Channel_branches) name. `$NIXPKGS_NAME` is the name of nixpkgs. This is necessary because npins lets you pin multiple nixpkgs in the same repository.

After having nixpkgs pinned, it can be used in nix derivations as following:
```nix
{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
in
...
```
`sources` contains the pinned nixpkgs, the name you gave above becomes an attribute in `sources` to access. So if you have the name `foo`, you would get nixpks by `import sources.foo {}`.

## Packaging & Shell
As shown above, nix shell configurations utilize `<nixpkgs>` syntax, which is the main deal breaker for reproducibility. Therefore the solution is to import nixpkgs from `sources` provided via npins.

I use the following template:
- `nix/shell.nix` : Contains the actual shell configuration which should be built with [callPackage](https://nix.dev/tutorials/callpackage.html). Example:
```nix
{
  mkShell,
  # Other dependencies...
}:

mkShell {
  # Shell configuration...
}
```
- `shell.nix` : Calls `nix/shell.nix` with the pinned nixpkgs. For example if we have nixpkgs with name `nixpkgs`:
```nix
{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
in
pkgs.callPackage ./nix/shell.nix {}
```

### Bonus: direnv
For convenience I use [direnv](https://direnv.net/) to enter `nix-shell`. It's convenient because it automatically enters into the environment and it's for some reason faster than calling `nix-shell` directly.

With `direnv` installed, I have the following `.envrc` file:
```direnv
use nix
```
Which is all we need.

## NixOS configuration
It's harder to pin nixpkgs for NixOS configurations, because NixOS configurations implicitly depend on `<nixpkgs/nixos>`, and because it's a lookup path, it requires `NIX_PATH` environment variable to point to `nixpkgs`. It kind of creates a loop if you want to declare `NIX_PATH` inside `configuration.nix`, because in order to interpret `configuration.nix` you first need to determine the location of `nixpkgs` which is only available after `NIX_PATH` is set. So this way of managing requires to run `nixos-rebuild` **twice** to actually take effect. I think this is not a good UX. Fortunately, we can use write a script that passes the appropriate `NIX_PATH` to `nixos-rebuild`. In order to prevent incorrect usage, `NIX_PATH` shouldn't be empty by default.

I use the following [Nu Shell](https://www.nushell.sh/) script for this:
```nu
def build-nixos-configuration [
  device_path: string, # Path for the system configuration. Must contain a 'configuration.nix' and an 'npins' directory.
  command: string = "switch", # Main command for 'nixos-rebuild'. 'switch' or 'dry-run'
  ...extra_args: string, # Passed to 'nixos-rebuild'
]: nothing -> nothing {
  let abs_device_path = ($device_path | path expand --strict);

  let npins_path = ($abs_device_path | path join npins default.nix);
  let nixpkgs_pin = run-external "nix" "eval" "--raw" "-f" $npins_path "nixpkgs";

  let configuration_path = ($abs_device_path | path join configuration.nix);

  let nix_path = $"nixpkgs=($nixpkgs_pin):nixos-config=($configuration_path)";
  with-env {
    NIX_PATH: $nix_path,
  } {
    # For some reason '--preserve-env=NIX_PATH' doesn't pass the env variable.
    sudo "--preserve-env" "-u" $"(whoami)" "nixos-rebuild" $command "--fast" ...$extra_args
  }
}
```

It may seem complicated, but the essential part is very simple:
```nu
let nixpkgs_pin = run-external "nix" "eval" "--raw" "-f" $npins_path "nixpkgs";
let nix_path = $"nixpkgs=($nixpkgs_pin):nixos-config=($configuration_path)";
with-env {
  NIX_PATH: $nix_path,
} {
  sudo "--preserve-env" "-u" $"(whoami)" "nixos-rebuild" $command "--fast" ...$extra_args
}
```
1. First line evaluates the nixpkgs and returns a [Nix Store](https://wiki.nixos.org/wiki/Nix_package_manager#Nix_store) path.
2. Second line creates the appropriate `NIX_PATH` env variables. `nixpkgs` is a path to nixpkgs and `nixos-config` is the path to `configuration.nix`.
3. Sixth line calls `nixos-rebuild` with appropriate arguments.

The same part can be written is bash as (disclaimer: I didn't test it):
```bash
NIXPKGS_PIN=$(nix eval --raw -f $NPINS_PATH nixpkgs)
NIX_PATH="nixpkgs=$NIXPKGS_PIN:nixos-config=$CONFIGURATION_PATH"
sudo --preserve-env -u "$(whoami)" nixos-rebuild $command --fast $@
```

With a script like this, one can pin nixpkgs for their system configuration.

## Home Manager
If you use [Home Manager](https://nix-community.github.io/home-manager/) the approach is very close to the system configuration. It's essentially the same, except in `NIX_PATH` you don't need to set `nixos-config` but you need `home-manager`:

```bash
NIXPKGS_PIN=$(nix eval --raw -f $NPINS_PATH nixpkgs)
HOME_MANAGER_PIN=$(nix eval --raw -f $NPINS_PATH home-manager)
NIX_PATH="nixpkgs=$NIXPKGS_PIN:home-manager=$HOME_MANAGER_PIN"
home-manager $command -f $HOME_MANAGER_PATH
```

## Conlusion
If you have come this far, thank you for giving your time. I believe that traditional Nix does many things right, but the way nixpkgs is managed really needs to change. With pinning nixpkgs using `npins` you can improve this one specific issue.

Credits: This post is heavily inspired by [https://jade.fyi/blog/pinning-nixos-with-npins/](https://jade.fyi/blog/pinning-nixos-with-npins/). If you want more deep dive explanation on the same topic I would recommend it.

[^1]: https://nix.dev/tutorials/nix-language#lookup-path-tutorial
[^2]: https://zero-to-nix.com/concepts/channels