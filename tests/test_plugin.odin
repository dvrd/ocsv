package tests

import "core:testing"
import "core:strings"
import ocsv "../src"

// ============================================================================
// Test Helper Functions & Example Plugins
// ============================================================================

// Example transform: ROT13 cipher
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

// Example transform: uppercase
uppercase_transform :: proc(value: string, allocator := context.allocator) -> string {
    return strings.to_upper(value, allocator)
}

// Example validator: email format check (simple)
validate_email :: proc(value: string) -> (bool, string) {
    if !strings.contains(value, "@") {
        return false, "Email must contain @"
    }
    if !strings.contains(value, ".") {
        return false, "Email must contain domain extension"
    }
    return true, ""
}

// Example validator: not empty
validate_not_empty :: proc(value: string) -> (bool, string) {
    if len(value) == 0 {
        return false, "Value cannot be empty"
    }
    return true, ""
}

// Example parser: passthrough parser (delegates to standard)
passthrough_parser :: proc(data: string, config: ocsv.Config, allocator := context.allocator) -> (^ocsv.Parser, bool) {
    parser := ocsv.parser_create()
    ok := ocsv.parse_csv(parser, data)
    if !ok {
        ocsv.parser_destroy(parser)
        return nil, false
    }
    return parser, true
}

// Example output: simple JSON array format
write_json :: proc(parser: ^ocsv.Parser, allocator := context.allocator) -> string {
    builder := strings.builder_make(allocator)
    strings.write_string(&builder, "[")

    for row, row_idx in parser.all_rows {
        if row_idx > 0 do strings.write_string(&builder, ",")
        strings.write_string(&builder, "[")

        for field, field_idx in row {
            if field_idx > 0 do strings.write_string(&builder, ",")
            strings.write_string(&builder, "\"")
            strings.write_string(&builder, field)
            strings.write_string(&builder, "\"")
        }

        strings.write_string(&builder, "]")
    }

    strings.write_string(&builder, "]")
    return strings.to_string(builder)
}

// ============================================================================
// Registry Tests (5 tests)
// ============================================================================

@(test)
test_plugin_registry_create_destroy :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    testing.expect(t, registry != nil, "Registry should be created")
    testing.expect_value(t, len(registry.transforms), 0)
    testing.expect_value(t, len(registry.validators), 0)
    testing.expect_value(t, len(registry.parsers), 0)
    testing.expect_value(t, len(registry.outputs), 0)
}

@(test)
test_plugin_register_transform :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        description = "ROT13 cipher transformation",
        transform = rot13_transform,
    }

    ok := ocsv.plugin_register_transform(registry, plugin)
    testing.expect(t, ok, "Should register transform successfully")
    testing.expect_value(t, len(registry.transforms), 1)

    // Try to register again - should fail
    ok2 := ocsv.plugin_register_transform(registry, plugin)
    testing.expect(t, !ok2, "Should not register duplicate transform")
    testing.expect_value(t, len(registry.transforms), 1)

    // Register with empty name - should fail
    empty_plugin := ocsv.Transform_Plugin{
        name = "",
        transform = rot13_transform,
    }
    ok3 := ocsv.plugin_register_transform(registry, empty_plugin)
    testing.expect(t, !ok3, "Should not register transform with empty name")
}

@(test)
test_plugin_register_validator :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    plugin := ocsv.Validator_Plugin{
        name = "email",
        description = "Email format validation",
        validate = validate_email,
    }

    ok := ocsv.plugin_register_validator(registry, plugin)
    testing.expect(t, ok, "Should register validator successfully")
    testing.expect_value(t, len(registry.validators), 1)

    // Try to register again - should fail
    ok2 := ocsv.plugin_register_validator(registry, plugin)
    testing.expect(t, !ok2, "Should not register duplicate validator")
}

