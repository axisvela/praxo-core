// Command gen emits the hermetic WASM fixtures used by the pluginrt WASM host
// tests. It depends on the Go standard library only and is run manually:
//
//	go run ./host/wasm/testdata/gen
//
// The output modules implement the host guest ABI:
//
//	export memory
//	export alloc(len i32) i32
//	export prax_request(ptr, len i32)
//	import env.prax_respond(ptr, len i32)
//
// The modules are intentionally tiny so they can be reviewed and regenerated
// offline with no WASM toolchain installed.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// --- tiny WASM binary encoder -----------------------------------------------

func uleb(v uint32) []byte {
	var out []byte
	for {
		b := byte(v & 0x7f)
		v >>= 7
		if v != 0 {
			out = append(out, b|0x80)
		} else {
			out = append(out, b)
			break
		}
	}
	return out
}

func sleb32(v int32) []byte {
	var out []byte
	for {
		b := byte(v & 0x7f)
		v >>= 7
		sign := b & 0x40
		if (v == 0 && sign == 0) || (v == -1 && sign != 0) {
			out = append(out, b)
			break
		}
		out = append(out, b|0x80)
	}
	return out
}

func vec(items ...[]byte) []byte {
	out := uleb(uint32(len(items)))
	for _, it := range items {
		out = append(out, it...)
	}
	return out
}

func name(s string) []byte {
	out := uleb(uint32(len(s)))
	return append(out, s...)
}

func section(id byte, body []byte) []byte {
	out := []byte{id}
	out = append(out, uleb(uint32(len(body)))...)
	return append(out, body...)
}

// codeBuf accumulates instruction bytes for one function body.
type codeBuf struct{ b []byte }

func (c *codeBuf) raw(bs ...byte) *codeBuf { c.b = append(c.b, bs...); return c }
func (c *codeBuf) end() *codeBuf           { return c.raw(0x0b) }
func (c *codeBuf) i32(v int32) *codeBuf    { return c.raw(0x41).raw(sleb32(v)...) }
func (c *codeBuf) localGet(i uint32) *codeBuf {
	return c.raw(0x20).raw(uleb(i)...)
}
func (c *codeBuf) localSet(i uint32) *codeBuf {
	return c.raw(0x21).raw(uleb(i)...)
}
func (c *codeBuf) globalGet(i uint32) *codeBuf {
	return c.raw(0x23).raw(uleb(i)...)
}
func (c *codeBuf) globalSet(i uint32) *codeBuf {
	return c.raw(0x24).raw(uleb(i)...)
}
func (c *codeBuf) call(i uint32) *codeBuf { return c.raw(0x10).raw(uleb(i)...) }
func (c *codeBuf) loop(bt byte) *codeBuf  { return c.raw(0x03, bt) }
func (c *codeBuf) block(bt byte) *codeBuf { return c.raw(0x02, bt) }
func (c *codeBuf) if_(bt byte) *codeBuf   { return c.raw(0x04, bt) }
func (c *codeBuf) br(label uint32) *codeBuf {
	return c.raw(0x0c).raw(uleb(label)...)
}
func (c *codeBuf) brIf(label uint32) *codeBuf {
	return c.raw(0x0d).raw(uleb(label)...)
}
func (c *codeBuf) load8u(align, off uint32) *codeBuf {
	return c.raw(0x2d).raw(uleb(align)...).raw(uleb(off)...)
}
func (c *codeBuf) store8(align, off uint32) *codeBuf {
	return c.raw(0x3a).raw(uleb(align)...).raw(uleb(off)...)
}
func (c *codeBuf) memoryGrow() *codeBuf { return c.raw(0x40, 0x00) }

func (c *codeBuf) add() *codeBuf { return c.raw(0x6a) }
func (c *codeBuf) sub() *codeBuf { return c.raw(0x6b) }
func (c *codeBuf) eq() *codeBuf  { return c.raw(0x46) }
func (c *codeBuf) eqz() *codeBuf { return c.raw(0x45) }
func (c *codeBuf) geU() *codeBuf { return c.raw(0x4f) }
func (c *codeBuf) drop() *codeBuf {
	return c.raw(0x1a)
}
func (c *codeBuf) unreachable() *codeBuf { return c.raw(0x00) }

// funcBody wraps locals + instructions into a code section entry.
func funcBody(locals []byte, code *codeBuf) []byte {
	entry := append([]byte{}, locals...)
	entry = append(entry, code.b...)
	out := uleb(uint32(len(entry)))
	return append(out, entry...)
}

// one local group.
func localGroup(count uint32, valType byte) []byte {
	return append(uleb(count), valType)
}

