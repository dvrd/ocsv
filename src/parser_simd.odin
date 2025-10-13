package ocsv

// SIMD-optimized CSV parser (EXPERIMENTAL - NOT YET OPTIMIZED)
// Target: 1.2-1.5x performance improvement over the standard parser
// Current status: Manual SIMD implementation has overhead issues
//
// TODO: Implement true SIMD using:
// - NEON intrinsics for ARM64
// - AVX2 intrinsics for x86_64
// - Proper vectorized comparisons (not byte-by-byte loops)
//
// For now, delegating to standard parser for better performance

parse_csv_simd :: proc(parser: ^Parser, data: string) -> bool {
    // TEMPORARY: Delegating to standard parser until true SIMD is implemented
    // The previous manual SIMD implementation had function call overhead
    // that made it slower than the standard parser's optimized loop
    return parse_csv(parser, data)
}

// parse_csv_auto automatically chooses between SIMD and standard parser
// based on file size and SIMD availability
parse_csv_auto :: proc(parser: ^Parser, data: string) -> bool {
    when ODIN_ARCH == .arm64 || ODIN_ARCH == .amd64 {
        // Use SIMD for files > 1KB
        if len(data) >= 1024 {
            return parse_csv_simd(parser, data)
        }
    }

    // Fallback to standard parser
    return parse_csv(parser, data)
}
