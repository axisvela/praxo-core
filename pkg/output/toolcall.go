// Package output parses structured output from model responses.
package output

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"
)

// ToolCall is a parsed tool invocation.
type ToolCall struct {
	CallID         string         `json:"call_id"`
	Name           string         `json:"name"`
	Operation      string         `json:"operation"`
	Resource       string         `json:"resource"`
	Risk           string         `json:"risk"`
	Reason         string         `json:"reason"`
	IdempotencyKey string         `json:"idempotency_key,omitempty"`
	Input          map[string]any `json:"input"`
}

// ParseToolCall parses the supported tool-call formats.
func ParseToolCall(content string) *ToolCall {
	var call ToolCall
	if err := json.Unmarshal([]byte(content), &call); err == nil && call.Name != "" {
		call.CallID = newID("tc")
		return &call
	}
	if call := parseDeepSeekDSML(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parseXMLStyle(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parseInvokeStyle(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parseTagStyle(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parseTodoStyle(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parseSkillInstall(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	if call := parsePlainStyle(content); call != nil {
		call.CallID = newID("tc")
		return call
	}
	return nil
}

var (
	dsmlInvokeRE     = regexp.MustCompile(`<｜｜DSML｜｜invoke\s+name="([^"]+)"\s*>`)
	dsmlParamRE      = regexp.MustCompile(`(?s)<｜｜DSML｜｜parameter\s+name="([^"]+)"(?:\s+string="([^"]+)")?\s*>(.*?)</｜｜DSML｜｜parameter>`)
	dsmlSingularRE   = regexp.MustCompile(`(?s)<｜｜DSML｜｜tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</｜｜DSML｜｜tool_call>`)
	xmlToolRE        = regexp.MustCompile(`(?s)<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>`)
	invokeNameRE     = regexp.MustCompile(`<tool_name>\s*([^<]+?)\s*</tool_name>`)
	invokeAttrRE     = regexp.MustCompile(`(?s)<parameters\s+actual="(.*?)">\s*</parameters>`)
	invokeBodyRE     = regexp.MustCompile(`(?s)<parameters>\s*(\{.*?)\s*</parameters>`)
	tagToolRE        = regexp.MustCompile(`(?s)<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)`)
	plainToolRE      = regexp.MustCompile(`(?m)^\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*$`)
	todoParseRE      = regexp.MustCompile(`(?s)<todo_(\w+?)>(.*?)</todo_\w+>`)
	skillInstallRE   = regexp.MustCompile(`(?s)<skill\.install\s+([^>]*)>(.*?)</skill\.install>`)
	excessNewlinesRE = regexp.MustCompile(`\n{3,}`)
)

func parseDeepSeekDSML(content string) *ToolCall {
	if !strings.Contains(content, "<｜｜DSML｜｜") {
		return nil
	}
	if !strings.Contains(content, "<｜｜DSML｜｜tool_calls>") {
		m := dsmlSingularRE.FindStringSubmatch(content)
		if len(m) < 3 {
			return nil
		}
		input, ok := parseInputJSON(m[2])
		if !ok {
			input = map[string]any{"content": strings.TrimSpace(m[2])}
		}
		return &ToolCall{Name: m[1], Input: input}
	}
	invoke := dsmlInvokeRE.FindStringSubmatch(content)
	if len(invoke) < 2 {
		return nil
	}
	input := make(map[string]any)
	for _, match := range dsmlParamRE.FindAllStringSubmatch(content, -1) {
		raw := strings.TrimSpace(match[3])
		var value any
		if err := json.Unmarshal([]byte(raw), &value); err != nil {
			value = raw
		}
		input[match[1]] = value
	}
	return &ToolCall{Name: invoke[1], Input: input}
}

func parseXMLStyle(content string) *ToolCall {
	matches := xmlToolRE.FindAllStringSubmatch(content, -1)
	if len(matches) == 0 {
		return nil
	}
	match := matches[len(matches)-1]
	input, ok := parseInputJSON(match[2])
	if !ok {
		return nil
	}
	return &ToolCall{Name: match[1], Input: input}
}

func parseInvokeStyle(content string) *ToolCall {
	if !strings.Contains(content, "<tool_call_invoke>") {
		return nil
	}
	nameMatch := invokeNameRE.FindStringSubmatch(content)
	if len(nameMatch) < 2 {
		return nil
	}
	raw := ""
	if m := invokeAttrRE.FindStringSubmatch(content); len(m) >= 2 {
		raw = strings.ReplaceAll(m[1], `\"`, `"`)
	} else if m := invokeBodyRE.FindStringSubmatch(content); len(m) >= 2 {
		raw = m[1]
	}
	input := make(map[string]any)
	if strings.TrimSpace(raw) != "" {
		parsed, ok := parseInputJSON(raw)
		if !ok {
			return nil
		}
		input = parsed
	}
	return &ToolCall{Name: strings.TrimSpace(nameMatch[1]), Input: input}
}

func parseTagStyle(content string) *ToolCall {
	matches := tagToolRE.FindAllStringSubmatch(content, -1)
	if len(matches) == 0 {
		return nil
	}
	match := matches[len(matches)-1]
	input, ok := parseInputJSON(match[2])
	if !ok {
		return nil
	}
	return &ToolCall{Name: match[1], Input: input}
}

func parseTodoStyle(content string) *ToolCall {
	if !strings.Contains(content, "<todo_") {
		return nil
	}
	m := todoParseRE.FindStringSubmatch(content)
	if len(m) < 3 {
		return nil
	}
	raw := strings.TrimSpace(m[2])
	input := make(map[string]any)
	if err := json.Unmarshal([]byte(raw), &input); err == nil {
		return &ToolCall{Name: "todo." + m[1], Input: input}
	}
	return &ToolCall{Name: "todo." + m[1], Input: map[string]any{"content": raw}}
}

func parseSkillInstall(content string) *ToolCall {
	if !strings.Contains(content, "<skill.install") {
		return nil
	}
	m := skillInstallRE.FindStringSubmatch(content)
	if len(m) < 3 {
		return nil
	}
	input := make(map[string]any)
	for _, pair := range strings.Split(strings.TrimSpace(m[1]), " ") {
		if pair == "" {
			continue
		}
		kv := strings.SplitN(pair, "=", 2)
		if len(kv) == 2 {
			input[strings.Trim(kv[0], `"`)] = strings.Trim(kv[1], ` "\"`)
		}
	}
	if input["url"] == "" {
		input["name"] = strings.TrimSpace(m[2])
	}
	return &ToolCall{Name: "skill.install", Input: input}
}

func parsePlainStyle(content string) *ToolCall {
	matches := plainToolRE.FindAllStringSubmatch(content, -1)
	if len(matches) == 0 {
		return nil
	}
	match := matches[len(matches)-1]
	if !strings.Contains(match[1], ".") {
		return nil
	}
	input, ok := parseInputJSON(match[2])
	if !ok {
		return nil
	}
	return &ToolCall{Name: match[1], Input: input}
}

var toolMarkupStripREs = []*regexp.Regexp{
	regexp.MustCompile(`(?s)<｜｜DSML｜｜tool_calls>.*?(?:</｜｜DSML｜｜tool_calls>|$)`),
	regexp.MustCompile(`(?s)<｜｜DSML｜｜tool_call\s+name="[^"]+"\s*>.*?(?:</｜｜DSML｜｜tool_call>|$)`),
	regexp.MustCompile(`(?s)<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)`),
	regexp.MustCompile(`(?s)<tool_call_invoke>.*?(?:</tool_call_invoke>|$)`),
	regexp.MustCompile(`(?s)<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)`),
}

// StripToolCallMarkup removes recognized tool-call blocks from assistant text.
func StripToolCallMarkup(content string) string {
	out := content
	for _, re := range toolMarkupStripREs {
		out = re.ReplaceAllString(out, "")
	}
	out = excessNewlinesRE.ReplaceAllString(out, "\n\n")
	return strings.TrimSpace(out)
}

// ParseInputJSON parses a JSON object, tolerating unescaped Windows paths.
func ParseInputJSON(raw string) (map[string]any, bool) {
	return parseInputJSON(raw)
}

func parseInputJSON(raw string) (map[string]any, bool) {
	input := make(map[string]any)
	if err := json.Unmarshal([]byte(strings.TrimSpace(raw)), &input); err == nil {
		return input, true
	}
	escaped := strings.ReplaceAll(raw, `\`, `\\`)
	input = make(map[string]any)
	if err := json.Unmarshal([]byte(strings.TrimSpace(escaped)), &input); err != nil {
		return nil, false
	}
	return input, true
}

func newID(prefix string) string {
	var buf [8]byte
	if _, err := rand.Read(buf[:]); err == nil {
		return prefix + "-" + hex.EncodeToString(buf[:])
	}
	return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
}