@(test)
test_plugin_register_parser :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    plugin := ocsv.Parser_Plugin{
        name = "passthrough",
        description = "Passthrough parser for testing",
        parse = passthrough_parser,
    }

    ok := ocsv.plugin_register_parser(registry, plugin)
    testing.expect(t, ok, "Should register parser successfully")
    testing.expect_value(t, len(registry.parsers), 1)

    // Try to register again - should fail
    ok2 := ocsv.plugin_register_parser(registry, plugin)
    testing.expect(t, !ok2, "Should not register duplicate parser")
}

@(test)
test_plugin_register_output :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    plugin := ocsv.Output_Plugin{
        name = "json",
        description = "JSON array output",
        write = write_json,
    }

    ok := ocsv.plugin_register_output(registry, plugin)
    testing.expect(t, ok, "Should register output successfully")
    testing.expect_value(t, len(registry.outputs), 1)

    // Try to register again - should fail
    ok2 := ocsv.plugin_register_output(registry, plugin)
    testing.expect(t, !ok2, "Should not register duplicate output")
}

// ============================================================================
// Lookup Tests (4 tests)
// ============================================================================

@(test)
test_plugin_get_transform :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register a transform
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        description = "ROT13 cipher transformation",
        transform = rot13_transform,
    }
    ocsv.plugin_register_transform(registry, plugin)

    // Lookup existing transform
    found, ok := ocsv.plugin_get_transform(registry, "rot13")
    testing.expect(t, ok, "Should find registered transform")
    testing.expect_value(t, found.name, "rot13")

    // Lookup non-existent transform
    _, not_found := ocsv.plugin_get_transform(registry, "nonexistent")
    testing.expect(t, !not_found, "Should not find non-existent transform")

    // Test with nil registry
    _, nil_result := ocsv.plugin_get_transform(nil, "rot13")
    testing.expect(t, !nil_result, "Should return false for nil registry")
}

@(test)
test_plugin_get_validator :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register a validator
    plugin := ocsv.Validator_Plugin{
        name = "email",
        description = "Email format validation",
        validate = validate_email,
    }
    ocsv.plugin_register_validator(registry, plugin)

    // Lookup existing validator
    found, ok := ocsv.plugin_get_validator(registry, "email")
    testing.expect(t, ok, "Should find registered validator")
    testing.expect_value(t, found.name, "email")

    // Lookup non-existent validator
    _, not_found := ocsv.plugin_get_validator(registry, "nonexistent")
    testing.expect(t, !not_found, "Should not find non-existent validator")
}

@(test)
test_plugin_get_parser :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register a parser
    plugin := ocsv.Parser_Plugin{
        name = "passthrough",
        description = "Passthrough parser",
        parse = passthrough_parser,
    }
    ocsv.plugin_register_parser(registry, plugin)

    // Lookup existing parser
    found, ok := ocsv.plugin_get_parser(registry, "passthrough")
    testing.expect(t, ok, "Should find registered parser")
    testing.expect_value(t, found.name, "passthrough")

    // Lookup non-existent parser
    _, not_found := ocsv.plugin_get_parser(registry, "nonexistent")
    testing.expect(t, !not_found, "Should not find non-existent parser")
}

@(test)
test_plugin_get_output :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register an output
    plugin := ocsv.Output_Plugin{
        name = "json",
        description = "JSON array output",
        write = write_json,
    }
    ocsv.plugin_register_output(registry, plugin)

    // Lookup existing output
    found, ok := ocsv.plugin_get_output(registry, "json")
    testing.expect(t, ok, "Should find registered output")
    testing.expect_value(t, found.name, "json")

    // Lookup non-existent output
    _, not_found := ocsv.plugin_get_output(registry, "nonexistent")
    testing.expect(t, !not_found, "Should not find non-existent output")
}

// ============================================================================
// List Tests (4 tests)
// ============================================================================

