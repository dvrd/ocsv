# PRP-11: Plugin Architecture - Technical Specification

**Status:** 🚧 In Progress
**Duration:** Est. 2 weeks
**Priority:** P4
**Complexity:** High
**Risk:** Medium
**Dependencies:** PRP-08 (Schema), PRP-09 (Transforms)

---

## Executive Summary

Implement a plugin system that allows external developers to extend OCSV functionality with custom:
- **Transform plugins** - Custom field transformations
- **Validator plugins** - Custom validation rules
- **Parser plugins** - Alternative parsing strategies
- **Output plugins** - Custom output formats

**Key Goals:**
- Simple plugin API
- Type-safe plugin registration
- Zero-copy where possible
- Backward compatible with existing systems

---

## Design Principles

1. **Simplicity First** - Plugins should be easy to write
2. **Type Safety** - Leverage Odin's type system
3. **Performance** - Minimal overhead (function pointers)
4. **Integration** - Seamless integration with existing APIs
5. **Discoverability** - Easy to find and use plugins

---

## Plugin Types

### 1. Transform Plugins

**Purpose:** Custom field transformations beyond the built-in 12 transforms.

**Use Cases:**
- Custom date parsing (non-standard formats)
- Domain-specific transformations (e.g., medical codes)
- Complex string manipulations
- Currency conversions with live exchange rates

**API:**
```odin
Transform_Plugin :: struct {
    name:        string,                    // "custom_date_parse"
    description: string,                    // Human-readable description
    transform:   Transform_Func,            // proc(string) -> string
    init:        proc() -> bool,            // Optional initialization
    cleanup:     proc(),                    // Optional cleanup
}

Transform_Func :: #type proc(value: string, allocator := context.allocator) -> string
```

**Example:**
```odin
my_transform :: proc(value: string, allocator := context.allocator) -> string {
    // Custom logic
    return custom_result
}

plugin := Transform_Plugin{
    name = "my_transform",
    description = "Custom transformation",
    transform = my_transform,
}
```

### 2. Validator Plugins

**Purpose:** Custom validation rules beyond the built-in schema validators.

**Use Cases:**
- Business logic validation (e.g., credit card numbers)
- External API validation (e.g., check if email exists)
- Complex constraints (e.g., multi-field dependencies)
- Custom type checking

**API:**
```odin
Validator_Plugin :: struct {
    name:        string,                    // "credit_card"
    description: string,                    // Human-readable description
    validate:    Validator_Func,            // proc(string) -> bool
    init:        proc() -> bool,            // Optional initialization
    cleanup:     proc(),                    // Optional cleanup
}

Validator_Func :: #type proc(value: string) -> (valid: bool, error: string)
```

**Example:**
```odin
validate_credit_card :: proc(value: string) -> (bool, string) {
    // Luhn algorithm
    if !luhn_check(value) {
        return false, "Invalid credit card number"
    }
    return true, ""
}

plugin := Validator_Plugin{
    name = "credit_card",
    description = "Validates credit card numbers using Luhn algorithm",
    validate = validate_credit_card,
}
```

### 3. Parser Plugins

**Purpose:** Alternative parsing strategies for specialized CSV formats.

**Use Cases:**
- Non-RFC 4180 formats (e.g., fixed-width)
- Streaming from network sources
- Compressed CSV (gzip, zlib)
- Binary CSV formats

**API:**
```odin
Parser_Plugin :: struct {
    name:        string,                    // "fixed_width"
    description: string,                    // Human-readable description
    parse:       Parser_Func,               // proc(string) -> ^Parser
    init:        proc() -> bool,            // Optional initialization
    cleanup:     proc(),                    // Optional cleanup
}

Parser_Func :: #type proc(data: string, config: Config, allocator := context.allocator) -> (^Parser, bool)
```

**Example:**
```odin
parse_fixed_width :: proc(data: string, config: Config, allocator := context.allocator) -> (^Parser, bool) {
    parser := parser_create()
    // Custom fixed-width parsing logic
    return parser, true
}

plugin := Parser_Plugin{
    name = "fixed_width",
    description = "Parses fixed-width column data",
    parse = parse_fixed_width,
}
```

### 4. Output Plugins

**Purpose:** Custom output formats beyond CSV.

**Use Cases:**
- JSON output
- XML output
- Database INSERT statements
- Custom report formats

