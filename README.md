# Sdk.Extension.devenv

This is a little experiement of packaging a user-defined shell environment with CLI tools as a Flatpak SDK extension.  
Naming is not very imaginative, and might change.  
I didn't like the alterntives, connecting a shell from a Flatpak sandbox to a host shell or a Podman container shell,
both sound self-defeating. There should be a good reason to break out of the Flatpak sandbox.  
Shorty after I started playing with this, I figured that there's no reason why I shouldn't re-use this for other
containers, making use of Flatpak's packaging tools to build and keep this updated, so for the most part, the packaged
binaries are statically linked, which also avoids introducing shared libraries.  
This is very opiniated and user-specific, so you probably don't want to use this as it is, but it will give you a good
idea how to package your own custom environment.  
It should be noted that [a running Flatpak instance will lose a mounted extension when the latter is updated](https://github.com/flatpak/flatpak/issues/4356).  
For that reason, and to support re-use of this with other containers, an alternative root path `/var/lib/devenv` will
also be supported.

An example application, `org.freedesktop.DevEnv`, is used to create a Flatpak instance, with this SDK extension enabled,
but the extension is mainly intended to be used with Flatpak packaged IDEs.


## How to build

### Set up build cache

You would want to make sure that ccache is enable and being used by Flatpak Builder (check for ccache hits).  
Essentially, it mean adding the `--cache` option, setting `CCACHE_DIR` environment variable, if ccache dir is not in the
default location.  
Flatpak Builder will mount the ccache dir to `/run/ccache` in the sandbox and will set `CCACHE_DIR` to this path.

To give access to sccache and golang build cache dirs, move them to `CCACHE_DIR/sccache` and `CCACHE_DIR/gocache`
accordingly, and then linked to them from `XDG_CACHE_DIR/sccache` and `XDG_CACHE_DIR/go-build`, so they will still be
shared with toolchains running directly in the host environment.

### Dependencies

You will need first to build and install the following SDK extensions:

* [org.freedesktop.Sdk.Extension.musl](https://github.com/tinywrkb/org.freedesktop.Sdk.Extension.musl)
* [org.freedesktop.Sdk.Extension.go-musl](https://github.com/tinywrkb/org.freedesktop.Sdk.Extension.go-musl)
* [org.freedesktop.Sdk.Extension.rust-musl](https://github.com/tinywrkb/org.freedesktop.Sdk.Extension.rust-musl)
* [org.freedesktop.Sdk.Extension.sccache](https://github.com/tinywrkb/org.freedesktop.Sdk.Extension.sccache)

### Building the extension

In addition to the `--ccache` option, I suggest also adding `--disable-updates` to have rebuilds start faster,
as there are a good number of git sources here.


## TODO
* helper scripts
  * flatpak-builder like env vars
  * set local installation targets: python, golang, rust
    node: NPM_PACKAGES=xdg-data/npm-packages
          PATH+=:xdg-data/npm-packages/bin
* read envvar to select shell (default to bash)
* test portability, needs to work when switching to /var/lib
* deal better with overriden HOME and XDG user dirs variables
* add more patched fonts: nerd-fonts
* investigate possible broken host tmux sessions
* drop musl shared lib, move next to users, maybe loader link can be relative
* evaluate building all golang and rust modules from source
* golang
  * ask upstream for static-pie binaries
  * compile from source: static-pie, `-extldflags="--static-pie"`
  * disable cgo where it's possible
  * test mold with cgo apps
* modules to add
  * iso manipulation tools: cdrtools, fuseiso
  * filesystems fuse tools: at least for dos/fat, ext2/3/4, overlayfs
  * partioning tools to operate on raw disk images
  * fonts for terminal emulator: noto-vf
  * debugging tools: gdb, valgrind
* choose a better extension name
* add ci to build and publish via oci registry
* see other useful tools @ https://github.com/agarrharr/awesome-cli-apps

## How to

* fontconfig
  * add to fonts.conf see [flatpaks README.md](https://github.com/tinywrkb/flatpaks/blob/master/README.md)
  * now: `<dir>/usr/lib/sdk/devenv/share/fonts/powerline</dir>`
  * next: `<dir prefix="xdg">fonts/powerline</dir>`
  * Reference: [fontconfig: Add support for XDG_DATA_DIRS](https://gitlab.freedesktop.org/fontconfig/fontconfig/-/commit/6f27f42e6140030715075aa3bd3e5cc9e2fdc6f1)

* easily enable after entering a sandbox
  * add override for envvar
    ```
    $ flatpak override --user --env=ENABLE_DEVENV=/usr/lib/sdk/devenv/bin/enable-development-environment
    ```
  * enter sandbox and then use envvar to run shell: `$ $ENABLE_DEVENV`

* enter a sandbox with enabled shell
  * set envvar in host shell
    ```
    $ export fpde=/usr/lib/sdk/devenv/bin/enable-development-environment
    ```
  * enter sandbox: `$ flatpak run --command=$fpde org.freedesktop.Sdk//21.08`

* enable by default, only works with actual apps, not runtimes
  * add persist override:  `$ flatpak override --user --persist=. FLATPAK_ID`
  * enter sandbox: `$ flatpak run FLATPAK_ID`
  * create .bashrc: `$ echo 'source $ENABLE_DEVENV' > .bashrc`

* fish: possible workarounds for hardcoded paths
  ```
  export fish_complete_path=$DEVENV_PATH/share/fish/completions
  export fish_function_path=$DEVENV_PATH/share/fish/functions
  export PATH=$DEVENV_PATH/bin:$PATH
  export __fish_datadir=$DEVENV_PATH/share
  export __fish_data_dir=$DEVENV_PATH/share
  export XDG_DATA_DIRS=$DEVENV_PATH/share:$XDG_DATA_DIRS
  ```