@(test)
test_plugin_list_transforms :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Empty registry
    names := ocsv.plugin_list_transforms(registry)
    defer delete(names)
    testing.expect_value(t, len(names), 0)

    // Register transforms
    plugin1 := ocsv.Transform_Plugin{name = "rot13", transform = rot13_transform}
    plugin2 := ocsv.Transform_Plugin{name = "uppercase", transform = uppercase_transform}
    ocsv.plugin_register_transform(registry, plugin1)
    ocsv.plugin_register_transform(registry, plugin2)

    // List transforms
    names2 := ocsv.plugin_list_transforms(registry)
    defer delete(names2)
    testing.expect_value(t, len(names2), 2)

    // Check that both names are present (order doesn't matter)
    found_rot13, found_uppercase := false, false
    for name in names2 {
        if name == "rot13" do found_rot13 = true
        if name == "uppercase" do found_uppercase = true
    }
    testing.expect(t, found_rot13, "Should list rot13 transform")
    testing.expect(t, found_uppercase, "Should list uppercase transform")
}

@(test)
test_plugin_list_validators :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Empty registry
    names := ocsv.plugin_list_validators(registry)
    defer delete(names)
    testing.expect_value(t, len(names), 0)

    // Register validators
    plugin1 := ocsv.Validator_Plugin{name = "email", validate = validate_email}
    plugin2 := ocsv.Validator_Plugin{name = "not_empty", validate = validate_not_empty}
    ocsv.plugin_register_validator(registry, plugin1)
    ocsv.plugin_register_validator(registry, plugin2)

    // List validators
    names2 := ocsv.plugin_list_validators(registry)
    defer delete(names2)
    testing.expect_value(t, len(names2), 2)
}

@(test)
test_plugin_list_parsers :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Empty registry
    names := ocsv.plugin_list_parsers(registry)
    defer delete(names)
    testing.expect_value(t, len(names), 0)

    // Register parser
    plugin := ocsv.Parser_Plugin{name = "passthrough", parse = passthrough_parser}
    ocsv.plugin_register_parser(registry, plugin)

    // List parsers
    names2 := ocsv.plugin_list_parsers(registry)
    defer delete(names2)
    testing.expect_value(t, len(names2), 1)
    testing.expect_value(t, names2[0], "passthrough")
}

@(test)
test_plugin_list_outputs :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Empty registry
    names := ocsv.plugin_list_outputs(registry)
    defer delete(names)
    testing.expect_value(t, len(names), 0)

    // Register output
    plugin := ocsv.Output_Plugin{name = "json", write = write_json}
    ocsv.plugin_register_output(registry, plugin)

    // List outputs
    names2 := ocsv.plugin_list_outputs(registry)
    defer delete(names2)
    testing.expect_value(t, len(names2), 1)
    testing.expect_value(t, names2[0], "json")
}

// ============================================================================
// Integration Tests (5+ tests)
// ============================================================================

@(test)
test_plugin_transform_integration :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register ROT13 transform
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ocsv.plugin_register_transform(registry, plugin)

    // Get and use the transform
    transform, ok := ocsv.plugin_get_transform(registry, "rot13")
    testing.expect(t, ok, "Should find ROT13 transform")

    // Test the transform function
    input := "Hello World"
    result := transform.transform(input)
    defer delete(result)
    testing.expect_value(t, result, "Uryyb Jbeyq")

    // Verify it's reversible (ROT13 twice = original)
    reversed := transform.transform(result)
    defer delete(reversed)
    testing.expect_value(t, reversed, input)
}

@(test)
test_plugin_validator_integration :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register email validator
    plugin := ocsv.Validator_Plugin{
        name = "email",
        validate = validate_email,
    }
    ocsv.plugin_register_validator(registry, plugin)

    // Get and use the validator
    validator, ok := ocsv.plugin_get_validator(registry, "email")
    testing.expect(t, ok, "Should find email validator")

    // Test valid email
    valid, _ := validator.validate("user@example.com")
    testing.expect(t, valid, "Should validate correct email")

    // Test invalid emails
    invalid1, msg1 := validator.validate("invalid-email")
    testing.expect(t, !invalid1, "Should reject email without @")
    testing.expect(t, len(msg1) > 0, "Should provide error message")

    invalid2, msg2 := validator.validate("invalid@email")
    testing.expect(t, !invalid2, "Should reject email without domain extension")
    testing.expect(t, len(msg2) > 0, "Should provide error message")
}

