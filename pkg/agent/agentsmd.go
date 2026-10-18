package agent

import (
	"fmt"
	"os"
	"strings"
)

// MaxAgentsMDBytes bounds the combined always-loaded AGENTS.md context.
const MaxAgentsMDBytes = 64 << 10

// LoadAgentsMD reads AGENTS.md files in order and combines them into one
// system-prompt section. The result is bounded by MaxAgentsMDBytes.
func LoadAgentsMD(paths ...string) (string, error) {
	var b strings.Builder
	for _, p := range paths {
		if strings.TrimSpace(p) == "" {
			continue
		}
		raw, err := os.ReadFile(p)
		if err != nil {
			return "", fmt.Errorf("agent: read AGENTS.md %s: %w", p, err)
		}
		text := strings.TrimSpace(string(raw))
		if text == "" {
			continue
		}
		if b.Len() > 0 {
			b.WriteString("\n\n")
		}
		header := fmt.Sprintf("## AGENTS.md: %s\n", p)
		chunk := header + text
		if b.Len()+len(chunk) > MaxAgentsMDBytes {
			remaining := MaxAgentsMDBytes - b.Len()
			if remaining <= len(header) {
				break
			}
			b.WriteString(chunk[:remaining])
			b.WriteString("\n[truncated]")
			break
		}
		b.WriteString(chunk)
	}
	return b.String(), nil
}
