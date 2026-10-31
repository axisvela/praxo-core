package spec

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

var (
	emailPattern    = regexp.MustCompile(`[A-Za-z0-9._%+\-]+@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})`)
	internalPattern = regexp.MustCompile(`(?i)\b[a-z0-9][a-z0-9.\-]*\.internal\b`)
	allowedDomains  = map[string]bool{
		"axisvela.com":             true,
		"users.noreply.github.com": true,
		"noreply.github.com":       true,
		"example.com":              true,
		"b.com":                    true,
		"d.com":                    true,
	}
)

func TestNoDisallowedEmails(t *testing.T) {
	blocked := blockedDomains()
	for _, file := range workingTreeFiles(t) {
		data, ok := readSmallTextFile(file)
		if !ok {
			continue
		}
		text := string(data)
		for _, match := range emailPattern.FindAllStringSubmatchIndex(text, -1) {
			domain := strings.ToLower(text[match[2]:match[3]])
			if domain == "github.com" && strings.HasSuffix(text[:match[0]], "ssh://") {
				continue
			}
			if blocked[domain] {
				t.Errorf("%s:%d: email domain %q is blocked",
					file, lineNumber(text, match[0]), domain)
				continue
			}
			if allowedDomains[domain] {
				continue
			}
			t.Errorf("%s:%d: email domain %q is not in the public allowlist",
				file, lineNumber(text, match[0]), domain)
		}
	}
}

func TestNoInternalHostnames(t *testing.T) {
	for _, file := range workingTreeFiles(t) {
		data, ok := readSmallTextFile(file)
		if !ok {
			continue
		}
		text := string(data)
		for _, match := range internalPattern.FindAllStringIndex(text, -1) {
			t.Errorf("%s:%d: internal hostname %q must not be published",
				file, lineNumber(text, match[0]), text[match[0]:match[1]])
		}
	}
}

func TestGitHistoryEmails(t *testing.T) {
	blocked := blockedDomains()
	if len(blocked) == 0 {
		t.Skip("set PRAXO_DISALLOWED_EMAIL_DOMAINS to audit commit identities")
	}
	out, err := exec.Command("git", "log", "--all", "--format=%H%x09%ae%x09%ce").Output()
	if err != nil {
		t.Skipf("git history unavailable: %v", err)
	}
	seen := map[string]bool{}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		fields := strings.Split(line, "\t")
		if len(fields) != 3 {
			continue
		}
		for _, email := range fields[1:] {
			at := strings.LastIndex(email, "@")
			if at < 0 {
				continue
			}
			domain := strings.ToLower(email[at+1:])
			if !blocked[domain] || seen[fields[0]+" "+domain] {
				continue
			}
			seen[fields[0]+" "+domain] = true
			t.Errorf("%s: commit identity uses blocked email domain %q", fields[0], domain)
		}
	}
}

func blockedDomains() map[string]bool {
	blocked := map[string]bool{}
	for _, item := range strings.Split(os.Getenv("PRAXO_DISALLOWED_EMAIL_DOMAINS"), ",") {
		if domain := strings.ToLower(strings.TrimSpace(item)); domain != "" {
			blocked[domain] = true
		}
	}
	return blocked
}

func workingTreeFiles(t *testing.T) []string {
	t.Helper()
	root := repoRoot(t)
	command := exec.Command("git", "ls-files", "--cached", "--others", "--exclude-standard", "-z")
	command.Dir = root
	out, err := command.Output()
	if err != nil {
		t.Skipf("git ls-files unavailable: %v", err)
	}
	var files []string
	for _, name := range strings.Split(string(out), "\x00") {
		if name != "" {
			files = append(files, filepath.Join(root, filepath.FromSlash(name)))
		}
	}
	return files
}

func TestPrivacyFileDiscovery(t *testing.T) {
	root := repoRoot(t)
	file, err := os.CreateTemp(root, "privacy-scan-test-*.txt")
	if err != nil {
		t.Fatal(err)
	}
	name := file.Name()
	if err := file.Close(); err != nil {
		_ = os.Remove(name)
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(name) })
	wanted := map[string]bool{
		filepath.Join(root, "VERSION"): false,
		name:                           false,
	}
	for _, path := range workingTreeFiles(t) {
		if _, ok := wanted[path]; ok {
			wanted[path] = true
		}
	}
	for path, found := range wanted {
		if !found {
			t.Errorf("privacy scan did not discover %s", path)
		}
	}
}

func readSmallTextFile(name string) ([]byte, bool) {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".exe", ".dll", ".so", ".dylib", ".a", ".o", ".class", ".jar",
		".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip", ".gz",
		".woff", ".woff2", ".ttf", ".eot", ".pyc":
		return nil, false
	}
	info, err := os.Stat(name)
	if err != nil || info.Size() > 2<<20 {
		return nil, false
	}
	data, err := os.ReadFile(name)
	return data, err == nil
}

func lineNumber(text string, index int) int {
	return strings.Count(text[:index], "\n") + 1
}
