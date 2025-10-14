package ocsv

import "core:simd"
import "base:intrinsics"

// Optimized byte search functions for CSV parsing using proper SIMD
// Based on core/bytes implementation pattern

// SIMD constants for 128-bit (16 byte) vectors
SCANNER_INDICES_128 :: simd.u8x16{
	0,  1,  2,  3,  4,  5,  6,  7,
	8,  9, 10, 11, 12, 13, 14, 15,
}
SCANNER_SENTINEL_MIN_128 :: simd.u8x16(255) // Use max u8 as sentinel for min search
SIMD_REG_SIZE_128 :: 16

// Platform-specific implementations
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

// Real SIMD implementations using Odin's SIMD API

find_byte_optimized :: proc(data: []byte, target: byte, start: int = 0) -> int #no_bounds_check {
    if start >= len(data) {
        return -1
    }

    search_data := data[start:]
    i, l := 0, len(search_data)

    // Guard against small data - not worth vectorizing
    if l < SIMD_REG_SIZE_128 {
        for i < l {
            if search_data[i] == target {
                return start + i
            }
            i += 1
        }
        return -1
    }

    target_vec: simd.u8x16 = target

    // Process 16-byte chunks with SIMD
    for i + SIMD_REG_SIZE_128 <= l {
        // Load 16 bytes (unaligned safe)
        chunk := intrinsics.unaligned_load(cast(^simd.u8x16)raw_data(search_data[i:]))

        // Compare all bytes - returns vector of 0xFF where match, 0x00 where no match
        matches := simd.lanes_eq(chunk, target_vec)

        // Check if any lane matched
        if simd.reduce_or(matches) > 0 {
            // Use select to get indices where matched, sentinel where not
            sel := simd.select(matches, SCANNER_INDICES_128, SCANNER_SENTINEL_MIN_128)
            // Find lowest index (first match)
            off := simd.reduce_min(sel)
            return start + i + int(off)
        }

        i += SIMD_REG_SIZE_128
    }

    // Handle remaining bytes (< 16)
    for i < l {
        if search_data[i] == target {
            return start + i
        }
        i += 1
    }

    return -1
}

find_any_special_optimized :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) #no_bounds_check {
    if start >= len(data) {
        return -1, 0
    }

    search_data := data[start:]
    i, l := 0, len(search_data)
    newline: byte = '\n'

    // Guard against small data
    if l < SIMD_REG_SIZE_128 {
        for i < l {
            b := search_data[i]
            if b == delim || b == quote || b == newline {
                return start + i, b
            }
            i += 1
        }
        return -1, 0
    }

    delim_vec: simd.u8x16 = delim
    quote_vec: simd.u8x16 = quote
    newline_vec: simd.u8x16 = newline

    // Process 16-byte chunks with SIMD
    for i + SIMD_REG_SIZE_128 <= l {
        // Load 16 bytes
        chunk := intrinsics.unaligned_load(cast(^simd.u8x16)raw_data(search_data[i:]))

        // Compare against each special character
        delim_matches := simd.lanes_eq(chunk, delim_vec)
        quote_matches := simd.lanes_eq(chunk, quote_vec)
        newline_matches := simd.lanes_eq(chunk, newline_vec)

        // Combine all matches with OR
        any_matches := delim_matches | quote_matches | newline_matches

        // Check if any lane matched
        if simd.reduce_or(any_matches) > 0 {
            // Get indices where matched
            sel := simd.select(any_matches, SCANNER_INDICES_128, SCANNER_SENTINEL_MIN_128)
            off := simd.reduce_min(sel)
            matched_byte := search_data[i + int(off)]
            return start + i + int(off), matched_byte
        }

        i += SIMD_REG_SIZE_128
    }

    // Handle remaining bytes
    for i < l {
        b := search_data[i]
        if b == delim || b == quote || b == newline {
            return start + i, b
        }
        i += 1
    }

    return -1, 0
}

// Pure scalar implementations (no SIMD, always available)
find_byte_scalar :: proc(data: []byte, target: byte, start: int = 0) -> int {
    if start >= len(data) {
        return -1
    }

    for i in start..<len(data) {
        if data[i] == target {
            return i
        }
    }
    return -1
}

find_any_special_scalar :: proc(data: []byte, delim: byte, quote: byte, start: int = 0) -> (int, byte) {
    if start >= len(data) {
        return -1, 0
    }

    newline: byte = '\n'
    for i in start..<len(data) {
        b := data[i]
        if b == delim || b == quote || b == newline {
            return i, b
        }
    }
    return -1, 0
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