@(test)
test_plugin_parser_integration :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register passthrough parser
    plugin := ocsv.Parser_Plugin{
        name = "passthrough",
        parse = passthrough_parser,
    }
    ocsv.plugin_register_parser(registry, plugin)

    // Get and use the parser
    parser_plugin, ok := ocsv.plugin_get_parser(registry, "passthrough")
    testing.expect(t, ok, "Should find passthrough parser")

    // Parse CSV data
    data := "a,b,c\n1,2,3\n4,5,6"
    config := ocsv.default_config()
    parser, parse_ok := parser_plugin.parse(data, config)
    defer if parser != nil do ocsv.parser_destroy(parser)

    testing.expect(t, parse_ok, "Should parse successfully")
    testing.expect(t, parser != nil, "Parser should not be nil")
    testing.expect_value(t, len(parser.all_rows), 3)
    testing.expect_value(t, len(parser.all_rows[0]), 3)
}

@(test)
test_plugin_output_integration :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register JSON output
    plugin := ocsv.Output_Plugin{
        name = "json",
        write = write_json,
    }
    ocsv.plugin_register_output(registry, plugin)

    // Parse some CSV data
    parser := ocsv.parser_create()
    defer ocsv.parser_destroy(parser)
    data := "a,b\n1,2\n3,4"
    ok := ocsv.parse_csv(parser, data)
    testing.expect(t, ok, "Should parse CSV")

    // Get and use the output plugin
    output, output_ok := ocsv.plugin_get_output(registry, "json")
    testing.expect(t, output_ok, "Should find JSON output")

    result := output.write(parser)
    defer delete(result)

    // Verify JSON format
    testing.expect(t, strings.contains(result, "["), "Should contain array brackets")
    testing.expect(t, strings.contains(result, "\"a\""), "Should contain field data")
    testing.expect_value(t, result, "[[\"a\",\"b\"],[\"1\",\"2\"],[\"3\",\"4\"]]")
}

@(test)
test_plugin_multiple_concurrent :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    // Register multiple plugins of different types
    transform := ocsv.Transform_Plugin{name = "rot13", transform = rot13_transform}
    validator := ocsv.Validator_Plugin{name = "email", validate = validate_email}
    parser_p := ocsv.Parser_Plugin{name = "passthrough", parse = passthrough_parser}
    output := ocsv.Output_Plugin{name = "json", write = write_json}

    ocsv.plugin_register_transform(registry, transform)
    ocsv.plugin_register_validator(registry, validator)
    ocsv.plugin_register_parser(registry, parser_p)
    ocsv.plugin_register_output(registry, output)

    // Verify all are registered
    testing.expect_value(t, len(registry.transforms), 1)
    testing.expect_value(t, len(registry.validators), 1)
    testing.expect_value(t, len(registry.parsers), 1)
    testing.expect_value(t, len(registry.outputs), 1)

    // Use all plugins in a workflow
    data := "email\nuser@example.com\ninvalid"
    config := ocsv.default_config()

    parser_plugin, _ := ocsv.plugin_get_parser(registry, "passthrough")
    parser, _ := parser_plugin.parse(data, config)
    defer if parser != nil do ocsv.parser_destroy(parser)

    // Validate fields using validator plugin
    val_plugin, _ := ocsv.plugin_get_validator(registry, "email")
    for row in parser.all_rows {
        for field in row {
            valid, _ := val_plugin.validate(field)
            // Just checking it runs without crashing
            _ = valid
        }
    }

    // Transform and output
    trans_plugin, _ := ocsv.plugin_get_transform(registry, "rot13")
    out_plugin, _ := ocsv.plugin_get_output(registry, "json")

    _ = trans_plugin
    json_output := out_plugin.write(parser)
    defer delete(json_output)

    testing.expect(t, len(json_output) > 0, "Should produce JSON output")
}

