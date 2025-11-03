# OCSV Binary Packed Format Specification

**Version:** 1.0
**Status:** Stable
**Last Updated:** 2025-11-03

## Overview

The OCSV Binary Packed Format is a zero-copy, memory-efficient serialization format for CSV data. It is designed for high-performance FFI (Foreign Function Interface) data transfer between Odin native code and Bun JavaScript runtime.

### Key Features

- **Zero-copy deserialization** - Direct memory access using `toArrayBuffer()`
- **Type-safe** - Structured header with validation
- **UTF-8 native** - Efficient string encoding
- **Version-aware** - Forward/backward compatibility support
- **Performance** - 52.32 MB/s throughput (84.6% of native baseline)

### Use Cases

- Large CSV files (>1000 rows)
- FFI data transfer with minimal overhead
- Memory-constrained environments
- High-throughput parsing pipelines

---

## Binary Format Layout

```
┌─────────────────────────────────────────────────────────────┐
│                        HEADER (24 bytes)                     │
├─────────────────────────────────────────────────────────────┤
│                   ROW OFFSETS (row_count × 4)                │
├─────────────────────────────────────────────────────────────┤
│                       FIELD DATA (variable)                  │
│  ┌────────────┬──────────────┬────────────┬──────────────┐  │
│  │ len (u16)  │ UTF-8 bytes  │ len (u16)  │ UTF-8 bytes  │  │
│  └────────────┴──────────────┴────────────┴──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Header Structure (24 bytes)

| Offset | Size | Type   | Name         | Description                          |
|--------|------|--------|--------------|--------------------------------------|
| 0      | 4    | u32    | magic        | Magic number: `0x4F435356` ("OCSV") |
| 4      | 4    | u32    | version      | Format version: `1`                  |
| 8      | 4    | u32    | row_count    | Number of rows in dataset            |
| 12     | 4    | u32    | field_count  | Number of fields per row             |
| 16     | 8    | u64    | total_bytes  | Total buffer size (including header) |

### Header Fields

#### `magic` (u32, little-endian)
- **Value:** `0x4F435356` (ASCII: "OCSV")
- **Purpose:** Format identification and validation
- **Validation:** Must match exactly, otherwise throw error

#### `version` (u32, little-endian)
- **Current:** `1`
- **Purpose:** Format version for compatibility checks
- **Validation:** Must be `1` for current implementation

#### `row_count` (u32, little-endian)
- **Range:** `0` to `4,294,967,295`
- **Purpose:** Number of rows to deserialize
- **Validation:** Must match actual row offsets length

#### `field_count` (u32, little-endian)
- **Range:** `0` to `4,294,967,295`
- **Purpose:** Fields per row (constant across all rows)
- **Validation:** Must match actual field count in each row

#### `total_bytes` (u64, little-endian)
- **Range:** `24` to `18,446,744,073,709,551,615`
- **Purpose:** Total buffer size for bounds checking
- **Validation:** Must match `bufferSize` parameter exactly

---

## Row Offsets Array

Immediately follows header at offset `24`.

```
Offset: 24
Size:   row_count × 4 bytes
Type:   u32[] (little-endian)
```

### Structure

Each entry is a 4-byte unsigned integer pointing to the **absolute offset** of the first field in that row.

```
┌─────────┬─────────┬─────────┬─────┬─────────┐
│ row[0]  │ row[1]  │ row[2]  │ ... │ row[n]  │
│ u32     │ u32     │ u32     │     │ u32     │
└─────────┴─────────┴─────────┴─────┴─────────┘
```

### Example

For a 3-row CSV:
```
Offset 24:  [348, 412, 476]
            ↓     ↓     ↓
         Row 0  Row 1  Row 2
```

---

## Field Data Structure

Begins at offset `24 + (row_count × 4)`.

Each field consists of:
1. **Length prefix** - 2 bytes (u16, little-endian)
2. **UTF-8 data** - `length` bytes (variable)

```
┌──────────────┬─────────────────────────────┐
│ length (u16) │  UTF-8 bytes (length bytes) │
└──────────────┴─────────────────────────────┘
```

### Length Prefix

- **Type:** `u16` (little-endian)
- **Range:** `0` to `65,535` bytes
- **Empty fields:** `length = 0` (no UTF-8 data follows)

### UTF-8 Data

- **Encoding:** UTF-8 (variable-length, 1-4 bytes per character)
- **No null terminator** - Length is explicit
- **No padding** - Fields are tightly packed

### Example Field

```
Field: "Hello"
Length: 5 (0x0500 in little-endian)
UTF-8:  0x48 0x65 0x6C 0x6C 0x6F

