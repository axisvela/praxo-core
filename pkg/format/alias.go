// Package format is deprecated: use pkg/formatter.
package format

import fm "github.com/axisvela/praxo-core/pkg/formatter"

// Formatter describes a code formatter for a specific language.
type Formatter = fm.Formatter

// WatchFormat watches a directory and formats files on change.
type WatchFormat = fm.WatchFormat

// Detect returns the appropriate formatter for a file path.
func Detect(filePath string) *Formatter { return fm.Detect(filePath) }

// Format runs the detected formatter on a file.
func Format(filePath string) (string, error) { return fm.Format(filePath) }

// AllAvailable returns all formatters installed on the system.
func AllAvailable() []Formatter { return fm.AllAvailable() }

// List returns all registered formatters.
func List() []Formatter { return fm.List() }

// NewWatch returns a directory formatter watcher.
func NewWatch(dir string) *WatchFormat { return fm.NewWatch(dir) }
