---
layout: post
title: Creating a protoc plugin
---

In this article we'll be going over how `protoc` interacts with plugins and how
to build our very own. By the end of this article we will have a CLI
auto-generated from proto definitions. Before going further let's make sure
we're using the same versions of Go and `protoc`:

```
% go version
go version go1.16.6 linux/amd64
% protoc --version
libprotoc 3.14.0
```

I will also be using v1.27.1 of the [`google.golang.org/protobuf`][1] package:

```
% go get google.golang.org/protobuf@v1.27.1
```

## Project structure

Let's take a look at the project directory structure, files, and their contents.

```
% tree .
.
├── cmd
│   ├── hello-world
│   │   └── main.go
│   └── protoc-gen-go-example
│       └── main.go
├── Makefile
└── proto
    ├── go
    └── hello_world.proto
```

The `proto/hello_world.proto` file contains definitions for our `HelloWorld`
service and a single RPC. `proto/go` is an empty directory, but `protoc` needs
the destination of auto-generated code to exist. It wont create the directory
for you. `cmd/hello-world/main.go` is an empty file, but it will be our CLI once
the plugin is generating code. `cmd/protoc-gen-go-example/main.go` is the first
file we're going to open, that'll be the actual plugin.

Before moving on to the plugin, I should mention the `Makefile`. It isn't needed
for the project, but it contains a few convenience tasks.

- `make install` builds the plugin and installs it into our `$GOPATH/bin`
- `make generate` runs `protoc` and our plugin
- `make hello-world` builds our CLI and installs it at `bin/hello-world`

I'll be using these `make` tasks throughout the article.

## A "Hello, world!" plugin

We should setup the project by initializing `go mod` and getting the
`google.golang.org/protobuf` package.

```
% go mod init
go: creating new go.mod: module github.com/dane/protoc-plugin-example
go: to add module requirements and sums:
        go mod tidy
% go get google.golang.org/protobuf@v1.27.1
google.golang.org/protobuf: no Go source files
```

Open `cmd/protoc-gen-go-example/main.go` and let's start building our plugin.
Below is the minimum amount of code necessary for our plugin to compile:

```
package main

import "google.golang.org/protobuf/compiler/protogen"

func main() {
        var options protogen.Options
        options.Run(func(plugin *protogen.Plugin) error {
                return nil
        })
}
```

`protoc` interacts with plugins via `STDIN` and `STDOUT` so we can't just add
`fmt.Println("Hello, world!")` to the function passed to `Run`. Instead, import
`os` as well as `fmt` and direct print statements to `STDERR`.

```
package main

import (
        "fmt"
        "os"

        "google.golang.org/protobuf/compiler/protogen"
)

func main() {
        var options protogen.Options
        options.Run(func(plugin *protogen.Plugin) error {
		// Direct to STDERR.
                fmt.Fprintln(os.Stderr, "Hello, world!")
                return nil
        })
}
```

Now, if we leverage those `make` tasks mentioned earlier, we'll get our first
plugin output:

```
% make install
% make generate
Hello, world!
```

### Refactor

We'll make a couple modifications to our code to resemble a more realistic
project and gain an understanding of how flags work. Create a `Plugin` struct in
`internal/plugin.go`, relocate the anonymous `Run` function to hang off of
`*Plugin`, and add a `Verbose` boolean field. The file should look like this:

```
package internal

import (
        "fmt"
        "os"

        "google.golang.org/protobuf/compiler/protogen"
)

type Plugin struct {
        Verbose bool
}

func (p *Plugin) Run(plugin *protogen.Plugin) error {
        // Direct to STDERR.
        fmt.Fprintln(os.Stderr, "Hello, world!")
    }
}
```

To make use of the `Verbose` field, wrap the `fmt.Fprintln` statement in an `if`
statement.

```
if p.Verbose {
        // Direct to STDERR.
        fmt.Fprintln(os.Stderr, "Hello, world!")
}
```

We can now delete a bit of code from `cmd/protoc-gen-go-example/main.go`, but
we'll need to import the `flag` package in order to populate the `Verbose`
struct field.

```
package main

import (
        "flag"

        "google.golang.org/protobuf/compiler/protogen"

        "github.com/dane/protoc-plugin-example/internal"
)

func main() {
        var flags flag.FlagSet
        var plugin internal.Plugin

        flags.BoolVar(&plugin.Verbose, "verbose", false, "enable verbose logging")

        options := protogen.Options{ParamFunc: flags.Set}
        options.Run(plugin.Run)
}
```

All of the plugin logic is encapulated in the `Run` method of our
`internal.Plugin` and we've assigned the `protogen.Options` `ParamFunc` to a
`flag.FlagSet` of all supported flags. If we rebuild and run the plugin now,
there won't be any output because the `Verbose` flag defaults to `false`. I've
updated the `make generate` task to pass `verbose=true` through the `*_opt`
flag.

```
generate:
        @protoc -I proto --go-example_opt=verbose=true --go-example_out=. hello_world.proto
```

Running the `make install` and `make generate` tasks as we did before yields the
same results:

```
% make install
% make generate
Hello, world!
```

## Traversing proto files

`protoc` will make all referenced proto files available to your plugin. This
means the files you directly target, the files they import (eg:
`google/protobuf/timestamp.proto`), the files _they_ import, etc. The Go
`protobuf` package makes it easy to identify which files our plugin should be
taking action on with a `Generate` boolean on the `*protogen.File` struct.


[1]: https://pkg.go.dev/google.golang.org/protobuf

-------

- Explain what the article will achieve
- State assumptions the author has (eg: go version, protoc version, protobuf go
  package version)
- Show project structure (tree .)
- Show proto/hello_world.proto content and explain it
- Explain how protoc interacts with plugins via stdin/stdout
- 
