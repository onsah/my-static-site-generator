[Nix Channels]() is probably one of the most controversial parts of the [Nix](). While Nix claims to be fully reproducible, usually non [Flake]() Nix derivations implicitly refers to a [nixpkgs]() usually through a channel. This breaks the reproducibility promise because the version of nixpkgs depends on the environment that the derivation is being built.

In this post I will show how you can get rid of channels and pin your nixpkgs for your derivations, [shells](), [NixOS configuration]() and [home manager configurations]().

## Nix Channel Background
Nix Channels are essentially URLs that point to a nixpkgs[^1]. Conventionally there are certain channels which are listed [here](https://status.nixos.org/). They are like package indexes in other package managers like [dnf]() and [apt](). So essentially they allow conveniently updating all installed packages like one does in traditional package managers. Furthermore, having a global version of a dependency is also beneficial for caching purposes, because packages we use that may depend on the same package depend on the same version, so we don't end up with many versions of the dependency with slight differences.

But of course it's not all good. First problem is, having a global version for every dependency makes it hard if we really want multiple different versions of the same package. For example it's not uncommon that one wants multiple versions of JDK installed at the same time. For this, nixpkgs have conventions that exposes several different major versions (for example JDK has many versions such as [jdk8](https://search.nixos.org/packages?channel=unstable&show=jdk8&from=0&size=50&sort=relevance&type=packages&query=jdk) and [jdk17](https://search.nixos.org/packages?channel=unstable&show=jdk17&from=0&size=50&sort=relevance&type=packages&query=jdk)) which solves this issue for many cases but it's still sometimes annoying. Second problem is exact version of the nixpkgs that is used is not specified in the [derivation](). If someone tries to build your Nix Derivation couple years later it may not build because the channel is updated with breaking changes.

We can't really fix the first problem with the traditional Nix. I believe that it's an inherent trade-off between space usage and preciseness. But fortunately we can solve the second problem using [npins]() to pin nixpkgs we want to use. Therefore ensuring reproducibility and improving the UX.

## Npins
Npins is a tool that allows "pinning" to a snapshot of the nixpkgs. The version is stored in a text file, therefore you can easily add it to version control. It also lets you conveniently update the version when you want, no manual text editing is required. It's available in nixpkgs with the name [npins](https://search.nixos.org/packages?channel=24.05&show=npins&from=0&size=50&sort=relevance&type=packages&query=npins).

Once you have it installed, you need to initialize it in the directory you want to use:
```bash
npins init --bare
```
This will create `npins` subdirectory on the current directory. Initially there are no pinned nixpkgs and it needs to be added with another command.

Adding nixpkgs can be done with:
```bash
npins add github nixos $NIXPKGS_NAME --branch $NIXPKGS_BRANCH
```
Where `$NIXPKGS_BRANCH` can be a [Nix Channel](https://wiki.nixos.org/wiki/Channel_branches) name. `$NIXPKGS_NAME` is the name of nixpkgs. This is necessary because npins lets you pin multiple nixpkgs in the same repository, so you need to give them names.

After having nixpkgs pinned, it can be used in nix derivations as:
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
One good use case for npins is pinning the nixpkgs for [Nix Shell](). So a new user can just pull the project and enter into the appropriate environment without worrying about having the correct version of nixpkgs.

I use the following pattern:
- `nix/shell.nix` : Contains the actual shell configuration which should be built with [callPackage](). Example:
```nix
{
  mkShell,
  # Other dependencies...
}:

mkShell {
  # Shell configuration...
}
```
- `shell.nix` : Calls `nix/shell.nix` with the pinned nixpkgs. For example if we have pinned nixpkgs with name `nixpkgs`:
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
For convenience I use [direnv]() to enter `nix-shell`. It's convenient because it automatically enters into the environment and it's for some reason faster than calling `nix-shell` directly.

With `direnv` installed, I have the following `.envrc` file:
```direnv
use nix
```
Which is all I need.

## NixOS configuration
NixOS system configuration depends on `NIX_PATH` environment variable to point to `nixpkgs`, which is then used to interpret `configuration.nix` file. It kind of creates a loop if you want to declare `NIX_PATH` inside `configuration.nix` because in order to interpret `configuration.nix` you first need to determine the location of `nixpkgs` which is only available after `NIX_PATH` is set. So this way of managing requires to run `nixos-rebuild` twice to actually take effect. I think this is not a good UX. Fortunately, we can use write a script that passes the appropriate `NIX_PATH` to `nixos-rebuild`. In order to prevent incorrect usage, `NIX_PATH` shouldn't be set by default.

I use the following [Nu]() script for this:
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
1. First line evaluates the nixpkgs and returns a [Nix Store]() path.
2. Second line creates the appropriate `NIX_PATH` env variables. `nixpkgs` is a path to nixpkgs and `nixos-config` is the path to `configuration.nix`.
3. Sixth line calls `nixos-rebuild` with appropriate arguments.

The same part can be written is bash as (disclaimer: I didn''t test this):
```bash
NIXPKGS_PIN=$(nix eval --raw -f $NPINS_PATH nixpkgs)
NIX_PATH="nixpkgs=$NIXPKGS_PIN:nixos-config=$CONFIGURATION_PATH"
sudo --preserve-env -u "$(whoami)" nixos-rebuild $command --fast $@
```

With a script like this, one can pin nixpkgs for their system configuration.

## Home Manager
If you use [Home Manager]() the approach is very close to the system configuration. It's essentially the same, except in `NIX_PATH` you don't need to set `nixos-config`.

```bash
NIXPKGS_PIN=$(nix eval --raw -f $NPINS_PATH nixpkgs)
NIX_PATH="nixpkgs=$NIXPKGS_PIN"
home-manager $command -f $HOME_MANAGER_PATH
```

## Conlusion
If have come this far, thank you. Nix has very good experience overall, but also has some incredibly problematic parts in terms of UX. With pinning nixpkgs using `npins` you can improve this one specific issue.

Credits: This post is heavily inspired by https://jade.fyi/blog/pinning-nixos-with-npins/

[^1]: https://zero-to-nix.com/concepts/channels