// ============================================================================
// Init/Cleanup Tests
// ============================================================================

init_called := false
cleanup_called := false

test_init :: proc() -> bool {
    init_called = true
    return true
}

test_cleanup :: proc() {
    cleanup_called = true
}

@(test)
test_plugin_init_cleanup :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    init_called = false
    cleanup_called = false

    // Register plugin with init/cleanup
    plugin := ocsv.Transform_Plugin{
        name = "test",
        transform = rot13_transform,
        init = test_init,
        cleanup = test_cleanup,
    }

    ok := ocsv.plugin_register_transform(registry, plugin)
    testing.expect(t, ok, "Should register plugin")
    testing.expect(t, init_called, "Init should be called during registration")

    // Cleanup is called when registry is destroyed
    ocsv.plugin_registry_destroy(registry)
    testing.expect(t, cleanup_called, "Cleanup should be called during destruction")

    // Create new registry to avoid double-free
    registry = ocsv.plugin_registry_create()
}

@(test)
test_plugin_init_failure :: proc(t: ^testing.T) {
    registry := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(registry)

    failing_init :: proc() -> bool {
        return false
    }

    plugin := ocsv.Transform_Plugin{
        name = "failing",
        transform = rot13_transform,
        init = failing_init,
    }

    ok := ocsv.plugin_register_transform(registry, plugin)
    testing.expect(t, !ok, "Should fail to register if init returns false")
    testing.expect_value(t, len(registry.transforms), 0)
}

// ============================================================================
// Bridge Function Tests (PRP-12)
// ============================================================================

@(test)
test_bridge_sync_single_transform :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    transform_reg := ocsv.registry_create()
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Register plugin
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ocsv.plugin_register_transform(plugin_reg, plugin)

    // Sync to transform registry
    ok := ocsv.plugin_sync_transform_to_registry(plugin_reg, "rot13", transform_reg)
    testing.expect(t, ok, "Should sync successfully")

    // Verify transform works in standard registry
    result := ocsv.apply_transform(transform_reg, "rot13", "Hello")
    defer delete(result)
    testing.expect_value(t, result, "Uryyb")

    // Try to sync non-existent plugin
    ok2 := ocsv.plugin_sync_transform_to_registry(plugin_reg, "nonexistent", transform_reg)
    testing.expect(t, !ok2, "Should fail to sync non-existent plugin")
}

@(test)
test_bridge_sync_all_transforms :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    transform_reg := ocsv.registry_create()
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Register multiple plugins
    plugin1 := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    plugin2 := ocsv.Transform_Plugin{
        name = "uppercase",
        transform = uppercase_transform,
    }

    ocsv.plugin_register_transform(plugin_reg, plugin1)
    ocsv.plugin_register_transform(plugin_reg, plugin2)

    // Sync all at once
    count := ocsv.plugin_sync_all_transforms_to_registry(plugin_reg, transform_reg)
    testing.expect_value(t, count, 2)

    // Verify both work in standard registry
    result1 := ocsv.apply_transform(transform_reg, "rot13", "Hello")
    defer delete(result1)
    testing.expect_value(t, result1, "Uryyb")

    result2 := ocsv.apply_transform(transform_reg, "uppercase", "hello")
    defer delete(result2)
    testing.expect_value(t, result2, "HELLO")
}

@(test)
test_bridge_register_with_sync :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    transform_reg := ocsv.registry_create()
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Register with automatic sync
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ok := ocsv.plugin_register_transform_with_sync(plugin_reg, plugin, transform_reg)
    testing.expect(t, ok, "Should register with sync successfully")

    // Verify available in both registries
    plugin_found, plugin_ok := ocsv.plugin_get_transform(plugin_reg, "rot13")
    testing.expect(t, plugin_ok, "Should find in plugin registry")

    result := ocsv.apply_transform(transform_reg, "rot13", "Test")
    defer delete(result)
    testing.expect_value(t, result, "Grfg")
}