**API:**
```odin
Output_Plugin :: struct {
    name:        string,                    // "json"
    description: string,                    // Human-readable description
    write:       Output_Func,               // proc(^Parser) -> string
    init:        proc() -> bool,            // Optional initialization
    cleanup:     proc(),                    // Optional cleanup
}

Output_Func :: #type proc(parser: ^Parser, allocator := context.allocator) -> string
```

**Example:**
```odin
write_json :: proc(parser: ^Parser, allocator := context.allocator) -> string {
    // Convert parser.all_rows to JSON
    return json_string
}

plugin := Output_Plugin{
    name = "json",
    description = "Outputs parsed data as JSON",
    write = write_json,
}
```

---

## Plugin Registry

**Purpose:** Central registry for discovering and managing plugins.

**API:**
```odin
Plugin_Registry :: struct {
    transforms: map[string]Transform_Plugin,
    validators: map[string]Validator_Plugin,
    parsers:    map[string]Parser_Plugin,
    outputs:    map[string]Output_Plugin,
}

// Create registry
registry_create :: proc() -> ^Plugin_Registry

// Register plugins
register_transform :: proc(registry: ^Plugin_Registry, plugin: Transform_Plugin) -> bool
register_validator :: proc(registry: ^Plugin_Registry, plugin: Validator_Plugin) -> bool
register_parser :: proc(registry: ^Plugin_Registry, plugin: Parser_Plugin) -> bool
register_output :: proc(registry: ^Plugin_Registry, plugin: Output_Plugin) -> bool

// Lookup plugins
get_transform :: proc(registry: ^Plugin_Registry, name: string) -> (Transform_Plugin, bool)
get_validator :: proc(registry: ^Plugin_Registry, name: string) -> (Validator_Plugin, bool)
get_parser :: proc(registry: ^Plugin_Registry, name: string) -> (Parser_Plugin, bool)
get_output :: proc(registry: ^Plugin_Registry, name: string) -> (Output_Plugin, bool)

// List plugins
list_transforms :: proc(registry: ^Plugin_Registry) -> []string
list_validators :: proc(registry: ^Plugin_Registry) -> []string
list_parsers :: proc(registry: ^Plugin_Registry) -> []string
list_outputs :: proc(registry: ^Plugin_Registry) -> []string

// Cleanup
registry_destroy :: proc(registry: ^Plugin_Registry)
```

---

## Integration with Existing Systems

### Transform System Integration

The existing transform system (PRP-09) already supports custom transforms via `Transform_Func`. Plugins extend this by:

1. **Registering transforms** in the global registry
2. **Discovering transforms** by name
3. **Applying transforms** using the same pipeline API

**Example:**
```odin
// Register plugin transform
register_transform(registry, my_transform_plugin)

// Use in transform pipeline (existing API)
pipeline := transform_pipeline_create()
transform_pipeline_add_by_name(pipeline, "my_transform")  // Looks up in registry
result := transform_pipeline_apply(pipeline, "input_data")
```

### Schema Validation Integration

Schema validation (PRP-07) can use validator plugins for custom rules:

**Example:**
```odin
// Register plugin validator
register_validator(registry, credit_card_validator)

// Use in schema (existing API)
field_schema := Field_Schema{
    name = "card_number",
    type = .String,
    validators = []Validator{
        .Required,
        .Custom{"credit_card"},  // References plugin
    },
}
```

### Parser Plugin Integration

Parser plugins provide alternative parsing strategies:

**Example:**
```odin
// Register plugin parser
register_parser(registry, fixed_width_parser)

// Use instead of standard parser
parser_plugin, ok := get_parser(registry, "fixed_width")
if ok {
    parser, success := parser_plugin.parse(data, config)
    defer parser_destroy(parser)
    // Use parsed data
}
```

---

## Implementation Plan

### Phase 1: Core Plugin System (Week 1)

**Goals:**
- Implement plugin types and registry
- Basic registration and lookup
- Integration with transform system

**Deliverables:**
1. `src/plugin.odin` - Plugin types and registry
2. `tests/test_plugin.odin` - Basic tests (15+ tests)
3. Integration with existing `transform.odin`

**Tasks:**
- [ ] Define plugin types (Transform, Validator, Parser, Output)
- [ ] Implement Plugin_Registry with maps
- [ ] Write registration/lookup functions
- [ ] Add tests for registry operations
- [ ] Integrate with Transform_Registry

### Phase 2: Plugin Examples & Documentation (Week 2)

**Goals:**
- Create example plugins
- Document plugin API
- Provide plugin development guide

