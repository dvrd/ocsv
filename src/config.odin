package cisv

// Config contains all parser configuration options
Config :: struct {
    delimiter:               byte,    // Field delimiter (default: ',')
    quote:                   byte,    // Quote character (default: '"')
    escape:                  byte,    // Escape character (default: '"')
    skip_empty_lines:        bool,    // Skip empty lines
    comment:                 byte,    // Comment character (default: '#')
    trim:                    bool,    // Trim whitespace from fields
    relaxed:                 bool,    // Relaxed parsing (allow RFC violations)
    max_row_size:            int,     // Maximum row size in bytes
    from_line:               int,     // Start parsing from line N (0 = start)
    to_line:                 int,     // Stop parsing at line N (-1 = end)
    skip_lines_with_error:   bool,    // Skip lines that fail to parse
}

// default_config returns a Config with sensible defaults
default_config :: proc() -> Config {
    return Config{
        delimiter            = ',',
        quote                = '"',
        escape               = '"',
        skip_empty_lines     = false,
        comment              = '#',
        trim                 = false,
        relaxed              = false,
        max_row_size         = 1024 * 1024,  // 1MB per row
        from_line            = 0,
        to_line              = -1,           // Parse all lines
        skip_lines_with_error = false,
    }
}