Binary: [0x05, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F]
         └──┬──┘  └──────────┬──────────┘
          len         UTF-8 bytes
```

### Empty Field

```
Field: ""
Length: 0 (0x0000 in little-endian)
UTF-8:  (none)

Binary: [0x00, 0x00]
         └──┬──┘
          len=0
```

---

## Complete Example

### Input CSV

```csv
name,age,city
Alice,30,NYC
Bob,25,LA
```

### Binary Layout

```
Header (24 bytes):
  magic:        0x4F435356  ("OCSV")
  version:      0x00000001  (1)
  row_count:    0x00000003  (3 rows)
  field_count:  0x00000003  (3 fields)
  total_bytes:  0x...       (calculated)

Row Offsets (12 bytes = 3 rows × 4):
  row[0]: 36  (header + offsets)
  row[1]: 52
  row[2]: 65

Field Data:
  # Row 0: ["name", "age", "city"]
  Offset 36:  [0x04, 0x00] "name"  (4 bytes)
  Offset 42:  [0x03, 0x00] "age"   (3 bytes)
  Offset 47:  [0x04, 0x00] "city"  (4 bytes)

  # Row 1: ["Alice", "30", "NYC"]
  Offset 52:  [0x05, 0x00] "Alice" (5 bytes)
  Offset 59:  [0x02, 0x00] "30"    (2 bytes)
  Offset 63:  [0x03, 0x00] "NYC"   (3 bytes)

  # Row 2: ["Bob", "25", "LA"]
  Offset 68:  [0x03, 0x00] "Bob"   (3 bytes)
  Offset 73:  [0x02, 0x00] "25"    (2 bytes)
  Offset 77:  [0x02, 0x00] "LA"    (2 bytes)
```

---

## Validation Rules

### Required Validations

1. **Magic Number** - Must be `0x4F435356`
2. **Version** - Must be `1` (current version)
3. **Buffer Size** - `total_bytes` must match actual buffer size
4. **Row Offsets** - All offsets must be within buffer bounds
5. **Field Lengths** - All field lengths must be within remaining buffer

### Error Handling

```javascript
// Invalid magic number
if (magic !== 0x4F435356) {
    throw new Error(`Invalid magic number: 0x${magic.toString(16)}`);
}

// Unsupported version
if (version !== 1) {
    throw new Error(`Unsupported version: ${version}`);
}

