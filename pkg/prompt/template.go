// Package prompt provides variable interpolation for agent prompts.
package prompt

import (
	"fmt"
	"regexp"
	"strings"
)

var variableRE = regexp.MustCompile(`\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}`)

// Template is a prompt template with named variables.
type Template struct {
	ID        string
	Source    string
	Variables []string
}

// New parses a template and records its variables.
func New(id, source string) Template {
	seen := map[string]bool{}
	var vars []string
	for _, match := range variableRE.FindAllStringSubmatch(source, -1) {
		if !seen[match[1]] {
			seen[match[1]] = true
			vars = append(vars, match[1])
		}
	}
	return Template{ID: id, Source: source, Variables: vars}
}

// Format replaces variables and fails on a missing value.
func (t Template) Format(vars map[string]string) (string, error) {
	var missing []string
	out := variableRE.ReplaceAllStringFunc(t.Source, func(token string) string {
		match := variableRE.FindStringSubmatch(token)
		value, ok := vars[match[1]]
		if !ok {
			missing = append(missing, match[1])
			return token
		}
		return value
	})
	if len(missing) > 0 {
		return "", fmt.Errorf("prompt %q missing variables: %s", t.ID, strings.Join(missing, ", "))
	}
	return out, nil
}

// ChatTemplate is a system/human prompt pair.
type ChatTemplate struct {
	ID     string
	System Template
	Human  Template
}

// Format renders both parts.
func (c ChatTemplate) Format(vars map[string]string) (system, human string, err error) {
	system, err = c.System.Format(vars)
	if err != nil {
		return "", "", err
	}
	human, err = c.Human.Format(vars)
	return system, human, err
}