// --- module assembly --------------------------------------------------------

const (
	respBase   = 1024
	suffixBase = 2048
	allocBase  = 8192
	idOffset   = 7
	suffixLen  = 25 // len(`","version":1,"ok":true}`) + '\n'
	// growPages is deliberately well below wasm32's hard 65536-page ceiling so
	// that memory.grow SUCCEEDS when no configured limit applies and FAILS
	// (-1) only because of WithMemoryLimitPages. A delta above the ceiling
	// would make the limit test vacuous.
	growPages = 8
	// spinIterations is large enough that concurrent invocations overlap but
	// small enough to keep the test fast.
	spinIterations = 2_000_000
)

var (
	prefixBytes = []byte(`{"id":"`)
	suffixBytes = []byte("\",\"version\":1,\"ok\":true}\n")
)

func check() {
	if string(prefixBytes) != `{"id":"` {
		panic("bad prefix")
	}
	if len(suffixBytes) != suffixLen {
		panic(fmt.Sprintf("suffix length %d != %d", len(suffixBytes), suffixLen))
	}
}

// echoBody appends the response builder: it scans the request frame for the id
// closing quote, copies the id into the response buffer, appends the static
// suffix and calls prax_respond. Locals: 2=p(id end), 3=id_len, 4=i, 5=j.
func echoBody(c *codeBuf) {
	// p = ptr + 7
	c.localGet(0).i32(idOffset).add().localSet(2)
	// block { loop { if load8(p)=='"' break; p++ } }
	c.block(0x40)
	c.loop(0x40)
	c.localGet(2).load8u(0, 0).i32('"').eq().brIf(1)
	c.localGet(2).i32(1).add().localSet(2)
	c.br(0)
	c.end() // loop
	c.end() // block

	// id_len = p - (ptr+7)
	c.localGet(2).localGet(0).i32(idOffset).add().sub().localSet(3)

	// i = 0; copy id
	c.i32(0).localSet(4)
	c.block(0x40)
	c.loop(0x40)
	c.localGet(4).localGet(3).geU().brIf(1)
	c.i32(respBase + idOffset).localGet(4).add()
	c.localGet(0).i32(idOffset).add().localGet(4).add().load8u(0, 0)
	c.store8(0, 0)
	c.localGet(4).i32(1).add().localSet(4)
	c.br(0)
	c.end() // loop
	c.end() // block

	// j = 0; copy suffix
	c.i32(0).localSet(5)
	c.block(0x40)
	c.loop(0x40)
	c.localGet(5).i32(suffixLen).geU().brIf(1)
	c.i32(respBase + idOffset).localGet(3).add().localGet(5).add()
	c.i32(suffixBase).localGet(5).add().load8u(0, 0)
	c.store8(0, 0)
	c.localGet(5).i32(1).add().localSet(5)
	c.br(0)
	c.end() // loop
	c.end() // block

	// prax_respond(respBase, 7+id_len+suffixLen)
	c.i32(respBase).i32(idOffset).localGet(3).add().i32(suffixLen).add().call(0)
}

