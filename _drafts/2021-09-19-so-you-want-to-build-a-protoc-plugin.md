---
Fixes:
- proto file should live in proto/example/hello_world/v1/service.proto
- gen code should live in proto/gen/v1
- update Makefile and shell commands with proper proto and gen paths
- update project tree
- include command.go.tmpl in project tree
- Consider writing comments to proto/gen/v1/hello_world.go instead of YAML
---


```
% go version
go version go1.16.6 linux/amd64
% protoc --version
libprotoc 3.14.0
```

```
% go get google.golang.org/protobuf@v1.27.1
```

```
% tree .
.
├── cmd
│   ├── hello-world
│   │   └── main.go
│   └── protoc-gen-go-example
│       └── main.go
├── go.mod
├── go.sum
├── internal
│   └── plugin.go
├── Makefile
└── proto
    ├── go
    └── hello_world.proto

6 directories, 7 files
```

```
% go mod init
go: creating new go.mod: module github.com/dane/protoc-plugin-example
go: to add module requirements and sums:
        go mod tidy
% go get google.golang.org/protobuf@v1.27.1
```

```
// file: cmd/protoc-gen-go-example/main.go
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

```
// file: internal/plugin.go
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
        if p.Verbose {
                // Direct to STDERR.
                fmt.Fprintln(os.Stderr, "Hello, world!")
        }
        return nil
}
```

```
% go install github.com/dane/protoc-plugin-example/cmd/protoc-gen-go-example
% protoc -I proto --go-example_out=. hello_world.proto
% protoc -I proto --go-example_opt=verbose=true --go-example_out=. hello_world.proto
Hello, world!
```

```
// file: internal/plugin.go
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
        for _, file := range plugin.Files {
                if p.Verbose {
                        fmt.Fprintf(os.Stderr, "%s: %v\n", file.Desc.Path(), file.Generate)
                }
        }
        return nil
}
```

```
% go install github.com/dane/protoc-plugin-example/cmd/protoc-gen-go-example
% protoc -I proto --go-example_opt=verbose=true --go-example_out=. hello_world.proto
hello_world.proto: true
```

```
// file: internal/plugin.go
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
        for _, file := range plugin.Files {
                if !file.Generate {
                        continue
                }

                if p.Verbose {
                        for _, service := range file.Services {
                                // Print HelloWorld service name.
                                fmt.Fprintf(os.Stderr, "service: %s\n", service.GoName)

                                // Print RPC names in HelloWorld service.
                                fmt.Fprintln(os.Stderr, "methods:")
                                for _, method := range service.Methods {
                                        fmt.Fprintf(os.Stderr, "- name: %s\n", method.GoName)

                                        // Print input message of each RPC.
                                        fmt.Fprintln(os.Stderr, "  input:")
                                        fmt.Fprintf(os.Stderr, "    name: %s\n", method.Input.GoIdent.GoName)
                                        fmt.Fprintln(os.Stderr, "    fields:")

                                        // Print field names of input message.
                                        for _, field := range method.Input.Fields {
                                                fmt.Fprintf(os.Stderr, "    - name: %s\n", field.GoName)
                                                fmt.Fprintf(os.Stderr, "      comments: %s\n", fieldComment)
                                        }

                                        // Print output message of each RPC.
                                        fmt.Fprintln(os.Stderr, "  output:")
                                        fmt.Fprintf(os.Stderr, "    name: %s\n", method.Output.GoIdent.GoName)
                                }
                        }
                }

        }
        return nil
}
```

```
% go install github.com/dane/protoc-plugin-example/cmd/protoc-gen-go-example
% protoc -I proto --go-example_opt=verbose=true --go-example_out=. hello_world.proto
service: HelloWorld
methods:
- name: Say
  input:
    name: SayRequest
    fields:
    - name: Name
  output:
    name: SayResponse
```

```
// file: internal/plugin.go
package internal

import (
        "fmt"
        "log"
        "strings"

        "google.golang.org/protobuf/compiler/protogen"
)

type Plugin struct {
        Verbose bool
}

