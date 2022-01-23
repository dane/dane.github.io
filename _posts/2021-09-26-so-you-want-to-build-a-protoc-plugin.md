---
title: So You Want to Build a protoc Plugin
layout: post
---

You're already developing or maintaining a gRPC service, you're no stranger to
`protoc` plugins such as `protoc-gen-go` and `protoc-gen-go-grpc`, and you've
found an area of your codebase that a machine should write for you. Let's walk
through building a `protoc` plugin and by the end we'll have an auto-generated
CLI to use against our gRPC service.

We'll review the project structure, our example gRPC service, programmatically
navigate Protobuf service definitions, and lastly, leverage
[Protobuf Options][1] for additional CLI customization.

<!-- more -->

## Project Structure

The structure below should resemble most most or many projects you've seen:
- `example` directory contains the example gRPC service we'll be using to build
  our CLI against.
- `main.go` will be the entrypoint of our `protoc` plugin.
- `plugin.go` will contain the implementation details of our `protoc` plugin.
- `template.go.tmpl` will contain the [`text/template`][2] that will drive the
  code generation.
- `Makefile` has all of the shell commands shown in this guide.

```
% tree
.
├── example
│   ├── bin
│   ├── cmd
│   │   ├── example-api
│   │   │   └── main.go
│   │   └── example-cli
│   │       └── main.go
│   └── proto
│       ├── gen
│       │   └── v1
│       │       ├── service_grpc.pb.go
│       │       └── service.pb.go
│       └── v1
│           └── service.proto
├── main.go
├── Makefile
├── plugin.go
└── template.go.tmpl

9 directories, 9 files
```

## Our Example gRPC Service

The `Example` service has a single `Create` RPC with a request and response
message and several comments. I intentionally haven't commented the entire
file---only in locations we'll use later in our CLI.  While the service
definition is simple, everything we go over will apply to other/larger service
definitions.

```
syntax = "proto3";

package v1;

option go_package = "github.com/dane/protoc-gen-go-cli/example/proto/gen/v1;v1";

// Example service is used to illustrate how to auto-generate a CLI with a
// protoc plugin.
service Example {
  // Create accepts a name as input and creates the example resource.
  rpc Create(CreateRequest) returns (CreateResponse);
}

message CreateRequest {
  // name is the name of the resource to be created.
  string name = 1;
}

message CreateResponse {
  // name is the name of the resource that was created.
  string name = 1;

  // created is a boolean indicated the resource was successfully created.
  bool created = 2;
}
```

## Navigating a .proto File

The [google.golang.org/protobuf/compiler/protogen][3] package makes navigating a
`proto` file straightforward. Every file processed by `protoc` is exposed to us
through [`*protogen.Plugin`][4]. I'll briefly describe the structs and fields
we'll be using below:

- `*protogen.Plugin` is the means in which all `proto` files are exposed to our
  program. It has a field `Files` (a slice of [`*protogen.File`][5]).
- `*protogen.File` represents every file `protoc` has to process. It has a field
  `Services` (a slice of [`*protogen.Service`][6]).
- `*protogen.Service` is an individual service defined in a `proto` file. It has
  field `Methods` (a slice of [`*protogen.Method`][7]) which are the service
  RPCs.
- `*protogen.Method` has fields `Input` and `Output` (both are [`*protogen.Message`][8]).
- `*protogen.Message` has a field `Fields` (a slice of [`*protogen.Field`][9]).

Every struct mentioned has a field `Comments`
([`*protogen.CommentSet`][10]). We'll be leveraging the `Leading` field of a
`*protogen.CommentSet`, but I encourage reviewing the documentation of `Trailing`
or `LeadingDetached` as they may better fit your use case.

## Building Our Plugin

The `main.go` file will be the plugin entrypoint. We'll keep this file small,
while illustrating how to support command-line flags (eg: `--go_opt` or
`--go-grpc_opt`).

```
package main

import (
    "flag"

    "google.golang.org/protobuf/compiler/protogen"
)

func main() {
    var flags flag.FlagSet
    var plugin Plugin

    flags.BoolVar(&plugin.Verbose, "verbose", false, "enable verbose logging")

    options := protogen.Options{ParamFunc: flags.Set}
    options.Run(plugin.Run)
}
```

By passing a `flag.FlagSet` to the `ParamFunc` of [`*protogen.Options`][11], our
plugin will automatically accept the command-line flag
`--go-cli_opt=verbose=true`. Additional flags can be added as needed, but this
is the only flag we'll be using.

The `plugin.go` file contains the implementation details of our plugin, the
`Plugin` struct instantiated in the `main` function, and the `Run` method
attached to the `Plugin` struct. I'll walkthrough this file in two blocks:

```
package main

import (
    "io"
    "io/ioutil"
    "log"
    "os"

    "google.golang.org/protobuf/compiler/protogen"
)

type Plugin struct {
    Verbose bool
}

func (p *Plugin) Run(plugin *protogen.Plugin) error {
    var out io.Writer = ioutil.Discard
    if p.Verbose {
        out = os.Stderr
    }
    logger := log.New(out, "", log.Lshortfile)
```

These lines of code shouldn't suprise you. We have a handful of imports and
defined a logger. It's at this point I was able to leverage that `Verbose` flag
we set previously in the `main` function and output must be sent to `STDERR`.
Anything sent to `STDOUT` will be processed by `protoc`.