// buildModule assembles a module. requestBody receives a codeBuf positioned
// after any prologue; the caller appends the function's operations and end.
func buildModule(requestBody func(c *codeBuf)) []byte {
	// Types: 0 = (i32,i32)->(), 1 = (i32)->i32
	typeSec := section(1, vec(
		[]byte{0x60, 0x02, 0x7f, 0x7f, 0x00},
		[]byte{0x60, 0x01, 0x7f, 0x01, 0x7f},
	))

	// Import: env.prax_respond : type 0
	imp := append(name("env"), name("prax_respond")...)
	imp = append(imp, 0x00)
	imp = append(imp, uleb(0)...)
	importSec := section(2, vec(imp))

	// Functions: alloc type1, prax_request type0
	funcSec := section(3, vec(uleb(1), uleb(0)))

	// Memory: min 1 page, no max
	memType := append(uleb(0), uleb(1)...)
	memSec := section(5, vec(memType))

	// Global 0: mut i32 = allocBase
	glob0 := []byte{0x7f, 0x01, 0x41}
	glob0 = append(glob0, sleb32(allocBase)...)
	glob0 = append(glob0, 0x0b)
	// Global 1: mut i32 = 0 (call counter)
	glob1 := []byte{0x7f, 0x01, 0x41, 0x00, 0x0b}
	globalSec := section(6, vec(glob0, glob1))

	// Exports
	expAlloc := append(name("alloc"), 0x00)
	expAlloc = append(expAlloc, uleb(1)...)
	expReq := append(name("prax_request"), 0x00)
	expReq = append(expReq, uleb(2)...)
	expMem := append(name("memory"), 0x02)
	expMem = append(expMem, uleb(0)...)
	exportSec := section(7, vec(expAlloc, expReq, expMem))

	// Code: alloc then prax_request
	alloc := &codeBuf{}
	alloc.globalGet(0)
	alloc.globalGet(0).localGet(0).add().globalSet(0)
	alloc.end()

	req := &codeBuf{}
	requestBody(req)
	req.end()

	noLocals := uleb(0)
	reqLocals := vec(localGroup(4, 0x7f)) // locals 2..5
	codeSec := section(10, vec(
		funcBody(noLocals, alloc),
		funcBody(reqLocals, req),
	))

	// Data: prefix at respBase, suffix at suffixBase
	dataPrefix := append([]byte{0x00, 0x41}, sleb32(respBase)...)
	dataPrefix = append(dataPrefix, 0x0b)
	dataPrefix = append(dataPrefix, uleb(uint32(len(prefixBytes)))...)
	dataPrefix = append(dataPrefix, prefixBytes...)

	dataSuffix := append([]byte{0x00, 0x41}, sleb32(suffixBase)...)
	dataSuffix = append(dataSuffix, 0x0b)
	dataSuffix = append(dataSuffix, uleb(uint32(len(suffixBytes)))...)
	dataSuffix = append(dataSuffix, suffixBytes...)
	dataSec := section(11, vec(dataPrefix, dataSuffix))

	header := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	out := append([]byte{}, header...)
	out = append(out, typeSec...)
	out = append(out, importSec...)
	out = append(out, funcSec...)
	out = append(out, memSec...)
	out = append(out, globalSec...)
	out = append(out, exportSec...)
	out = append(out, codeSec...)
	out = append(out, dataSec...)
	return out
}

func echoRequest(c *codeBuf) { echoBody(c) }

// hangRequest never answers; used to prove the start deadline bounds the
// compilation/instantiation/health sequence.
func hangRequest(c *codeBuf) {
	c.loop(0x40)
	c.br(0)
	c.end()
}

// spinRequest responds to the first request (the health handshake) then spins
// forever on every subsequent request. This lets a host Start cleanly before a
// CPU-bound invocation is cancelled or timed out.
func spinRequest(c *codeBuf) {
	c.globalGet(1)
	c.if_(0x40)
	c.loop(0x40)
	c.br(0)
	c.end()
	// else: first call, record and answer health
	c.raw(0x05) // else
	c.i32(1).globalSet(1)
	echoBody(c)
	c.end() // if
}

// growRequest answers the first request (health) then, on the next, attempts a
// small memory.grow. The delta stays below wasm32's 65536-page ceiling, so the
// grow succeeds unless the runtime's configured page limit rejects it; when the
// limit rejects it the grow returns -1 and the guest traps (fail closed).
func growRequest(c *codeBuf) {
	c.globalGet(1)
	c.if_(0x40)
	c.i32(growPages).memoryGrow()
	c.i32(-1).eq()
	c.if_(0x40)
	c.unreachable()
	c.end()
	echoBody(c)
	c.raw(0x05) // else
	c.i32(1).globalSet(1)
	echoBody(c)
	c.end() // if
}

// slowRequest burns a fixed instruction budget before answering, giving
// concurrent callers a deterministic window to contend for the host.
func slowRequest(c *codeBuf) {
	c.i32(spinIterations).localSet(5)
	c.block(0x40)
	c.loop(0x40)
	c.localGet(5).eqz().brIf(1)
	c.localGet(5).i32(1).sub().localSet(5)
	c.br(0)
	c.end() // loop
	c.end() // block
	echoBody(c)
}

func main() {
	check()
	// Default to the parent directory of this source file (the testdata dir),
	// so `go run ./host/wasm/testdata/gen` is independent of the caller's cwd.
	_, self, _, _ := runtime.Caller(0)
	dir := filepath.Dir(filepath.Dir(self))
	if len(os.Args) > 1 {
		dir = os.Args[1]
	}
	modules := map[string][]byte{
		"echo.wasm": buildModule(echoRequest),
		"hang.wasm": buildModule(hangRequest),
		"spin.wasm": buildModule(spinRequest),
		"grow.wasm": buildModule(growRequest),
		"slow.wasm": buildModule(slowRequest),
	}
	for name, bin := range modules {
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, bin, 0o644); err != nil {
			panic(err)
		}
		fmt.Printf("wrote %s (%d bytes)\n", path, len(bin))
	}
}