**Deliverables:**
1. `plugins/` directory with examples
2. `docs/PLUGIN_API.md` - Plugin development guide
3. `docs/PLUGIN_EXAMPLES.md` - Example plugins
4. Integration tests with real plugins

**Tasks:**
- [ ] Create example transform plugin (e.g., rot13)
- [ ] Create example validator plugin (e.g., email)
- [ ] Create example output plugin (e.g., JSON)
- [ ] Write plugin development guide
- [ ] Add integration tests

---

## Example Plugins

### 1. ROT13 Transform Plugin

```odin
package examples

import ocsv "../src"

rot13_transform :: proc(value: string, allocator := context.allocator) -> string {
    result := make([]u8, len(value), allocator)
    for ch, i in value {
        if ch >= 'A' && ch <= 'Z' {
            result[i] = byte((ch - 'A' + 13) % 26 + 'A')
        } else if ch >= 'a' && ch <= 'z' {
            result[i] = byte((ch - 'a' + 13) % 26 + 'a')
        } else {
            result[i] = byte(ch)
        }
    }
    return string(result)
}

ROT13_Plugin :: ocsv.Transform_Plugin{
    name = "rot13",
    description = "ROT13 cipher transformation",
    transform = rot13_transform,
}
```

### 2. Email Validator Plugin

```odin
package examples

import "core:strings"
import ocsv "../src"

validate_email :: proc(value: string) -> (bool, string) {
    if !strings.contains(value, "@") {
        return false, "Email must contain @"
    }
    if !strings.contains(value, ".") {
        return false, "Email must contain domain extension"
    }
    return true, ""
}

Email_Validator_Plugin :: ocsv.Validator_Plugin{
    name = "email",
    description = "Basic email format validation",
    validate = validate_email,
}
```

### 3. JSON Output Plugin

```odin
package examples

import "core:fmt"
import "core:strings"
import ocsv "../src"

write_json :: proc(parser: ^ocsv.Parser, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)
    strings.write_string(&builder, "[")

    for row, row_idx in parser.all_rows {
        if row_idx > 0 do strings.write_string(&builder, ",")
        strings.write_string(&builder, "[")

        for field, field_idx in row {
            if field_idx > 0 do strings.write_string(&builder, ",")
            fmt.sbprintf(&builder, "\"%s\"", field)
        }

        strings.write_string(&builder, "]")
    }

    strings.write_string(&builder, "]")
    return strings.to_string(builder)
}

JSON_Output_Plugin :: ocsv.Output_Plugin{
    name = "json",
    description = "Outputs parsed data as JSON array",
    write = write_json,
}
```

---

## Testing Strategy

### Unit Tests (15+ tests)

1. **Registry Tests (5 tests)**
   - test_registry_create_destroy
   - test_register_transform
   - test_register_validator
   - test_register_parser
   - test_register_output

2. **Lookup Tests (4 tests)**
   - test_get_transform
   - test_get_validator
   - test_get_parser
   - test_get_output

3. **List Tests (4 tests)**
   - test_list_transforms
   - test_list_validators
   - test_list_parsers
   - test_list_outputs

4. **Integration Tests (5+ tests)**
   - test_plugin_transform_integration
   - test_plugin_validator_integration
   - test_plugin_parser_integration
   - test_plugin_output_integration
   - test_multiple_plugins_concurrent

### Integration Tests

Test with real example plugins:
- ROT13 transform
- Email validator
- JSON output

---

## Success Criteria

- [ ] All plugin types implemented
- [ ] Registry working (register, lookup, list)
- [ ] 15+ tests passing
- [ ] 3+ example plugins
- [ ] Integration with existing systems
- [ ] Documentation complete
- [ ] Zero memory leaks

---

## Future Enhancements

### Dynamic Plugin Loading (Phase 5)

Currently, plugins are compiled into the binary. Future work:
- Load plugins from shared libraries (.so, .dylib, .dll)
- Plugin discovery from directory
- Version compatibility checking
- Hot reload support

### Plugin Marketplace (Phase 6)

- Central plugin repository
- Plugin versioning
- Dependency management
- Security scanning

---

## Timeline

**Week 1:** Core implementation
- Day 1-2: Plugin types and registry
- Day 3-4: Integration with transforms
- Day 5: Testing and bug fixes

**Week 2:** Examples and documentation
- Day 1-2: Example plugins
- Day 3-4: Documentation
- Day 5: Final testing and release

---

**Created:** 2025-10-13
**Status:** 🚧 Specification Complete, Implementation Pending
**Next Step:** Implement `src/plugin.odin`