// Buffer size mismatch
if (BigInt(bufferSize) !== totalBytes) {
    throw new Error(`Buffer size mismatch: expected ${totalBytes}, got ${bufferSize}`);
}
```

---

## Deserialization Algorithm

### JavaScript Implementation

```javascript
function deserializePackedBuffer(bufferPtr, bufferSize) {
    // 1. Convert pointer to ArrayBuffer (zero-copy)
    const arrayBuffer = toArrayBuffer(bufferPtr, 0, bufferSize);
    const view = new DataView(arrayBuffer);
    const bytes = new Uint8Array(arrayBuffer);

    // 2. Read and validate header
    const magic = view.getUint32(0, true);
    if (magic !== 0x4F435356) throw new Error("Invalid magic");

    const version = view.getUint32(4, true);
    if (version !== 1) throw new Error("Unsupported version");

    const rowCount = view.getUint32(8, true);
    const fieldCount = view.getUint32(12, true);
    const totalBytes = view.getBigUint64(16, true);

    if (BigInt(bufferSize) !== totalBytes) throw new Error("Size mismatch");

    // 3. Read row offsets
    const rowOffsets = new Uint32Array(rowCount);
    for (let i = 0; i < rowCount; i++) {
        rowOffsets[i] = view.getUint32(24 + i * 4, true);
    }

    // 4. Deserialize rows
    const rows = new Array(rowCount);
    const decoder = new TextDecoder('utf-8');

    for (let i = 0; i < rowCount; i++) {
        const row = new Array(fieldCount);
        let offset = rowOffsets[i];

        for (let j = 0; j < fieldCount; j++) {
            const length = view.getUint16(offset, true);
            offset += 2;

            if (length > 0) {
                const fieldBytes = bytes.subarray(offset, offset + length);
                row[j] = decoder.decode(fieldBytes);
                offset += length;
            } else {
                row[j] = "";
            }
        }
        rows[i] = row;
    }

    return rows;
}
```

### Odin Serialization (Reference)

Located in `src/ffi_bindings.odin`:

```odin
@(export, link_name="ocsv_rows_to_packed_buffer")
ocsv_rows_to_packed_buffer :: proc "c" (parser_ptr: rawptr, out_size: ^c.int) -> rawptr {
    context = runtime.default_context()

    parser := cast(^Parser)parser_ptr
    if parser == nil || len(parser.all_rows) == 0 {
        out_size^ = 0
        return nil
    }

    // Calculate total size
    row_count := u32(len(parser.all_rows))
    field_count := u32(len(parser.all_rows[0]))

    header_size :: size_of(u32) * 4 + size_of(u64)  // 24 bytes
    offsets_size := size_of(u32) * row_count

    fields_size := u64(0)
    for row in parser.all_rows {
        for field in row {
            fields_size += size_of(u16) + u64(len(field))
        }
    }

    total_size := u64(header_size) + u64(offsets_size) + fields_size

    // Allocate buffer
    buffer := make([]byte, total_size)

    // Write header
    offset := 0
    write_u32_le(&buffer, &offset, 0x4F435356)  // magic
    write_u32_le(&buffer, &offset, 1)            // version
    write_u32_le(&buffer, &offset, row_count)
    write_u32_le(&buffer, &offset, field_count)
    write_u64_le(&buffer, &offset, total_size)

    // Write row offsets
    row_offset := u32(header_size + offsets_size)
    for i in 0..<row_count {
        write_u32_le(&buffer, &offset, row_offset)

        // Calculate next row offset
        for field in parser.all_rows[i] {
            row_offset += u32(size_of(u16) + len(field))
        }
    }

    // Write field data
    for row in parser.all_rows {
        for field in row {
            write_u16_le(&buffer, &offset, u16(len(field)))
            for b in transmute([]byte)field {
                buffer[offset] = b
                offset += 1
            }
        }
    }

    out_size^ = c.int(total_size)
    return raw_data(buffer)
}
```

---

## Performance Characteristics

### Benchmarks (10K rows, 3 fields)

| Operation              | Time      | Throughput |
|------------------------|-----------|------------|
| Native Odin parse      | 4.70 ms   | 61.82 MB/s |
| Packed buffer (FFI)    | 5.56 ms   | 52.32 MB/s |
| Bulk JSON (FFI)        | 7.15 ms   | 40.68 MB/s |
| Field-by-field (FFI)   | 9.83 ms   | 29.58 MB/s |

### Memory Usage

- **Header:** 24 bytes (constant)
- **Offsets:** `row_count × 4` bytes
- **Fields:** `Σ(field_length + 2)` bytes for all fields
- **Overhead:** ~2% (length prefixes only)

### Advantages

1. **Zero-copy** - Direct ArrayBuffer access, no intermediate buffers
2. **Type-safe** - Structured header with validation
3. **Compact** - Minimal overhead (2 bytes per field)
4. **Fast** - 84.6% of native Odin performance

### Trade-offs

1. **Max field size** - 65,535 bytes (u16 limit)
2. **Contiguous memory** - Entire buffer must fit in memory
3. **No streaming** - Must serialize/deserialize entire dataset

---

## Version History

### Version 1 (Current)

- **Released:** Phase 2 FFI Optimization (2025-11-03)
- **Features:**
  - 24-byte header with magic/version
  - Row offset array for direct access
  - Length-prefixed UTF-8 fields
  - Zero-copy deserialization support

### Future Versions

Potential enhancements for version 2+:
- Compression support (zstd, lz4)
- Column-oriented layout option
- Schema metadata in header
- Streaming support with chunk offsets
- Extended field lengths (u32)

---

## Implementation Notes

### Zero-Copy Requirements

1. **Alignment** - Buffer must be properly aligned for DataView
2. **Lifetime** - Buffer must remain valid during deserialization
3. **Endianness** - Always little-endian (platform-independent)

### UTF-8 Considerations

- **Variable-length** - 1-4 bytes per character
- **No BOM** - Byte Order Mark not included
- **Valid UTF-8** - Decoder will throw on invalid sequences
- **No null bytes** - Length is explicit, null not needed

### Memory Safety

- **Bounds checking** - All offsets validated before access
- **Buffer ownership** - Odin owns buffer, JavaScript borrows
- **Cleanup** - Buffer freed by Odin when parser destroyed

### Best Practices

1. **Validate early** - Check magic/version before processing
2. **Pre-allocate** - Use typed arrays for offsets
3. **Reuse decoder** - Single TextDecoder instance for all fields
4. **Error handling** - Throw descriptive errors on validation failures

---

## References

- **Implementation:** `/src/ffi_bindings.odin` (Odin serialization)
- **Deserialization:** `/bindings/index.js` (JavaScript deserialization)
- **Tests:** `/test-auto-mode.js` (Integration tests)
- **Benchmarks:** `/examples/benchmark_bulk.ts` (Performance tests)

---

## License

MIT License - See [LICENSE](../LICENSE) for details.
