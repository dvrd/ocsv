# CISV Architecture Overview

**Document Date:** 2025-10-12
**Project Version:** v0.0.7
**Purpose:** Comprehensive technical architecture documentation

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Layer Breakdown](#layer-breakdown)
3. [Core Components](#core-components)
4. [SIMD Optimization Layer](#simd-optimization-layer)
5. [Memory Management](#memory-management)
6. [Data Flow](#data-flow)
7. [API Surface](#api-surface)
8. [Build System](#build-system)
9. [Extension Points](#extension-points)
10. [Design Patterns](#design-patterns)
11. [Performance Characteristics](#performance-characteristics)
12. [Platform Support Matrix](#platform-support-matrix)

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │  Node.js App     │  │  CLI Tool        │  │  C App     │ │
│  └────────┬─────────┘  └────────┬─────────┘  └─────┬──────┘ │
└───────────┼────────────────────┼─────────────────────┼───────┘
            │                    │                     │
┌───────────┼────────────────────┼─────────────────────┼───────┐
│           ▼                    ▼                     │       │
│  ┌─────────────────┐  ┌──────────────┐              │       │
│  │  N-API Bindings │  │  CLI Parser  │              │       │
│  │  (cisv_addon.cc)│  │  (main.c)    │              │       │
│  └────────┬────────┘  └──────┬───────┘              │       │
│           │                   │                      │       │
│  Language Bridge Layer        │                      │       │
└───────────┼───────────────────┼──────────────────────┼───────┘
            │                   │                      │
┌───────────┼───────────────────┼──────────────────────┼───────┐
│           ▼                   ▼                      ▼       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 Core C Library                        │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │  cisv_parser.c     │  cisv_transformer.c              │ │
│  │  - Parsing logic   │  - Field transforms              │ │
│  │  - SIMD dispatch   │  - Built-in transforms           │ │
│  │  - Streaming API   │  - Custom transforms             │ │
│  │                    │                                   │ │
│  │  cisv_writer.c     │  cisv_simd.h                     │ │
│  │  - CSV writing     │  - SIMD detection                │ │
│  │  - Format options  │  - Platform-specific intrinsics  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Core Layer (Performance Critical)                          │
└──────────────────────────────────────────────────────────────┘
            │
┌───────────┼──────────────────────────────────────────────────┐
│           ▼                                                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Operating System & Hardware Layer                   │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │  • Memory Mapping (mmap / CreateFileMapping)         │    │
│  │  • File I/O (POSIX / Windows APIs)                   │    │
│  │  • SIMD Instructions (AVX-512 / AVX2 / SSE2 / NEON)  │    │
│  │  • CPU Cache Hierarchy                               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  Platform Layer                                               │
└───────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Performance First**: Every design decision prioritizes speed
2. **Zero-Copy When Possible**: Memory mapping for file access
3. **SIMD Everywhere**: Vectorized operations for hot paths
4. **Cache-Friendly**: Data structures sized for cache lines
5. **Platform Abstraction**: Clean separation for portability

---

## Layer Breakdown

### 1. Core C Library (`cisv/`)

**Purpose:** High-performance CSV processing core
**Language:** C11
**Dependencies:** None (stdlib only)

**Files:**
- `cisv_parser.c` (40KB) - Main parsing logic
- `cisv_parser.h` - Parser API and configuration
- `cisv_transformer.c` (18KB) - Data transformation pipeline
- `cisv_transformer.h` - Transform API
- `cisv_writer.c` (16KB) - CSV writing with SIMD
- `cisv_writer.h` - Writer API
- `cisv_simd.h` - SIMD detection and macros

**Responsibilities:**
- CSV parsing with RFC 4180 support (partial)
- SIMD-accelerated delimiter/quote detection
- Memory-mapped file reading
- Streaming API implementation
- Built-in transformations (uppercase, hash, base64, etc.)
- CSV writing with optimization

### 2. N-API Bridge (`cisv_addon.cc`)

**Purpose:** Node.js integration layer
**Language:** C++17
**Dependencies:** node-addon-api, N-API

**Responsibilities:**
- Expose C API to JavaScript
- Convert JavaScript types to C types
- Handle async operations
- Manage memory between JS and C
- Error propagation to JavaScript
- Callback marshalling

**Key Classes:**
```cpp
class CisvParser : public Napi::ObjectWrap<CisvParser> {
  // Node.js wrapper for cisv_parser
  private:
    cisv_parser* parser_;
    std::vector<std::vector<std::string>> rows_;
    Napi::FunctionReference jsTransform_;
};
```

### 3. JavaScript API Layer

**Files:**
- `index.js` - CommonJS entry point
- `index.mjs` - ESM entry point
- `index.ts` - TypeScript entry point
- `index.d.ts` - TypeScript type definitions

**Responsibilities:**
- High-level API for JavaScript users
- Configuration normalization
- Promise/callback abstraction
- Method chaining support

### 4. CLI Tool

**Entry Point:** `main.c` (compiled with `-DCISV_CLI`)
**Binary:** `cisv_bin`

**Responsibilities:**
- Command-line argument parsing
- File operations
- Output formatting (JSON, CSV, TSV)
- Benchmarking mode
- Column selection
- Row counting

---

## Core Components

### 1. Parser (cisv_parser.c)

#### Configuration Structure

```c
typedef struct cisv_config {
    // Delimiters & Quotes
    char delimiter;              // Field delimiter (default: ',')
    char quote;                  // Quote character (default: '"')
    char escape;                 // Escape char (0 = RFC4180 "")
    char comment;                // Comment line prefix (0 = none)

    // Behavior
    bool skip_empty_lines;       // Skip empty lines
    bool trim;                   // Trim whitespace
    bool relaxed;                // Relaxed parsing mode
    bool skip_lines_with_error;  // Continue on error

    // Limits
    size_t max_row_size;         // Max row size (0 = unlimited)
    int from_line;               // Start line (1-based)
    int to_line;                 // End line (0 = EOF)

    // Callbacks
    cisv_field_cb field_cb;      // Per-field callback
    cisv_row_cb row_cb;          // Per-row callback
    cisv_error_cb error_cb;      // Error callback
    void *user;                  // User data
} cisv_config;
```

#### Parsing Modes

**1. File Parsing** (Memory-Mapped)
```c
int cisv_parser_parse_file(cisv_parser *parser, const char *path);
```
- Uses `mmap()` on Linux/macOS
- Zero-copy when possible
- SIMD-accelerated scanning
- Callbacks for each field/row

**2. Streaming API**
```c
int cisv_parser_write(cisv_parser *parser, const uint8_t *chunk, size_t len);
void cisv_parser_end(cisv_parser *parser);
```
- Chunk-based processing
- 1MB ring buffer
- Handles partial rows across chunks

**3. Row Counting** (Fast Path)
```c
size_t cisv_parser_count_rows(const char *path);
```
- Optimized for speed
- No callback overhead
- SIMD newline detection

#### Parser State Machine

```
┌──────────┐   delimiter    ┌──────────┐
│  FIELD   │ ──────────────>│ NEW_FIELD│
│          │<────────────────│          │
└──────────┘      data       └──────────┘
     │                            │
     │ quote                      │ newline
     │                            │
     ▼                            ▼
┌──────────┐   quote+"     ┌──────────┐
│ IN_QUOTE │ ──────────────>│ NEW_ROW  │
│          │<────────────────│          │
└──────────┘    callback    └──────────┘
```

### 2. SIMD Dispatcher

#### Feature Detection Hierarchy

```c
// Compile-time detection
#ifdef __AVX512F__
    #define cisv_HAVE_AVX512
    #define cisv_VEC_BYTES 64
    typedef __m512i cisv_vec;
#elif defined(__AVX2__)
    #define cisv_HAVE_AVX2
    #define cisv_VEC_BYTES 32
    typedef __m256i cisv_vec;
#elif defined(__SSE2__)
    #define cisv_HAVE_SSE2
    #define cisv_VEC_BYTES 16
    typedef __m128i cisv_vec;
#elif defined(__ARM_NEON)
    #define HAS_NEON
    // ARM-specific handling
#endif
```

#### SIMD Operations

**1. Delimiter Detection**
```c
// Find delimiter positions in 64-byte chunk (AVX-512)
__m512i chunk = _mm512_loadu_si512(data);
__m512i delim = _mm512_set1_epi8(',');
uint64_t mask = _mm512_cmpeq_epi8_mask(chunk, delim);
// Process 64 characters in parallel
```

**2. Quote Detection**
```c
// Find quote characters
__m512i quotes = _mm512_set1_epi8('"');
uint64_t quote_mask = _mm512_cmpeq_epi8_mask(chunk, quotes);
```

**3. Newline Detection**
```c
// Find \n or \r\n
__m512i lf = _mm512_set1_epi8('\n');
__m512i cr = _mm512_set1_epi8('\r');
uint64_t newline_mask = _mm512_cmpeq_epi8_mask(chunk, lf) |
                        _mm512_cmpeq_epi8_mask(chunk, cr);
```

### 3. Transformer (cisv_transformer.c)

#### Built-in Transforms (C Implementation)

```c
typedef enum {
    TRANSFORM_UPPERCASE,
    TRANSFORM_LOWERCASE,
    TRANSFORM_TRIM,
    TRANSFORM_TO_INT,
    TRANSFORM_TO_FLOAT,
    TRANSFORM_HASH_SHA256,
    TRANSFORM_BASE64_ENCODE,
} cisv_transform_type;
```

**Performance Characteristics:**
- **C transforms**: Near-zero overhead
- **JS transforms**: ~10-50x slower (V8 boundary crossing)
- **SIMD potential**: uppercase/lowercase can use SIMD

#### Transform Pipeline

```
Input Row: ["John", "  25  ", "NYC"]
           │
           ├─> Field 0: uppercase    -> "JOHN"
           ├─> Field 1: trim + to_int -> 25
           └─> Field 2: (no transform) -> "NYC"
           │
Output Row: ["JOHN", 25, "NYC"]
```

#### Custom JavaScript Transforms

```javascript
parser.transform(0, (value) => value.toUpperCase());
parser.transform(1, (value) => parseInt(value.trim()));
parser.transform(-1, (value) => value.replace(/[^\w\s]/g, ''));
```

### 4. Writer (cisv_writer.c)

#### Writer Configuration

```c
typedef struct {
    char delimiter;
    char quote;
    bool quote_all;          // Quote every field
    bool use_crlf;           // Windows line endings
    const char *null_value;  // Representation for NULL
} cisv_writer_config;
```

#### Writing Modes

**1. Direct Write**
```c
void cisv_writer_write_row(cisv_writer *w, const char **fields, size_t n);
```

**2. Buffered Write**
- Internal 64KB buffer
- SIMD-optimized quoting check
- Batch writes to reduce syscalls

---

## SIMD Optimization Layer

### Detection Strategy

**Compile-Time Detection:**
```bash
gcc -march=native  # Detects CPU features at compile time
```

**Runtime Detection** (Future):
```c
bool has_avx512 = __builtin_cpu_supports("avx512f");
bool has_avx2 = __builtin_cpu_supports("avx2");
// Function pointer dispatch
```

### Optimization Hot Paths

**1. Find Delimiter (95% of parse time)**
```c
// Scalar version (baseline)
for (size_t i = 0; i < len; i++) {
    if (data[i] == delimiter) {
        // Handle field
    }
}

// SIMD version (AVX-512)
while (len >= 64) {
    __m512i chunk = _mm512_loadu_si512(data);
    __m512i delim = _mm512_set1_epi8(delimiter);
    uint64_t mask = _mm512_cmpeq_epi8_mask(chunk, delim);

    if (mask) {
        // Process delimiters (64 chars checked in parallel)
        int pos = __builtin_ctzll(mask);
        // Handle field at data[pos]
    }

    data += 64;
    len -= 64;
}
```

**Performance Impact:**
- **Scalar**: ~1 char/cycle
- **SIMD (AVX-512)**: ~64 chars/cycle
- **Speedup**: ~40-50x (accounting for overhead)

**2. Quote Handling**

Similar SIMD strategy for finding quote boundaries in O(n/64) time.

**3. Memory Copying**

```c
// Use SIMD for field copying (future optimization)
_mm512_storeu_si512(dest, _mm512_loadu_si512(src));
```

### Cache Optimization

**Ring Buffer Design:**
```
┌─────────────────────────────────┐
│   1MB Ring Buffer (L3 cache)    │
│                                  │
│  ┌──────────┐  ┌──────────┐     │
│  │ Chunk 1  │  │ Chunk 2  │  ...│
│  └──────────┘  └──────────┘     │
└─────────────────────────────────┘
```

- Size chosen for L3 cache (typically 8-32MB)
- Reduces cache misses
- Enables prefetching

---

## Memory Management

### Memory Mapping Strategy

**Linux/macOS:**
```c
int fd = open(path, O_RDONLY);
struct stat st;
fstat(fd, &st);
void *data = mmap(NULL, st.st_size, PROT_READ,
                  MAP_PRIVATE | MAP_POPULATE, fd, 0);

#ifdef __linux__
    posix_fadvise(fd, 0, st.st_size, POSIX_FADV_SEQUENTIAL);
#endif
```

**Advantages:**
- Zero-copy from kernel to userspace
- OS handles paging
- Prefetching hints (`MAP_POPULATE`, `POSIX_FADV_SEQUENTIAL`)

**Fallbacks:**
```c
// For streams or pipes
char buffer[1024*1024];  // 1MB buffer
size_t n = read(fd, buffer, sizeof(buffer));
```

### Node.js Memory Management

**V8 Heap:**
- JavaScript strings are UTF-16
- Conversion overhead from UTF-8 (CSV) to UTF-16 (JS)

**Native Heap:**
- Parser state: ~1KB per parser instance
- Row buffer: ~1MB for large rows
- Memory-mapped file: Shared with OS

**Memory Profile** (parsing 100MB CSV):
```
V8 Heap:    ~200MB (parsed rows as JS arrays)
Native:     ~102MB (mmap + parser state)
Total:      ~302MB
Peak RSS:   ~350MB (with overhead)
```

**Optimization Opportunities:**
- Streaming to avoid accumulation
- External strings (V8 feature)
- Shared buffers

---

## Data Flow

### Parse File Flow

```
User Code
   │
   ├─> parser.parseSync("data.csv")
   │
   ▼
JavaScript Wrapper (index.js)
   │
   ├─> Normalize config
   │
   ▼
N-API Bridge (cisv_addon.cc)
   │
   ├─> Convert JS config → cisv_config
   ├─> Create cisv_parser
   │
   ▼
Core Parser (cisv_parser.c)
   │
   ├─> mmap(data.csv)
   ├─> SIMD scan for delimiters
   ├─> Callbacks for each field
   │     │
   │     ▼
   │   N-API Bridge
   │     │
   │     ├─> Accumulate into std::vector
   │     └─> Apply transforms
   │
   ├─> munmap()
   │
   ▼
Return to JavaScript
   │
   └─> Array of arrays [[...], [...]]
```

### Transform Flow

```
Input: "  HELLO  "
   │
   ▼
Check transform registry
   │
   ├─> C transform? → Apply immediately (fast)
   │                  └─> Result: "HELLO"
   │
   └─> JS transform? → Call JavaScript function
                       │
                       ├─> Cross V8 boundary (slow)
                       ├─> Execute JS code
                       └─> Return result
```

**Performance Comparison:**
- C transform: ~10ns per field
- JS transform: ~500ns per field (50x slower)

### Streaming Flow

```
Input Stream (chunks)
   │
   ├─> chunk 1 (1MB)
   │     │
   │     ├─> parser.write(chunk1)
   │     │     │
   │     │     ├─> Append to ring buffer
   │     │     ├─> Scan for complete rows
   │     │     └─> Emit row callbacks
   │     │
   ├─> chunk 2 (1MB)
   │     │
   │     └─> ... (repeat)
   │
   └─> End of stream
         │
         └─> parser.end()
               │
               ├─> Flush remaining data
               └─> Final row callback
```

---

## API Surface

### C API

**Configuration:**
```c
void cisv_config_init(cisv_config *cfg);
```

**Parser Lifecycle:**
```c
cisv_parser *cisv_parser_create_with_config(const cisv_config *cfg);
int cisv_parser_parse_file(cisv_parser *p, const char *path);
void cisv_parser_destroy(cisv_parser *p);
```

**Streaming:**
```c
int cisv_parser_write(cisv_parser *p, const uint8_t *data, size_t len);
void cisv_parser_end(cisv_parser *p);
```

**Utilities:**
```c
size_t cisv_parser_count_rows(const char *path);
int cisv_parser_get_line_number(const cisv_parser *p);
```

### JavaScript API

**Class: cisvParser**

**Constructor:**
```typescript
new cisvParser(config?: CisvConfig)
```

**Parsing Methods:**
```typescript
parseSync(path: string): ParsedRow[]
parse(path: string): Promise<ParsedRow[]>
parseString(csv: string): ParsedRow[]
```

**Streaming Methods:**
```typescript
write(chunk: Buffer | string): void
end(): void
getRows(): ParsedRow[]
clear(): void
```

**Configuration:**
```typescript
setConfig(config: CisvConfig): void
getConfig(): CisvConfig
```

**Transforms:**
```typescript
transform(field: number | string,
          transform: TransformType | FieldTransformFn,
          context?: TransformContext): this
transformRow(transform: RowTransformFn): this
removeTransform(field: number | string): this
clearTransforms(): this
```

**Statistics:**
```typescript
getStats(): ParseStats
getTransformInfo(): TransformInfo
```

**Static Methods:**
```typescript
static countRows(path: string): number
static countRowsWithConfig(path: string, config?: CisvConfig): number
```

### CLI API

```bash
cisv_bin [OPTIONS] [FILE]

Options:
  -d, --delimiter CHAR    Field delimiter
  -q, --quote CHAR        Quote character
  -t, --trim              Trim whitespace
  -c, --count             Count rows only
  -s, --select COLS       Select columns (0,2,5)
  --head N                First N rows
  --tail N                Last N rows
  -b, --benchmark         Benchmark mode
```

---

## Build System

### Makefile (CLI Build)

**Targets:**
- `make cli` - Build standalone CLI tool
- `make tests` - Build C test suite
- `make test-c` - Run C tests
- `make benchmark-cli` - CLI benchmarks
- `make clean` - Remove build artifacts

**Compilation Flags:**
```makefile
CFLAGS = -O3 -march=native -mavx2 -mtune=native \
         -pipe -fomit-frame-pointer \
         -Wall -Wextra -std=c11 \
         -flto -ffast-math -funroll-loops
```

**Flag Explanation:**
- `-O3`: Maximum optimization
- `-march=native`: CPU-specific optimizations
- `-mavx2`: Enable AVX2 instructions
- `-flto`: Link-time optimization
- `-ffast-math`: Aggressive math optimizations
- `-funroll-loops`: Loop unrolling

### node-gyp (Node.js Addon Build)

**binding.gyp:**
```python
{
  'targets': [{
    'target_name': 'cisv',
    'sources': [
      'cisv/cisv_parser.c',
      'cisv/cisv_transformer.c',
      'cisv/cisv_writer.c',
      'cisv/cisv_addon.cc'
    ],
    'cflags': ['-O3', '-march=native', '-mavx2'],
    'cflags_cc': ['-O3', '-march=native', '-mavx2'],
    'include_dirs': ["<!@(node -p \"require('node-addon-api').include\")"],
    'dependencies': ["<!(node -p \"require('node-addon-api').gyp\")"],
  }]
}
```

**Build Commands:**
```bash
npm install          # Runs node-gyp rebuild
node-gyp configure   # Generate Makefiles
node-gyp build       # Compile addon
node-gyp clean       # Remove build/
```

---

## Extension Points

### 1. Custom Transforms (JavaScript)

```javascript
parser.transform(0, (value) => {
    // Custom transformation logic
    return value.toUpperCase();
});
```

### 2. Custom Transforms (Native C)

```c
// Future: Plugin API for native transforms
typedef void (*transform_fn)(char *data, size_t len, void *ctx);

void register_transform(const char *name, transform_fn fn) {
    // Register custom C transform
}
```

### 3. Row Transforms

```javascript
parser.transformRow((row, rowObj) => {
    // Filter rows
    if (rowObj.age < 18) return null;

    // Modify rows
    row.push(Date.now());
    return row;
});
```

### 4. Error Handlers

```c
void error_callback(void *user, int line, const char *msg) {
    fprintf(stderr, "Error on line %d: %s\n", line, msg);
    // Custom error handling
}
```

### 5. Custom Output Formats (CLI)

**Future:**
```bash
cisv_bin --format json data.csv
cisv_bin --format parquet data.csv
cisv_bin --format avro data.csv
```

---

## Design Patterns

### 1. Strategy Pattern (Parsing Modes)

```c
// Different parsing strategies
typedef int (*parse_strategy)(cisv_parser *p, const char *data, size_t len);

// File parsing strategy (mmap)
int parse_file_strategy(cisv_parser *p, const char *path) { ... }

// Streaming strategy (chunked)
int parse_stream_strategy(cisv_parser *p, const char *data, size_t len) { ... }
```

### 2. Callback Pattern (Events)

```c
// Observer pattern via callbacks
typedef void (*cisv_field_cb)(void *user, const char *data, size_t len);
typedef void (*cisv_row_cb)(void *user);

// Client registers callbacks
parser->config.field_cb = my_field_handler;
parser->config.row_cb = my_row_handler;
```

### 3. Builder Pattern (Configuration)

```javascript
const parser = new cisvParser()
    .setConfig({ delimiter: ';', trim: true })
    .transform(0, 'uppercase')
    .transform(1, 'to_int')
    .transformRow((row) => row.filter(Boolean));
```

### 4. Template Method (Transform Pipeline)

```c
// Template for transform processing
void process_field(char *field, transform_list *transforms) {
    for (transform *t = transforms->head; t != NULL; t = t->next) {
        if (t->type == TRANSFORM_C) {
            // Native transform (fast path)
            t->c_fn(field, t->context);
        } else {
            // JavaScript transform (slow path)
            field = t->js_fn(field);
        }
    }
}
```

### 5. Adapter Pattern (Node.js Bridge)

```cpp
// Adapt C API to N-API
Napi::Value CisvParser::ParseSync(const Napi::CallbackInfo& info) {
    // Convert JS arguments to C types
    std::string path = info[0].As<Napi::String>();

    // Call C function
    int result = cisv_parser_parse_file(parser_, path.c_str());

    // Convert C results to JS types
    Napi::Array rows = Napi::Array::New(env, rows_.size());
    // ...
    return rows;
}
```

---

## Performance Characteristics

### Time Complexity

**Parsing:**
- Best case: O(n/64) with SIMD (all delimiters aligned)
- Average case: O(n/32) with SIMD (mixed)
- Worst case: O(n) scalar fallback

**Transformations:**
- C transforms: O(1) per field
- JS transforms: O(1) per field + overhead (~500ns)

**Memory:**
- File parsing: O(1) with mmap (streaming)
- Accumulated rows: O(rows × fields) in memory

### Space Complexity

**Parser State:**
- Parser struct: ~1KB
- Ring buffer: 1MB (configurable)
- Memory-mapped file: O(file_size) virtual, O(working_set) physical

**Output:**
- Parsed rows: O(rows × avg_field_size)
- Node.js: 2x overhead (UTF-16 conversion)

### Benchmark Methodology

**Test Setup:**
- CPU: Intel Core i7-9700K @ 3.6GHz (8 cores)
- RAM: 32GB DDR4-3200
- SSD: NVMe PCIe 3.0
- OS: Ubuntu 22.04 LTS
- Compiler: GCC 11.3.0

**Test Data:**
- 1M rows × 10 columns
- File size: ~150MB
- Mix of quoted/unquoted fields

**Results:**
```
cisv (sync):        71 MB/s   (2.1s total)
cisv (async):       98 MB/s   (1.5s total)
d3-dsv:             98 MB/s   (1.5s total)
papaparse:          28 MB/s   (5.4s total)
csv-parse:          18 MB/s   (8.3s total)
```

### Bottlenecks

**Current:**
1. **UTF-8 → UTF-16 conversion** (Node.js): ~30% overhead
2. **JavaScript transform overhead**: 50x slower than C
3. **Memory allocation** for rows: ~20% of parse time

**Optimization Opportunities:**
1. External strings (V8 feature) - avoid UTF-16 conversion
2. SIMD for transformations (uppercase/lowercase)
3. Thread pool for parallel parsing
4. Zero-copy strings with Buffers

---

## Platform Support Matrix

| Platform | Status | SIMD | Memory Mapping | Notes |
|----------|--------|------|----------------|-------|
| **Linux (x86_64)** | ✅ Supported | AVX-512/AVX2/SSE2 | mmap | Optimal |
| **macOS (x86_64)** | ✅ Supported | AVX2/SSE2 | mmap | Full support |
| **macOS (ARM64)** | ⚠️ Partial | Scalar only | mmap | No NEON yet |
| **Windows (x86_64)** | ❌ Not Supported | - | - | Planned (PRP-04) |
| **Linux (ARM64)** | ⚠️ Partial | Scalar only | mmap | No NEON yet (PRP-05) |
| **FreeBSD** | 🔶 Untested | AVX2/SSE2 | mmap | Should work |

### Platform-Specific Code

**Linux:**
```c
#ifdef __linux__
    #include <sys/mman.h>
    posix_fadvise(fd, 0, size, POSIX_FADV_SEQUENTIAL);
    mmap(NULL, size, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0);
#endif
```

**macOS:**
```c
#ifdef __APPLE__
    #include <sys/mman.h>
    #ifdef F_RDADVISE
        fcntl(fd, F_RDADVISE, &advice);
    #endif
    mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
#endif
```

**Windows (Planned):**
```c
#ifdef _WIN32
    HANDLE hFile = CreateFile(path, GENERIC_READ, ...);
    HANDLE hMap = CreateFileMapping(hFile, NULL, PAGE_READONLY, ...);
    void *data = MapViewOfFile(hMap, FILE_MAP_READ, ...);
#endif
```

**ARM NEON (Planned):**
```c
#ifdef __ARM_NEON
    #include <arm_neon.h>
    uint8x16_t chunk = vld1q_u8(data);
    uint8x16_t delim = vdupq_n_u8(',');
    uint8x16_t mask = vceqq_u8(chunk, delim);
#endif
```

---

## Future Architecture Enhancements

### 1. Multi-threaded Parsing (PRP-10)

```
File: data.csv (1GB)
   │
   ├─> Split into N chunks (thread-safe boundaries)
   │
   ├─> Thread 1: Parse chunk 1 (0-256MB)
   ├─> Thread 2: Parse chunk 2 (256-512MB)
   ├─> Thread 3: Parse chunk 3 (512-768MB)
   └─> Thread 4: Parse chunk 4 (768-1024MB)
        │
        └─> Merge results
```

**Challenges:**
- Finding row boundaries across chunks
- Quoted fields spanning chunks
- Memory ordering

### 2. Plugin Architecture (PRP-11)

```
┌──────────────────────────────────┐
│     Plugin Manager                │
├──────────────────────────────────┤
│  • Plugin discovery               │
│  • Version compatibility         │
│  • Dependency resolution         │
└──────────────────────────────────┘
          │
          ├─> Transform Plugins
          │     • Custom formats
          │     • Data validation
          │
          ├─> Output Plugins
          │     • Parquet writer
          │     • Avro writer
          │
          └─> Input Plugins
                • Excel reader
                • JSON→CSV
```

### 3. Schema Validation (PRP-08)

```
Schema: {
    fields: [
        { name: "id", type: "int", required: true },
        { name: "email", type: "string", pattern: /^.+@.+$/ },
        { name: "age", type: "int", range: [0, 150] }
    ]
}
   │
   ├─> Validate row 1: ✅ Pass
   ├─> Validate row 2: ❌ Fail (invalid email)
   └─> Report errors
```

---

## Conclusion

CISV's architecture is designed for extreme performance through:

1. **SIMD vectorization** - Process 64 bytes in parallel
2. **Memory mapping** - Zero-copy file access
3. **Cache optimization** - 1MB ring buffer aligned to cache
4. **Minimal abstraction** - Direct C implementation for hot paths
5. **Platform-specific tuning** - Leverage OS and CPU features

**Key Trade-offs:**
- ✅ Performance over portability (currently)
- ✅ Speed over safety (limited error handling)
- ✅ Simplicity over flexibility (minimal dependencies)

**Roadmap:**
- Phase 0-2: Production readiness + cross-platform
- Phase 3-4: Advanced features + ecosystem

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Claude Code (Architecture Analysis)