```
    for _, file := range plugin.Files {
        if !file.Generate {
            continue
        }

        logger.Printf("file=%s", file.Desc.Path())

        for _, service := range file.Services {
            for _, method := range service.Methods {
                for _, field := range method.Input.Fields {
                    logger.Printf(
                        "service=%s method=%s input=%s field=%s",
                        service.GoName,
                        method.GoName,
                        method.Input.GoIdent.GoName,
                        field.GoName,
                    )

                    logger.Printf("comment=%q", field.Comments.Leading)
                }
            }
        }
    }
    return nil
}
```

Installing and running the plugin yields three log lines. A `proto` file, our
gRPC service, and the comment documenting the `name` field of the
`CreateRequest` message.

```
% go install github.com/dane/protoc-gen-go-cli
% protoc -I example/proto \
  --go-cli_out=example/proto/gen \
  --go-cli_opt=paths=source_relative,verbose=true \
  example/proto/v1/service.proto
plugin.go:28: file=v1/service.proto
plugin.go:33: service=Example method=Create input=CreateRequest field=Name
plugin.go:40: comment="// name is the name of the resource to be created.\n"
```

Take note of the comment that was logged. It includes the forward slashes
and a new-line character. We'll have to strip those out.

This revision to the `for` loop writes the values to a file instead of logging
them. It also includes a `stripComment` function that removes the forward
slashes and new-line mentioned previously.

```
    for _, file := range plugin.Files {
        if !file.Generate {
            continue
        }

        logger.Printf("file=%s", file.Desc.Path())

        fileName := fmt.Sprintf("%s_cli.go", file.GeneratedFilenamePrefix)
        gen := plugin.NewGeneratedFile(fileName, file.GoImportPath)
        gen.P("package ", file.GoPackageName)

        for _, service := range file.Services {
            for _, method := range service.Methods {
                for _, field := range method.Input.Fields {
                    gen.P("// service: ", service.GoName)
                    gen.P("// method: ", method.GoName)
                    gen.P("// input: ", method.Input.GoIdent.GoName)
                    gen.P("// field: ", field.GoName)
                    gen.P("// comment: ", stripComment(field.Comments.Leading))
                }
            }
        }
    }
    return nil
}

func stripComment(comments protogen.Comments) string {
    value := strings.TrimPrefix(string(comments), "//")
    return strings.TrimSpace(value)
}
```

The [`NewGeneratedFile`][12] method creates the auto-generated file and the
[`P`][13] method appends text to it. A [`protogen.GeneratedFile`][14] also
adheres to the [`io.Writer`][15] interface which we'll make use of later.


Now, if we install and run the plugin again, fewer log lines will be omitted,
but we will have an auto-generated file.

```
% go install github.com/dane/protoc-gen-go-cli
% protoc -I example/proto \
        --go-cli_out=example/proto/gen \
        --go-cli_opt=paths=source_relative,verbose=true \
        example/proto/v1/service.proto
plugin.go:30: file=v1/service.proto

% cat example/proto/gen/v1/service_cli.go
package v1

// service: Example
// method: Create
// input: CreateRequest
// field: Name
// comment: name is the name of the resource to be created.
```

## Building a CLI

At this point we know how to auto-generate a file and write to it, but we
haven't gone over _what_ to write. 





-----

We're starting out with a working API and handwritten CLI.

```
% bin/hello-world hello --help
hello accepts a name from input and returns a "Hello {name}!" string.

Usage:
  hello-world hello [flags]

Flags:
  -h, --help          help for hello
      --name string   name is the name of the person to be greeted.
```

Let's start the `hello-world-api` on port 9000:

```
% bin/hello-world-api
2021/09/26 16:00:13 listening on "[::]:9000"
```

And send a request to the gRPC service with the CLI:

```
% bin/hello-world hello --name Dane
Hello Dane!
```

Before starting the plugin let's review the service definition and the existing
CLI. The service contains a single RPC (`SayHello`) and two messages
(`SayHelloRequest` and `SayHelloResponse`). There are comments throughout the
file, but I'll omit them to keep the code snippet short.

```
service HelloWorld {
  rpc SayHello(SayHelloRequest) returns (SayHelloResponse);
}

message SayHelloRequest {
  string name = 1;
}

message SayHelloResponse {
  string message = 1;
}
```

The CLI is a bit longer and can be [seen in full here][3]. The significant areas
of the file is the `main` function where the `rootCmd` is created:

```
func main() {
    rootCmd := &cobra.Command{
        Use:   "hello-world",
        Short: "Interact with HelloWorld service",
    }

    rootCmd.AddCommand(NewHelloCommand())

    err := rootCmd.Execute()
    exitIf(err)
}
```



[1]: https://developers.google.com/protocol-buffers/docs/proto3#options
[2]: https://golang.org/pkg/text/template/
[3]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen
[4]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Plugin
[5]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#File
[6]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Service
[7]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Method
[8]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Message
[9]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Field
[10]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#CommentSet
[11]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Options
[12]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#Plugin.NewGeneratedFile 
[13]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#GeneratedFile.P
[14]: https://pkg.go.dev/google.golang.org/protobuf@v1.27.1/compiler/protogen#GeneratedFile
[15]: https://pkg.go.dev/io#Writer
