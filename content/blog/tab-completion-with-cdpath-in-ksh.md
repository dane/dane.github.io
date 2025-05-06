---
title: "Tab completion with CDPATH in ksh"
publishDate: 2025-05-02
description: |
  A brief example on how to create tab completion of paths declared with CDPATH
  in ksh.
---

I used `bash` and `zsh` for most of my Linux/BSD life. I switched to `ksh` when
I started using OpenBSD as my daily driver since that's the default. `CDPATH` is
one of my favorite features of these shells. It allows me to navigate between
projects quickly and from anywhere on my file system. For example, if I had
three projects, `foo`, `bar`, and `baz`:

```
$ ls ~/Projects/src/**/*
/home/dane/Projects/src/github.com/dane:
foo bar baz
```

By exporting my `CDPATH` to `CDPATH=$CDPATH:~/Projects/src`, I can navigate
between them:

```
$ pwd
/home/dane
$ cd github.com/dane/foo
$ pwd
/home/dane/Projects/src/github.com/dane/foo
```

`bash` and `zsh` have `cd` tab complete paths and subpaths declared in `CDPATH`,
but `ksh` does not. I wanted to have a similar experience with `ksh`. There is
a built-in means of creating tab completions in `ksh` for any command, but you
must declare all possible values that can be completed. This is done with:

```
$ set -A complete_{COMMAND}_{ARG_COUNT} -- {VALUES}
```

For example, if I wanted to use tab completion to build the path
`github.com/dane/foo`, I would run the following:

```
$ export CDPATH=$CDPATH:~/Projects/src
$ set -A complete_cd_1 -- github.com/dane/foo
$ cd git<TAB>
```

I wanted `cd` to complete all of my project paths so I needed to create a
command that would list all possible paths:

```
$ find ~/Projects/src -type d -maxdepth 3 
/home/dane/Projects/src
/home/dane/Projects/src/github.com
/home/dane/Projects/src/github.com/dane
/home/dane/Projects/src/github.com/dane/foo
/home/dane/Projects/src/github.com/dane/bar
/home/dane/Projects/src/github.com/dane/baz
```

Next, I needed to remove the `/home/dane/Projects/src/` prefix:

```
find ~/Projects/src -type d -maxdepth 3 | sed "s#^$HOME/Projects/src/##g"
/home/dane/Projects/src
github.com
github.com/dane
github.com/dane/foo
github.com/dane/bar
github.com/dane/baz
```

`find` has an `-exec` flag, I know, but I couldn't get it to work so I piped the
output to `sed` instead. Let me know if you can get `-exec` working!

With the directory list generated it just needed to be passed to the `set -A`:

```
set -A complete_cd_1 -- `
  find ~/Projects/src -type d -maxdepth 3 | \
    sed "s#^$HOME/Projects/src/##g"
`
```

My solution isn't perfect. It only targets one path where `CDPATH` may contain
many. I can't `cd` into a new project path until the `complete_cd_1` values are
regenerated. `/home/dane/Projects/src` is unnecessarily passed to
`complete_cd_1`. Knowing this, I feel like my approach struck a balance between
addressing my need while remaining simple.
