# OCSV Plugins

This directory contains example plugins that demonstrate the OCSV plugin system.

## Overview

The OCSV plugin system allows you to extend CSV parsing functionality with:
- **Transform plugins** - Custom field transformations
- **Validator plugins** - Custom validation rules
- **Parser plugins** - Alternative parsing strategies
- **Output plugins** - Custom output formats

## Example Plugins

### 1. ROT13 Transform (`rot13.odin`)

A simple cipher that rotates alphabetic characters by 13 positions.

```odin
import ocsv_plugins "plugins"
import ocsv "src"

registry := ocsv.plugin_registry_create()
defer ocsv.plugin_registry_destroy(registry)

ocsv.plugin_register_transform(registry, ocsv_plugins.ROT13_Plugin)

transform, _ := ocsv.plugin_get_transform(registry, "rot13")
result := transform.transform("Hello World")
// result = "Uryyb Jbeyq"
```

**Features:**
- Reversible transformation (ROT13 twice = original)
- Preserves non-alphabetic characters
- Case-insensitive

### 2. Email Validator (`email_validator.odin`)

Basic email format validation.

```odin
import ocsv_plugins "plugins"
import ocsv "src"

registry := ocsv.plugin_registry_create()
defer ocsv.plugin_registry_destroy(registry)

ocsv.plugin_register_validator(registry, ocsv_plugins.Email_Validator_Plugin)

validator, _ := ocsv.plugin_get_validator(registry, "email")

valid, msg := validator.validate("user@example.com")
// valid = true, msg = ""

valid2, msg2 := validator.validate("invalid-email")
// valid2 = false, msg2 = "Email must contain @ symbol"
```

**Checks:**
- Presence of @ symbol
- Presence of domain extension
- No consecutive dots
- Non-empty username and domain
- Valid start/end characters

### 3. JSON Output (`json_output.odin`)

Converts CSV data to JSON format.

```odin
import ocsv_plugins "plugins"
import ocsv "src"

registry := ocsv.plugin_registry_create()
defer ocsv.plugin_registry_destroy(registry)

// Register both JSON plugins
ocsv.plugin_register_output(registry, ocsv_plugins.JSON_Output_Plugin)
ocsv.plugin_register_output(registry, ocsv_plugins.JSON_Objects_Output_Plugin)

// Parse CSV
parser := ocsv.parser_create()
defer ocsv.parser_destroy(parser)
ocsv.parse_csv(parser, "name,age\nAlice,30\nBob,25")

// Array format
output1, _ := ocsv.plugin_get_output(registry, "json")
json1 := output1.write(parser)
// json1 = [["name","age"],["Alice","30"],["Bob","25"]]

// Object format (first row = headers)
output2, _ := ocsv.plugin_get_output(registry, "json_objects")
json2 := output2.write(parser)
// json2 = [{"name":"Alice","age":"30"},{"name":"Bob","age":"25"}]
```

**Features:**
- Two output modes: arrays and objects
- Object mode uses first row as headers
- Handles empty CSV gracefully

## Creating Your Own Plugins

### Transform Plugin

```odin
package my_plugins

import ocsv "../src"

my_transform :: proc(value: string, allocator := context.allocator) -> string {
    // Your transformation logic here
    return transformed_value
}

My_Transform_Plugin :: ocsv.Transform_Plugin{
    name = "my_transform",
    description = "My custom transformation",
    transform = my_transform,
}
```

### Validator Plugin

```odin
package my_plugins

import ocsv "../src"

my_validator :: proc(value: string) -> (bool, string) {
    // Your validation logic here
    if is_valid {
        return true, ""
    }
    return false, "Error message"
}

My_Validator_Plugin :: ocsv.Validator_Plugin{
    name = "my_validator",
    description = "My custom validator",
    validate = my_validator,
}
```

### Parser Plugin

```odin
package my_plugins

import ocsv "../src"

my_parser :: proc(data: string, config: ocsv.Config, allocator := context.allocator) -> (^ocsv.Parser, bool) {
    // Your parsing logic here
    parser := ocsv.parser_create()
    // ... custom parsing ...
    return parser, true
}

My_Parser_Plugin :: ocsv.Parser_Plugin{
    name = "my_parser",
    description = "My custom parser",
    parse = my_parser,
}
```

### Output Plugin

```odin
package my_plugins

import ocsv "../src"

my_output :: proc(parser: ^ocsv.Parser, allocator := context.allocator) -> string {
    // Your output formatting logic here
    return formatted_output
}

My_Output_Plugin :: ocsv.Output_Plugin{
    name = "my_output",
    description = "My custom output format",
    write = my_output,
}
```

## Plugin Lifecycle

Plugins can optionally define `init` and `cleanup` procedures:

```odin
my_init :: proc() -> bool {
    // Initialize resources
    // Return true on success, false on failure
    return true
}

my_cleanup :: proc() {
    // Clean up resources
}

My_Plugin :: ocsv.Transform_Plugin{
    name = "my_plugin",
    description = "Plugin with lifecycle hooks",
    transform = my_transform,
    init = my_init,          // Called during registration
    cleanup = my_cleanup,    // Called during registry destruction
}
```

## Best Practices

1. **Keep plugins simple** - Each plugin should do one thing well
2. **Handle errors gracefully** - Validators should provide clear error messages
3. **Use proper memory management** - Clean up allocated resources
4. **Document your plugins** - Include usage examples in comments
5. **Test thoroughly** - Create tests for your plugins
6. **Consider performance** - Avoid unnecessary allocations in hot paths

## Testing

See `tests/test_plugin.odin` for examples of how to test plugins.

## Further Reading

- [PRP-11 Specification](../docs/PRP-11-SPEC.md) - Complete plugin architecture design
- [API Documentation](../docs/API.md) - Full API reference
- [ARCHITECTURE_OVERVIEW.md](../docs/ARCHITECTURE_OVERVIEW.md) - Project architecture

## License

Same as OCSV - see main project LICENSE file