func (p *Plugin) Run(plugin *protogen.Plugin) error {
        for _, file := range plugin.Files {
                if !file.Generate {
                        continue
                }

                // Convert path/to/hello_world.proto to path/to/hello_world.yaml.
                filePath := fmt.Sprintf("%s.yaml", file.GeneratedFilenamePrefix)

                // Create generated file.
                gen := plugin.NewGeneratedFile(filePath, file.GoImportPath)

                if p.Verbose {
                        log.Printf("Writing %s -> %s", file.Desc.Path(), filePath)
                }

                for _, service := range file.Services {
                        // Print HelloWorld service name.
                        fmt.Fprintf(gen, "service: %s\n", service.GoName)

                        // Print RPC names in HelloWorld service.
                        fmt.Fprintln(gen, "methods:")
                        for _, method := range service.Methods {
                                // Remove forward slashes and new-lines from comment.
                                methodComment := strings.TrimPrefix(string(method.Comments.Leading), "//")
                                methodComment = strings.TrimSpace(methodComment)

                                fmt.Fprintf(gen, "- name: %s\n", method.GoName)
                                fmt.Fprintf(gen, "  comments: %s\n", methodComment)

                                // Print input message of each RPC.
                                fmt.Fprintln(gen, "  input:")
                                fmt.Fprintf(gen, "    name: %s\n", method.Input.GoIdent.GoName)
                                fmt.Fprintln(gen, "    fields:")

                                // Print field names of input message.
                                for _, field := range method.Input.Fields {
                                        // Remove forward slashes and new-lines from comment.
                                        fieldComment := strings.TrimPrefix(string(field.Comments.Leading), "//")
                                        fieldComment = strings.TrimSpace(fieldComment)

                                        fmt.Fprintf(gen, "    - name: %s\n", field.GoName)
                                        fmt.Fprintf(gen, "      comments: %s\n", fieldComment)
                                }

                                // Print output message of each RPC.
                                fmt.Fprintln(gen, "  output:")
                                fmt.Fprintf(gen, "    name: %s\n", method.Output.GoIdent.GoName)
                        }
                }
        }
        return nil
}
```

```
% go install github.com/dane/protoc-plugin-example/cmd/protoc-gen-go-example
% protoc -I proto --go-example_opt=paths=source_relative,verbose=true --go-example_out=proto/go hello_world.proto
2021/09/22 08:22:13 Writing hello_world.proto -> hello_world.yaml
% ls proto/go
hello_world.yaml
```

```
service: HelloWorld
methods:
- name: Say
  comments: Say accepts a name from input and returns a "Hello {name}!" string.
  input:
    name: SayRequest
    fields:
    - name: Name
      comments: name is the name of the person to be greeted.
  output:
    name: SayResponse
```

```
// file: internal/plugin.go
package internal

import (
        "bytes"
        _ "embed"
        "fmt"
        "go/format"
        "log"
        "strings"
        "text/template"

        "google.golang.org/protobuf/compiler/protogen"
        "google.golang.org/protobuf/reflect/protoreflect"
)

type Plugin struct {
        Verbose bool
}

type Params struct {
        GoPackageName protogen.GoPackageName
        Methods       []*protogen.Method
}

//go:embed command.go.tmpl
var commandTmpl string

func (p *Plugin) Run(plugin *protogen.Plugin) error {
        tmpl, err := template.New("command").Funcs(template.FuncMap{
                "ToUpper":      strings.ToUpper,
                "ToLower":      strings.ToLower,
                "FlagName":     flagName,
                "TrimComments": trimComments,
        }).Parse(commandTmpl)

        if err != nil {
                return err
        }

        for _, file := range plugin.Files {
                if !file.Generate {
                        continue
                }

                // Convert path/to/hello_world.proto to path/to/hello_world.go.
                filePath := fmt.Sprintf("%s.go", file.GeneratedFilenamePrefix)

                // Create generated file.
                gen := plugin.NewGeneratedFile(filePath, file.GoImportPath)

                if p.Verbose {
                        log.Printf("Writing %s -> %s", file.Desc.Path(), filePath)
                }

                for _, service := range file.Services {
                        var buf bytes.Buffer
                        err := tmpl.Execute(&buf, Params{
                                GoPackageName: file.GoPackageName,
                                Methods:       service.Methods,
                        })

                        if err != nil {
                                return err
                        }

                        formatted, err := format.Source(buf.Bytes())
                        if err != nil {
                                return err
                        }

                        if _, err := gen.Write(formatted); err != nil {
                                return err
                        }
                }
        }
        return nil
}