@(test)
test_bridge_register_with_sync_no_transform_reg :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    defer ocsv.plugin_registry_destroy(plugin_reg)

    // Register without transform registry (should still work)
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ok := ocsv.plugin_register_transform_with_sync(plugin_reg, plugin, nil)
    testing.expect(t, ok, "Should register even without transform registry")

    // Verify still in plugin registry
    _, found := ocsv.plugin_get_transform(plugin_reg, "rot13")
    testing.expect(t, found, "Should find in plugin registry")
}

@(test)
test_bridge_unified_registry :: proc(t: ^testing.T) {
    plugin_reg, transform_reg := ocsv.plugin_create_unified_registry()
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Both registries should be created
    testing.expect(t, plugin_reg != nil, "Plugin registry should be created")
    testing.expect(t, transform_reg != nil, "Transform registry should be created")

    // Register with sync
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ok := ocsv.plugin_register_transform_with_sync(plugin_reg, plugin, transform_reg)
    testing.expect(t, ok, "Should register with sync")

    // Use both APIs
    plugin_found, _ := ocsv.plugin_get_transform(plugin_reg, "rot13")
    result1 := plugin_found.transform("Hello")
    defer delete(result1)
    testing.expect_value(t, result1, "Uryyb")

    result2 := ocsv.apply_transform(transform_reg, "rot13", "Hello")
    defer delete(result2)
    testing.expect_value(t, result2, "Uryyb")
}

@(test)
test_bridge_with_pipeline :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    transform_reg := ocsv.registry_create()
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Register plugins and sync
    plugin := ocsv.Transform_Plugin{
        name = "uppercase",
        transform = uppercase_transform,
    }
    ocsv.plugin_register_transform_with_sync(plugin_reg, plugin, transform_reg)

    // Use plugin transform in standard pipeline
    pipeline := ocsv.pipeline_create()
    defer ocsv.pipeline_destroy(pipeline)

    ocsv.pipeline_add_step(pipeline, "uppercase", 0)  // Apply to first field

    // Create test data - must be heap-allocated since pipeline will free/replace them
    row := []string{strings.clone("hello"), strings.clone("world")}
    defer delete(row[0])
    defer delete(row[1])

    // Apply pipeline
    ocsv.pipeline_apply_to_row(pipeline, transform_reg, row)

    // Verify transformation
    testing.expect_value(t, row[0], "HELLO")
    testing.expect_value(t, row[1], "world")  // Unchanged
}

@(test)
test_bridge_builtin_and_plugin_coexist :: proc(t: ^testing.T) {
    plugin_reg := ocsv.plugin_registry_create()
    transform_reg := ocsv.registry_create()  // Has built-ins
    defer ocsv.plugin_registry_destroy(plugin_reg)
    defer ocsv.registry_destroy(transform_reg)

    // Register custom plugin
    plugin := ocsv.Transform_Plugin{
        name = "rot13",
        transform = rot13_transform,
    }
    ocsv.plugin_register_transform_with_sync(plugin_reg, plugin, transform_reg)

    // Verify built-in transform still works
    result1 := ocsv.apply_transform(transform_reg, ocsv.TRANSFORM_TRIM, "  hello  ")
    defer delete(result1)
    testing.expect_value(t, result1, "hello")

    // Verify plugin transform works
    result2 := ocsv.apply_transform(transform_reg, "rot13", "Hello")
    defer delete(result2)
    testing.expect_value(t, result2, "Uryyb")

    // Verify both work in combination
    result3 := ocsv.apply_transform(transform_reg, ocsv.TRANSFORM_UPPERCASE, "hello")
    defer delete(result3)
    result4 := ocsv.apply_transform(transform_reg, "rot13", result3)
    defer delete(result4)
    testing.expect_value(t, result4, "URYYB")
}
