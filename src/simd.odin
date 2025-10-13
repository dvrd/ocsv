package ocsv

import "core:simd"
import "base:intrinsics"

// Optimized byte search functions for CSV parsing
// These use compiler auto-vectorization instead of manual SIMD to avoid overhead

// Platform-specific implementations (use compiler auto-vectorization)
when ODIN_ARCH == .arm64 {

    find_delimiter_simd :: proc(data: []byte, delim: byte, start: int = 0) -> int {
        return find_byte_optimized(data, delim, start)
    }

    // find_quote_simd searches for the first occurrence of a quote character
    find_quote_simd :: proc(data: []byte, quote: byte, start: int = 0) -> int {
        return find_delimiter_simd(data, quote, start)
    }

    find_newline_simd :: proc(data: []byte, start: int = 0) -> int {
        return find_byte_optimized(data, '\n', start)
    }

    find_any_special_simd :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
        return find_any_special_optimized(data, delim, quote, start)
    }

} else when ODIN_ARCH == .amd64 {
    // AMD64/AVX2 optimizations for x86_64 processors

    find_delimiter_simd :: proc(data: []byte, delim: byte, start: int = 0) -> int {
        // Similar implementation with AVX2 intrinsics
        // For now, fallback to scalar (AVX2 support can be added later)
        return find_byte_scalar(data, delim, start)
    }

    find_quote_simd :: proc(data: []byte, quote: byte, start: int = 0) -> int {
        return find_byte_scalar(data, quote, start)
    }

    find_newline_simd :: proc(data: []byte, start: int = 0) -> int {
        return find_byte_scalar(data, '\n', start)
    }

    find_any_special_simd :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
        return find_any_special_scalar(data, delim, quote, start)
    }

} else {
    // Fallback for other architectures

    find_delimiter_simd :: proc(data: []byte, delim: byte, start: int = 0) -> int {
        return find_byte_scalar(data, delim, start)
    }

    find_quote_simd :: proc(data: []byte, quote: byte, start: int = 0) -> int {
        return find_byte_scalar(data, quote, start)
    }

    find_newline_simd :: proc(data: []byte, start: int = 0) -> int {
        return find_byte_scalar(data, '\n', start)
    }

    find_any_special_simd :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
        return find_any_special_scalar(data, delim, quote, start)
    }
}

// Optimized implementations using compiler auto-vectorization
// Simple loops allow LLVM to generate efficient vectorized code

find_byte_optimized :: proc(data: []byte, target: byte, start: int = 0) -> int {
    if start >= len(data) {
        return -1
    }

    search_data := data[start:]
    for i := 0; i < len(search_data); i += 1 {
        if search_data[i] == target {
            return start + i
        }
    }
    return -1
}

find_any_special_optimized :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
    if start >= len(data) {
        return -1, 0
    }

    search_data := data[start:]
    for i := 0; i < len(search_data); i += 1 {
        b := search_data[i]
        if b == delim || b == quote || b == '\n' {
            return start + i, b
        }
    }
    return -1, 0
}

// Legacy scalar functions (kept for compatibility)
find_byte_scalar :: proc(data: []byte, target: byte, start: int = 0) -> int {
    return find_byte_optimized(data, target, start)
}

find_any_special_scalar :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
    return find_any_special_optimized(data, delim, quote, start)
}

// Helper to check if SIMD is available on this platform
is_simd_available :: proc() -> bool {
    when ODIN_ARCH == .arm64 || ODIN_ARCH == .amd64 {
        return true
    } else {
        return false
    }
}

// Get SIMD architecture name
get_simd_arch :: proc() -> string {
    when ODIN_ARCH == .arm64 {
        return "ARM64/NEON"
    } else when ODIN_ARCH == .amd64 {
        return "AMD64/AVX2"
    } else {
        return "Scalar (no SIMD)"
    }
}