func flagName(kind protoreflect.Kind) string {
        switch kind {
        case protoreflect.StringKind:
                return "StringVarP"
        case protoreflect.Int64Kind:
                return "IntVarP"
        case protoreflect.DoubleKind:
                return "Float64VarP"
        case protoreflect.BoolKind:
                return "BoolVarP"
        }

        return ""
}

func trimComments(comments protogen.Comments) string {
        value := strings.TrimPrefix(string(comments), "//")
        return strings.TrimSpace(value)
}
```

```
// file: internal/command.go.tmpl
// Code generated by protoc-gen-go-example. DO NOT EDIT.

package {{ .GoPackageName }}

import (
        "fmt"

        "github.com/spf13/cobra"
)

var All = []*cobra.Command{
        {{ range .Methods -}}
        New{{ .GoName }}Command(),
        {{ end -}}
}

{{ range .Methods }}
type {{ .GoName }}Runner struct {
        {{ range .Input.Fields -}}
                {{ .GoName }} {{ .Desc.Kind -}}
        {{ end -}}
}

func (r {{ .GoName }}Runner) Run(cmd *cobra.Command, args []string) {
        fmt.Printf("Hello %s!\n", r.Name)
}

func New{{ .GoName }}Command() *cobra.Command {
        var runner {{ .GoName }}Runner
        command := &cobra.Command{
                Use:   "{{ ToLower .GoName }}",
                Short: `{{ TrimComments .Comments.Leading }}`,
                Run:   runner.Run,
        }

        {{ range .Input.Fields -}}
                command.Flags().{{ FlagName .Desc.Kind }}(&runner.{{ .GoName }}, "{{ ToLower .GoName }}", "", "", "{{ TrimComments .Comments.Leading }}")
        {{ end }}

        return command
}
{{ end }}
```

```
% go install github.com/dane/protoc-plugin-example/cmd/protoc-gen-go-example
% protoc -I proto --go-example_opt=paths=source_relative,verbose=true --go-example_out=proto/go/v1 hello_world.proto
2021/09/25 19:43:24 Writing hello_world.proto -> hello_world.go
% ls proto/go/v1/
hello_world.go
```

```
// file: proto/go/v1/hello_world.go
// Code generated by protoc-gen-go-example. DO NOT EDIT.

package v1

import (
        "fmt"

        "github.com/spf13/cobra"
)

var All = []*cobra.Command{
        NewSayCommand(),
}

type SayRunner struct {
        Name string
}

func (r SayRunner) Run(cmd *cobra.Command, args []string) {
        fmt.Printf("Hello %s!\n", r.Name)
}

func NewSayCommand() *cobra.Command {
        var runner SayRunner
        command := &cobra.Command{
                Use:   "say",
                Short: `Say accepts a name from input and returns a "Hello {name}!" string.`,
                Run:   runner.Run,
        }

        command.Flags().StringVarP(&runner.Name, "name", "", "", "name is the name of the person to be greeted.")

        return command
}
```

```
file: cmd/hello-world/main.go
package main

import (
        "fmt"
        "os"

        "github.com/spf13/cobra"

        "github.com/dane/protoc-plugin-example/proto/go/v1"
)

func main() {
        rootCmd := &cobra.Command{
                Use:   "hello-world",
                Short: "Interact with HelloWorld service",
        }

        for _, command := range v1.All {
                rootCmd.AddCommand(command)
        }

        if err := rootCmd.Execute(); err != nil {
                fmt.Fprintln(os.Stderr, err)
                os.Exit(1)
        }
}
```

```
% go build -o bin/hello-world ./cmd/hello-world/main.go
% bin/hello-world
Interact with HelloWorld service

Usage:
  hello-world [command]

Available Commands:
  completion  generate the autocompletion script for the specified shell
  help        Help about any command
  say         Say accepts a name from input and returns a "Hello {name}!" string.

Flags:
  -h, --help   help for hello-world

Use "hello-world [command] --help" for more information about a command.
```

```
% bin/hello-world say --help
Say accepts a name from input and returns a "Hello {name}!" string.

Usage:
  hello-world say [flags]

Flags:
  -h, --help          help for say
      --name string   name is the name of the person to be greeted.
```

```
% bin/hello-world say --name Dane
Dane!
```
