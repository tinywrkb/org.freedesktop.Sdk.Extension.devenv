# TODO

* default to /var/lib
* improve enable.sh
  * read envvar DEVENV_SHELL to select shell (default to bash)
  * default to using /var/lib
  * set global XDG workaround instead of bashrc
* only override HOME and XDG user dirs variables in wrapper scripts
* enable-sdk
* Remove how-to section
* possible failure mapping of sdk path
  * stow: hardcoded perl `use dir`, can be patched
  * luajit: dynamically linked bindings, not sure if working
  * luajit: dynamically linked bindings, check if symlink to libc can be drop into same folder
  * luajit: dynamically linked bindings, try again to statically link against libc, but keep shared
  * luajit: keep bindings
  * libutempter: "libexec"
  * kakoune: "libexec", strange one, links to bin, try droping this
  * luajit: bindings are in lib, very likely hardcoded path
  * byobu: lib execs, check if relative to executable
  * running apps might try to access sdk path when they should switch to /var/lib: byobu, neovim
  * byobu: etc defaults
  * etc/profile.d: can be dropped?
  * vimfm: default colors in /etc
  * wtf put group, machineid, passwd, resolv.conf in etc?
  * share: byobu, fish, fzf, kak, kak-lsp, luajit, nnn, nvim, pyenv, ugrep, vifm, vim, zsh
* modules to add
  * add more patched fonts: nerd-fonts
  * iso manipulation tools: cdrtools, fuseiso
  * filesystems fuse tools: at least for dos/fat, ext2/3/4, overlayfs
  * partioning tools to operate on raw disk images
  * fonts for terminal emulator: noto-vf
  * debugging tools: gdb, valgrind
* Investigate possible broken host tmux sessions
* Drop musl shared lib, move next to users, maybe loader link can be relative
* Evaluate building all golang and rust modules from source
* golang
  * Ask upstream for static-pie binaries
  * Compile from source: static-pie, `-extldflags="--static-pie"`
  * Disable cgo where it's possible
  * Test mold with cgo apps
* Choose a better extension name
* Add CI to build and publish via oci registry
* See other useful tools @ https://github.com/agarrharr/awesome-cli-apps

## variables and build wrapper
* maybe create a wrapper for each language that set variable in its own environment and run commands
* maybe wrapper should create symlink to project in /run/build to hit cache
  * project name might be different from folder name and match module name in manifest
  * read setting from config file
  * start by having a simple build.sh
* golang
  * GOCACHE=${HOME}/.cache/gocache
  * GOPATH=${PROJECT_PATH}
  * XDG_CACHE_HOME=${PROJECT_PATH}/cache (in wrapper script)
  * GO111MODULE=off
* rust
  * HOME
  * CARGO_HOME=${PROJECT_PATH}/cargo
  * SCCACHE_BIN=/usr/lib/sdk/sccache/bin/sccache
  * RUSTC_WRAPPER=${SCCACHE_BIN}
  * SCCACHE_DIR=${HOME}/.cache/sccache
  * SCCACHE_CONF=${SCCACHE_DIR}/config
* node
  * NPM_PACKAGES=${PROJECT_PATH}/xdg-data/npm-packages
  * PATH+=:${NPM_PACKAGES}/bin
* generic/c/cpp
  * AR=ar | x86_64-linux-musl-ar
  * CC=gcc | x86_64-linux-musl-gcc
  * CXX=g++ | x86_64-linux-musl-g++
  * LD=ld | ld.mold | x86_64-linux-musl-ld.mold
  * TARGET_PATH=${PROJECT_PATH}/target
  * PATH=${TARGET_PATH}/bin:${PATH}
  * LD_LIBRARY_PATH=${TARGET_PATH}/lib:${LD_LIBRARY_PATH}
  * PKG_CONFIG_PATH=${TARGET_PATH}/lib/pkgconfig:${TARGET_PATH}/share/pkgconfig:...
  * ACLOCAL_PATH=${TARGET_PATH}/share/aclocal
  * C_INCLUDE_PATH=${TARGET_PATH}/include
  * CPLUS_INCLUDE_PATH=${TARGET_PATH}/include
  * LDFLAGS=-L${TARGET_PATH}/lib
  * LC_ALL=en_US.utf8
