package conformance

import (
	"context"
	"errors"
	"fmt"
	"path"
	"strings"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

var sequence atomic.Uint64

func uniqueName(prefix string) string {
	return fmt.Sprintf("%s-%d-%d", prefix, time.Now().UnixNano(), sequence.Add(1))
}

// CheckVFSBackend verifies the generic vfs.Backend contract: write, stat,
// read, list, glob, grep, delete, recursive delete, and ErrNotFound. It uses a
// unique virtual directory and removes it before returning.
func CheckVFSBackend(ctx context.Context, backend vfs.Backend) error {
	if backend == nil {
		return errors.New("conformance: vfs backend is nil")
	}
	root := uniqueName("praxo-conformance")
	defer func() {
		_ = backend.Delete(ctx, root, true)
	}()

	file := path.Join(root, "a.txt")
	content := []byte("praxo conformance")
	if err := backend.Write(ctx, file, content); err != nil {
		return fmt.Errorf("conformance: vfs write: %w", err)
	}
	entry, err := backend.Stat(ctx, file)
	if err != nil {
		return fmt.Errorf("conformance: vfs stat: %w", err)
	}
	if entry.IsDir || entry.Size != int64(len(content)) {
		return fmt.Errorf("conformance: vfs stat = %#v", entry)
	}
	data, err := backend.Read(ctx, file)
	if err != nil {
		return fmt.Errorf("conformance: vfs read: %w", err)
	}
	if string(data) != string(content) {
		return fmt.Errorf("conformance: vfs read = %q", data)
	}
	list, err := backend.List(ctx, root)
	if err != nil {
		return fmt.Errorf("conformance: vfs list: %w", err)
	}
	if !hasEntry(list, "a.txt") {
		return fmt.Errorf("conformance: vfs list missing a.txt: %#v", list)
	}
	matches, err := backend.Glob(ctx, path.Join(root, "*.txt"))
	if err != nil {
		return fmt.Errorf("conformance: vfs glob: %w", err)
	}
	if !hasPath(matches, file) {
		return fmt.Errorf("conformance: vfs glob missing %s: %#v", file, matches)
	}
	grep, err := backend.Grep(ctx, "conformance", root)
	if err != nil {
		return fmt.Errorf("conformance: vfs grep: %w", err)
	}
	if !hasMatch(grep, "a.txt", "conformance") {
		return fmt.Errorf("conformance: vfs grep missing a.txt: %#v", grep)
	}
	if err := backend.Delete(ctx, file, false); err != nil {
		return fmt.Errorf("conformance: vfs delete: %w", err)
	}
	if _, err := backend.Stat(ctx, file); !errors.Is(err, vfs.ErrNotFound) {
		return fmt.Errorf("conformance: vfs stat after delete = %v, want ErrNotFound", err)
	}
	nested := path.Join(root, "nested", "b.txt")
	if err := backend.Write(ctx, nested, content); err != nil {
		return fmt.Errorf("conformance: vfs nested write: %w", err)
	}
	if err := backend.Delete(ctx, root, true); err != nil {
		return fmt.Errorf("conformance: vfs recursive delete: %w", err)
	}
	if _, err := backend.Stat(ctx, nested); !errors.Is(err, vfs.ErrNotFound) {
		return fmt.Errorf("conformance: vfs stat after recursive delete = %v, want ErrNotFound", err)
	}
	return nil
}

func hasEntry(entries []vfs.Entry, name string) bool {
	for _, entry := range entries {
		if entry.Name == name {
			return true
		}
	}
	return false
}

func hasPath(paths []string, want string) bool {
	for _, candidate := range paths {
		if path.Clean(candidate) == path.Clean(want) || path.Base(candidate) == path.Base(want) {
			return true
		}
	}
	return false
}

func hasMatch(matches []vfs.Match, name, text string) bool {
	for _, match := range matches {
		if path.Base(match.Path) == name && strings.Contains(match.Text, text) {
			return true
		}
	}
	return false
}

// CheckMemoryStore verifies the generic memory.Store contract: Put then
// Search by query, session isolation, and a respected result limit.
func CheckMemoryStore(ctx context.Context, store memory.Store) error {
	if store == nil {
		return errors.New("conformance: memory store is nil")
	}
	token := uniqueName("praxo-conformance-token")
	session := uniqueName("praxo-conformance-session")
	other := session + "-other"
	first := memory.Record{
		ID:      uniqueName("record"),
		Frame:   memory.FrameExperience,
		Content: "use " + token,
	}
	if err := store.Put(ctx, session, first); err != nil {
		return fmt.Errorf("conformance: memory put: %w", err)
	}
	second := memory.Record{
		ID:      uniqueName("record"),
		Frame:   memory.FrameExperience,
		Content: "also " + token,
	}
	if err := store.Put(ctx, session, second); err != nil {
		return fmt.Errorf("conformance: memory second put: %w", err)
	}
	results, err := store.Search(ctx, session, token, 10)
	if err != nil {
		return fmt.Errorf("conformance: memory search: %w", err)
	}
	if !hasRecord(results, first.ID) {
		return fmt.Errorf("conformance: memory search missing %s: %#v", first.ID, results)
	}
	otherResults, err := store.Search(ctx, other, token, 10)
	if err != nil {
		return fmt.Errorf("conformance: memory other-session search: %w", err)
	}
	if len(otherResults) != 0 {
		return fmt.Errorf("conformance: memory session isolation returned %#v", otherResults)
	}
	limited, err := store.Search(ctx, session, token, 1)
	if err != nil {
		return fmt.Errorf("conformance: memory limited search: %w", err)
	}
	if len(limited) > 1 {
		return fmt.Errorf("conformance: memory limit returned %d records", len(limited))
	}
	return nil
}

func hasRecord(records []memory.Record, id string) bool {
	for _, record := range records {
		if record.ID == id {
			return true
		}
	}
	return false
}
