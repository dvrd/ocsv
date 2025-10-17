# OCSV Simple Bindings

Ultra-minimal FFI bindings with zero abstraction between JavaScript and Odin.

**Philosophy:** No classes, no wrappers - just functions that return results.

## Installation

```bash
bun install ocsv
```

## Quick Start

```typescript
import { parseCSV } from 'ocsv/bindings/simple'

const rows = parseCSV('name,age\nAlice,30\nBob,25')
// [["name", "age"], ["Alice", "30"], ["Bob", "25"]]
```

## API

### `parseCSV(csvData: string): string[][]`

Parse CSV and return 2D array of strings.

```typescript
const rows = parseCSV('a,b,c\n1,2,3')
// [["a", "b", "c"], ["1", "2", "3"]]
```

### `parseCSVWithHeader(csvData: string): { header: string[], rows: string[][] }`

Parse CSV with separate header and data rows.

```typescript
const { header, rows } = parseCSVWithHeader('name,age\nAlice,30')
// header: ["name", "age"]
// rows: [["Alice", "30"]]
```

### `parseCSVToObjects(csvData: string): Record<string, string>[]`

Parse CSV and return array of objects using first row as keys.

```typescript
const people = parseCSVToObjects('name,age\nAlice,30\nBob,25')
// [{ name: "Alice", age: "30" }, { name: "Bob", age: "25" }]
```

### `getCSVDimensions(csvData: string): { rows: number, avgFields: number }`

Get CSV dimensions without extracting all data.

```typescript
const { rows, avgFields } = getCSVDimensions(csvData)
console.log(`${rows} rows × ${avgFields} fields`)
```

### `getRow(csvData: string, rowIndex: number): string[] | null`

Get specific row by index.

```typescript
const row5 = getRow(csvData, 5)  // 6th row (0-indexed)
```

### `getField(csvData: string, rowIndex: number, fieldIndex: number): string | null`

Get specific field value.

```typescript
const value = getField(csvData, 1, 2)  // Row 1, Column 2
```

### `ffi` - Direct FFI Access

For advanced users who need low-level control:

```typescript
import { ffi } from 'ocsv/bindings/simple'

const parser = ffi.ocsv_parser_create()
try {
  const buffer = Buffer.from(csvData)
  ffi.ocsv_parse_string(parser, buffer, buffer.length)
  const rowCount = ffi.ocsv_get_row_count(parser)
  // ... use parser directly
} finally {
  ffi.ocsv_parser_destroy(parser)
}
```

## Features

✅ **Zero abstraction** - Direct FFI calls
✅ **No classes** - Just functions
✅ **High performance** - 123+ MB/s throughput
✅ **RFC 4180 compliant** - Handles all edge cases
✅ **UTF-8 support** - CJK, emojis, etc.
✅ **Quoted fields** - Handles commas, quotes, newlines
✅ **Memory safe** - Zero leaks

## Performance

Tested with 10 million rows (661 MB):

- **Throughput:** 123.05 MB/s
- **Rows/sec:** 1,859,110
- **Time/row:** 538 nanoseconds

## Edge Cases

All RFC 4180 edge cases are handled:

```typescript
// Quoted fields with commas
const csv1 = '"Smith, John",30,"New York, NY"'

// Nested quotes (doubled)
const csv2 = '"He said ""Hello"""'

// Multiline fields
const csv3 = `name,bio
"Alice","Line 1
Line 2
Line 3"`

// UTF-8
const csv4 = 'name,city\n山田太郎,東京\nGarcía,México'

// All handled correctly by parseCSV()
```

## Examples

See [`examples/simple_minimal.ts`](../examples/simple_minimal.ts) for comprehensive examples:

```bash
bun run examples/simple_minimal.ts
```

## Comparison with Wrapper API

| Feature | Simple API | Wrapper API |
|---------|-----------|-------------|
| Abstraction | Zero | High |
| Classes | No | Yes |
| Bundle size | Minimal | Larger |
| Type safety | Basic | Full |
| API surface | 7 functions | ~20 methods |
| Learning curve | Flat | Steeper |
| Use case | Quick scripts | Full apps |

## When to Use

✅ **Use Simple API when:**
- Quick scripts and one-off tasks
- Prototyping and exploration
- Performance is critical
- You want minimal bundle size
- You prefer functional style

❌ **Use Wrapper API when:**
- Building full applications
- Need advanced features (streaming, plugins, schema validation)
- Want IDE autocomplete for all options
- Prefer object-oriented style

## License

MIT
