Recently I am working on a Scala backend as a side project. I decided to deploy it as a Docker image for portability reasons. My hosting provider supports running JARs, but I wanted something that I could host anywhere if I decided to move away. 

There are already articles about [generating Docker images for a Scala project](https://medium.com/@ievstrygul/dockerizing-scala-app-3fdf08cffda4) [even with Nix](https://zendesk.engineering/using-nix-to-develop-and-package-a-scala-project-cadccd56ad06), so why am I writing another one? The reason is that when I followed them, I ended up with a 722MB Docker image! I found this to be unnecessarily big which motivated me to look for ways to reduce it. So this article is about building a **minimal** Docker image for Scala project using Nix. Most of it can be applied to any program that runs on JVM (Java, Kotlin etc.) as well.

Containerization of a JVM application feels a bit strange because one has to also bundle the JVM to execute the JAR, so it's essentially virtualization over virtualization, which also most probably runs on a virtual machine. 

Anyway... let's start.

## First attempt

In order to containerize a Scala application one has to:

1. Build a JAR with all the dependencies included. This is called "über JAR".
2. Bundle it with a JVM.
3. Package the whole thing into a Docker-compatible container.

I am going to do all steps with Nix, since that gives me reproducible builds and I already use it for development.

My first attempt was the following:

```nix
let
    repository = builtins.fetchTarball {
        url = "https://github.com/zaninime/sbt-derivation/archive/master.tar.gz";
    };
    sbt-derivation = import "${repository}/overlay.nix";
    app = sbt-derivation.mkSbtDerivation.${system} {
        pname = "app";
        version = "0.0.1";
        src = ./.;
        depsSha256 = "sha256-06Qog8DyDgisnBhUQ9wW46WqqnhGXlakI1DSuFHkriQ=";

        buildInputs = with pkgs; [ sbt jdk23 makeWrapper ];

        buildPhase = "sbt assembly";

        installPhase = ''
        mkdir -p $out/bin
        mkdir -p $out/share/java

        cp src/app/target/scala-3.*/*.jar $out/share/java

        makeWrapper ${pkgs.jdk23_headless}/bin/java $out/bin/scala-app \
            --add-flags "-cp \"$out/share/java/*\" org.app.Application"
        '';
    };
    app-container = pkgs.dockerTools.buildImage {
        name = "app-container";
        tag = "latest";

        copyToRoot = [ packages.default pkgs.busybox ];

        config = { Cmd = [ "/bin/${packages.default.pname}" ]; };
    };
in 
    app-container
```

Explanation:

1. [sbt-derivation](https://github.com/zaninime/sbt-derivation) is a convenience utility to generate Nix derivations for `sbt` projects.
2. [sbt-assembly](https://github.com/sbt/sbt-assembly) lets us generate "über JAR" with all the necessary dependencies.
3. `makeWrapper` creates a binary that wraps the JAR with a `java` binary so it looks like a regular binary from outside. The binary comes from [jdk23_headless](https://search.nixos.org/packages?channel=unstable&show=jdk23_headless&from=0&size=50&sort=relevance&type=packages&query=jdk23_headless) package.

After I built the container, I was pushing it into the hosting provider's registry but I noticed it took a lot of time to upload it. My home connection is not really fast (I would expect better from Germany) so having to wait 15 minutes to deploy a new version of the application was very annoying. I checked the image size locally, and I saw:

```
REPOSITORY                                   TAG                               IMAGE ID      CREATED        SIZE
localhost/app-container                      latest                            f0e2ad8f1167  55 years ago   722 MB
```

Ignore the obviously incorrect `CREATED 55 years ago`, the image was 722 MB! This is huge for a project like this. Annoyed by it, I went to checkout the contents of the image. Using `docker`/`podman` one can export the image filesystem into a `.tar` archive:

```sh
aiono ❯ docker create localhost/app-container:latest
0b08b8de863228c8211d7c844a3e84a9b03c5032f68ee582e1e0fca6caee0244
aiono ❯ TMP_DIR=$(mktemp -d)
aiono ❯ docker export 0b08b8de863228c8211d7c844a3e84a9b03c5032f68ee582e1e0fca6caee0244 > "$TMP_DIR/image.tar"
aiono ❯ mkdir "$TMP_DIR/image"
aiono ❯ tar -xf "$TMP_DIR/image.tar" -C "$TMP_DIR/image"
```

Then I checked the contents of the image using [du](https://www.man7.org/linux/man-pages/man1/du.1.html):
```sh
aiono ❯ du -sh $TMP_DIR/image/*
1,2M    /tmp/tmp.3xnIHXwY1l/image/bin
4,0K    /tmp/tmp.3xnIHXwY1l/image/default.script
0       /tmp/tmp.3xnIHXwY1l/image/linuxrc
651M    /tmp/tmp.3xnIHXwY1l/image/nix
1,2M    /tmp/tmp.3xnIHXwY1l/image/sbin
37M     /tmp/tmp.3xnIHXwY1l/image/share
```

Seems like most of the size comes from `/nix/store` which is not surprising. What's under `/share` should be the JVM. So it seems like the problem is not in the JAR since it's just 37 MB. Let's verify:

```sh
aiono ❯ du -sh /tmp/tmp.3xnIHXwY1l/image/share/java/*
37M     /tmp/tmp.3xnIHXwY1l/image/share/java/scala-app-assembly-0.1.0.jar
```

Correct!

Let's see what are the largest directories under `/nix/store`:

```sh
aiono ❯ du -sh $TMP_DIR/image/nix/store/* | sort -h | tail -n 10
484K    /tmp/tmp.3xnIHXwY1l/image/nix/store/mk9nhl6b48gpqhdbjy9ir16wrz6r3qn6-lcms2-2.17
628K    /tmp/tmp.3xnIHXwY1l/image/nix/store/ncdwsrgq6n6161l433m4x34057zq0hhf-libidn2-2.3.8
1,2M    /tmp/tmp.3xnIHXwY1l/image/nix/store/skijwg3cx0hkl5p2l5l4zz898glxi644-busybox-1.36.1
1,7M    /tmp/tmp.3xnIHXwY1l/image/nix/store/00zrahbb32nzawrmv9sjxn36h7qk9vrs-bash-5.2p37
2,0M    /tmp/tmp.3xnIHXwY1l/image/nix/store/vm18dxfa5v7y3linrg1x1q9wx41bkxwf-libunistring-1.3
2,0M    /tmp/tmp.3xnIHXwY1l/image/nix/store/w753b87diqcja7gc3kifydxdfpi967ns-libjpeg-turbo-3.1.0
9,6M    /tmp/tmirectories undep.3xnIHXwY1l/image/nix/store/l7d6vwajpfvgsd3j4cr25imd1mzb7d1d-gcc-14.3.0-lib
31M     /tmp/tmp.3xnIHXwY1l/image/nix/store/q4wq65gl3r8fy746v9bbwgx4gzn0r2kl-glibc-2.40-66
37M     /tmp/tmp.3xnIHXwY1l/image/nix/store/778xsjch86fyv4qdzznqyihcw7s5r029-scala-app-0.0.1
566M    /tmp/tmp.3xnIHXwY1l/image/nix/store/w7rphym6zk35wsx3aknbn3y7srj3x5qa-openjdk-headless-23.0.2+7
```

The winner is definitely `openjdk-headless`. Almost all of the 722 MB comes from it. So that will be the first thing we will try to reduce. Second is odd, `scala-app` is the package for our app but we already have a copy of our app in `/share`! So it looks like a duplication but first focus on our JDK package.

## Minimal Java Runtime Environments

My first mistake was to bundle a full **Java Development Kit (JDK)** with the application. JDKs are used to _build_ a JVM app but to run it you only need **Java Runtime Environment (JRE)**. I searched for `jre` in [Nix Search](https://search.nixos.org/packages?channel=25.05&type=packages&query=jre). Second option was `jre_minimal`, which sounded very promising. So I made the following change:

```nix
- makeWrapper ${pkgs.jdk23_headless}/bin/java $out/bin/scala-app \
+ makeWrapper ${pkgs.jre_minimal}/bin/java $out/bin/scala-app \
```

Let's see how our image size changed:

```sh
aiono ❯ nix-build
aiono ❯ cat result | docker load
aiono ❯ docker images
REPOSITORY                        TAG                               IMAGE ID      CREATED        SIZE
localhost/app-container           latest                            0b25de30d43c  55 years ago   508 MB
```

It's down to 508 MB. Still very big but at least we managed to trim it down 200 MB. Let's try to run our app:

```sh
aiono ❯ nix-build
aiono ❯ docker run --expose 4041 --network host localhost/app-container:latest
Exception in thread "main" java.lang.NoClassDefFoundError: sun/misc/Unsafe
        at ...
```

Not good. Seems like we nedd `sun.misc.Unsafe` but `jre_minimal` doesn't come with it. We need to fix this.

I don't remember how I found, but [this section in nixpkgs reference](https://nixos.org/manual/nixpkgs/stable/#sec-language-java) shows how to use `jre_minimal`. Turns out, `jre_minimal` strips of _all_ the standard modules to provide a minimal JRE, so you need to provide which libraries you want. Under the hood, it [uses jlink to generate a minimal JRE](https://github.com/NixOS/nixpkgs/blob/3ff0e34b1383648053bba8ed03f201d3466f90c9/pkgs/development/compilers/openjdk/jre.nix#L28).

How do we know which modules we need? Thankfully, there is a tool for that called [jdeps](https://dev.java/learn/jvm/tools/core/jdeps/). We can run it in our assembled jar to see which dependencies we need.

```sh
aiono ❯ jdeps --ignore-missing-deps --list-reduced-deps result/share/java/server-assembly-0.1.0.jar
   java.base
   java.desktop
   java.management
   java.naming
   java.security.jgss
   java.security.sasl
   java.sql
   jdk.unsupported
```

Let's add those:

```nix
let
    repository = builtins.fetchTarball {
        url = "https://github.com/zaninime/sbt-derivation/archive/master.tar.gz";
    };
    sbt-derivation = import "${repository}/overlay.nix";
    app = let
        # Define custom JRE 👇
        jre = pkgs.jre_minimal.override {
            modules = [
                "java.base"
                "java.desktop"
                "java.logging"
                "java.management"
                "java.naming"
                "java.security.jgss"
                "java.security.sasl"
                "java.sql"
                "java.transaction.xa"
                "java.xml"
                "jdk.unsupported"
            ];
        };
    in
    sbt-derivation.mkSbtDerivation.${system} {
        # ...

        installPhase = ''
        mkdir -p $out/bin
        mkdir -p $out/share/java

        cp src/app/target/scala-3.*/*.jar $out/share/java

        # Use custom JRE 👇
        makeWrapper ${jre}/bin/java $out/bin/scala-app \
            --add-flags "-cp \"$out/share/java/*\" org.app.Application"
        '';
    };
    in 
    # ...
```

Let's build:

```sh
aiono ❯ nix-build
aiono ❯ cat result | docker load
aiono ❯ docker images
REPOSITORY                        TAG                               IMAGE ID      CREATED        SIZE
localhost/app-container           latest                            54a30dcb4708  55 years ago   596 MB
```

Got a bit bigger, but hopefully at least it runs:

```sh
aiono ❯ docker run --expose 4041 --network host localhost/app-container:latest
Server is listening at '/127.0.0.1:4041'
```

Yes! It successfully runs now.

While we made some progress, still it's far away from an appropriate size. The bulk of the size still comes from the JRE.

So I kept reading around, I noticed that I didn't notice an important part of the `jre_minimal` derivation. While I optimized the modules we need, I didn't pick an appropriate JDK. We can override the `jdk` attribute of the derivation for that.

```nix
let
    repository = builtins.fetchTarball {
        url = "https://github.com/zaninime/sbt-derivation/archive/master.tar.gz";
    };
    sbt-derivation = import "${repository}/overlay.nix";
    app = let
        jre = pkgs.jre_minimal.override {
            modules = [
                "java.base"
                "java.desktop"
                "java.logging"
                "java.management"
                "java.naming"
                "java.security.jgss"
                "java.security.sasl"
                "java.sql"
                "java.transaction.xa"
                "java.xml"jdk to J
                "jdk.unsupported"
            ];
            # Set JDK to headless 👇
            jdk = pkgs.jdk21_headless;
        };
    in
    ...
```

Let's build our image again:

```sh
aiono ❯ nix-build
aiono ❯ cat result | docker load
aiono ❯ docker images
REPOSITORY                        TAG                               IMAGE ID      CREATED        SIZE
localhost/app-container           latest                            ed070c56e715  55 years ago   239 MB
```

239 MB! That seems promising. Let's run and hopefully it doesn't crash:

```sh
aiono ❯ docker run --expose 4041 --network host localhost/app-container:latest
Server is listening at '/127.0.0.1:4041'
```

Great! We have come a long way from 722 MB to 239 MB.

## TODO: dockerTools.copyToRoot gotchas