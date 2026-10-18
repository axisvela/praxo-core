// Package vfstools adapts a vfs.Backend to framework tools.
package vfstools

import (
	"context"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

type baseTool struct {
	name   string
	desc   string
	params map[string]any
	invoke func(context.Context, map[string]any) (any, error)
}

func (t *baseTool) Name() string        { return t.name }
func (t *baseTool) Description() string { return t.desc }
func (t *baseTool) Spec() model.ToolSpec {
	return model.ToolSpec{Name: t.name, Description: t.desc, Parameters: t.params}
}
func (t *baseTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	return t.invoke(ctx, args)
}

func object(props map[string]any, required ...string) map[string]any {
	return map[string]any{"type": "object", "properties": props, "required": required}
}

func str(desc string) map[string]any { return map[string]any{"type": "string", "description": desc} }
func boolean(desc string) map[string]any {
	return map[string]any{"type": "boolean", "description": desc}
}

func stringArg(args map[string]any, key string) string {
	s, _ := args[key].(string)
	return s
}

func boolArg(args map[string]any, key string) bool {
	b, _ := args[key].(bool)
	return b
}

// Tools returns the filesystem tool set backed by b. If b also implements
// vfs.Executor, an fs.execute tool is included.
func Tools(b vfs.Backend) []tool.Tool {
	if b == nil {
		return nil
	}
	tools := []tool.Tool{
		&baseTool{
			name: "fs.list", desc: "List files and directories",
			params: object(map[string]any{"path": str("virtual directory path")}),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				return b.List(ctx, stringArg(args, "path"))
			},
		},
		&baseTool{
			name: "fs.read", desc: "Read a file",
			params: object(map[string]any{"path": str("virtual file path")}, "path"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				data, err := b.Read(ctx, stringArg(args, "path"))
				if err != nil {
					return nil, err
				}
				return string(data), nil
			},
		},
		&baseTool{
			name: "fs.write", desc: "Write a file",
			params: object(map[string]any{"path": str("virtual file path"), "content": str("file content")}, "path", "content"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				path := stringArg(args, "path")
				if err := b.Write(ctx, path, []byte(stringArg(args, "content"))); err != nil {
					return nil, err
				}
				return map[string]any{"path": path, "status": "written"}, nil
			},
		},
		&baseTool{
			name: "fs.edit", desc: "Replace exact text in a file",
			params: object(map[string]any{
				"path": str("virtual file path"), "old": str("text to replace"), "new": str("replacement text"),
				"global": boolean("replace all occurrences"),
			}, "path", "old", "new"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				path := stringArg(args, "path")
				data, err := b.Read(ctx, path)
				if err != nil {
					return nil, err
				}
				old, replacement := stringArg(args, "old"), stringArg(args, "new")
				if old == "" {
					return nil, fmt.Errorf("vfstools: old text is required")
				}
				updated := string(data)
				if boolArg(args, "global") {
					updated = strings.ReplaceAll(updated, old, replacement)
				} else {
					updated = strings.Replace(updated, old, replacement, 1)
				}
				if updated == string(data) {
					return nil, fmt.Errorf("vfstools: old text not found")
				}
				if err := b.Write(ctx, path, []byte(updated)); err != nil {
					return nil, err
				}
				return map[string]any{"path": path, "status": "edited"}, nil
			},
		},
		&baseTool{
			name: "fs.delete", desc: "Delete a file or directory",
			params: object(map[string]any{"path": str("virtual path"), "recursive": boolean("delete recursively")}, "path"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				path := stringArg(args, "path")
				if err := b.Delete(ctx, path, boolArg(args, "recursive")); err != nil {
					return nil, err
				}
				return map[string]any{"path": path, "status": "deleted"}, nil
			},
		},
		&baseTool{
			name: "fs.glob", desc: "Find files by glob pattern (supports **)",
			params: object(map[string]any{"pattern": str("glob pattern")}, "pattern"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				return b.Glob(ctx, stringArg(args, "pattern"))
			},
		},
		&baseTool{
			name: "fs.grep", desc: "Search file contents with a regular expression",
			params: object(map[string]any{"pattern": str("regular expression"), "path": str("virtual file or directory")}, "pattern"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				return b.Grep(ctx, stringArg(args, "pattern"), stringArg(args, "path"))
			},
		},
	}
	if ex, ok := b.(vfs.Executor); ok {
		tools = append(tools, &baseTool{
			name: "fs.execute", desc: "Execute a command in the backend environment",
			params: object(map[string]any{
				"command": map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
				"dir":     str("working directory"),
			}, "command"),
			invoke: func(ctx context.Context, args map[string]any) (any, error) {
				raw, _ := args["command"].([]any)
				command := make([]string, 0, len(raw))
				for _, item := range raw {
					s, ok := item.(string)
					if !ok {
						return nil, fmt.Errorf("vfstools: command must be a string array")
					}
					command = append(command, s)
				}
				return ex.Execute(ctx, command, stringArg(args, "dir"))
			},
		})
	}
	return tools
}
