package ocsv

// Plugin system for extending OCSV functionality
//
// This module provides a type-safe plugin architecture that allows
// external developers to extend OCSV with:
// - Custom field transformations
// - Custom validation rules
// - Alternative parsing strategies
// - Custom output formats
//
// See docs/PRP-11-SPEC.md for detailed design documentation

import "core:fmt"
import "base:runtime"

// ============================================================================
// Plugin Function Types
// ============================================================================

// Note: Transform_Func is defined in transform.odin and reused here

// Validator_Func validates a string value
// Returns (valid: bool, error_message: string)
Validator_Func :: #type proc(value: string) -> (bool, string)

// Parser_Func creates a parser from data using the provided config
// Returns (parser: ^Parser, success: bool)
Parser_Func :: #type proc(data: string, config: Config, allocator := context.allocator) -> (^Parser, bool)

// Output_Func converts parsed data to a custom output format
// Returns the formatted output as a string
Output_Func :: #type proc(parser: ^Parser, allocator := context.allocator) -> string

// ============================================================================
// Plugin Structs
// ============================================================================

// Transform_Plugin defines a custom field transformation
Transform_Plugin :: struct {
    name:        string,         // Unique identifier (e.g., "rot13", "uppercase")
    description: string,         // Human-readable description
    transform:   Transform_Func, // The transformation function
    init:        proc() -> bool, // Optional: initialization (can be nil)
    cleanup:     proc(),         // Optional: cleanup (can be nil)
}

// Validator_Plugin defines a custom validation rule
Validator_Plugin :: struct {
    name:        string,          // Unique identifier (e.g., "email", "credit_card")
    description: string,          // Human-readable description
    validate:    Validator_Func,  // The validation function
    init:        proc() -> bool,  // Optional: initialization (can be nil)
    cleanup:     proc(),          // Optional: cleanup (can be nil)
}

// Parser_Plugin defines an alternative parsing strategy
Parser_Plugin :: struct {
    name:        string,       // Unique identifier (e.g., "fixed_width", "json")
    description: string,       // Human-readable description
    parse:       Parser_Func,  // The parsing function
    init:        proc() -> bool, // Optional: initialization (can be nil)
    cleanup:     proc(),       // Optional: cleanup (can be nil)
}

// Output_Plugin defines a custom output format
Output_Plugin :: struct {
    name:        string,       // Unique identifier (e.g., "json", "xml")
    description: string,       // Human-readable description
    write:       Output_Func,  // The output function
    init:        proc() -> bool, // Optional: initialization (can be nil)
    cleanup:     proc(),       // Optional: cleanup (can be nil)
}

// ============================================================================
// Plugin Registry
// ============================================================================

// Plugin_Registry is the central registry for discovering and managing plugins
Plugin_Registry :: struct {
    transforms: map[string]Transform_Plugin,
    validators: map[string]Validator_Plugin,
    parsers:    map[string]Parser_Plugin,
    outputs:    map[string]Output_Plugin,
    allocator:  runtime.Allocator, // Allocator used for registry operations
}

// ============================================================================
// Registry Creation & Destruction
// ============================================================================

// plugin_registry_create creates a new plugin registry
// The registry must be destroyed with plugin_registry_destroy to avoid memory leaks
plugin_registry_create :: proc(allocator := context.allocator) -> ^Plugin_Registry {
    registry := new(Plugin_Registry, allocator)
    registry.allocator = allocator
    registry.transforms = make(map[string]Transform_Plugin, 16, allocator)
    registry.validators = make(map[string]Validator_Plugin, 16, allocator)
    registry.parsers = make(map[string]Parser_Plugin, 16, allocator)
    registry.outputs = make(map[string]Output_Plugin, 16, allocator)
    return registry
}

// plugin_registry_destroy cleans up a plugin registry
// Calls cleanup() on all registered plugins that have cleanup functions
plugin_registry_destroy :: proc(registry: ^Plugin_Registry) {
    if registry == nil do return

    // Call cleanup on all plugins that have cleanup functions
    for _, plugin in registry.transforms {
        if plugin.cleanup != nil {
            plugin.cleanup()
        }
    }
    for _, plugin in registry.validators {
        if plugin.cleanup != nil {
            plugin.cleanup()
        }
    }
    for _, plugin in registry.parsers {
        if plugin.cleanup != nil {
            plugin.cleanup()
        }
    }
    for _, plugin in registry.outputs {
        if plugin.cleanup != nil {
            plugin.cleanup()
        }
    }

    // Clean up maps
    delete(registry.transforms)
    delete(registry.validators)
    delete(registry.parsers)
    delete(registry.outputs)

    // Free the registry itself
    free(registry, registry.allocator)
}

// ============================================================================
// Plugin Registration
// ============================================================================

// plugin_register_transform registers a transform plugin
// Returns true on success, false if a plugin with the same name already exists
plugin_register_transform :: proc(registry: ^Plugin_Registry, plugin: Transform_Plugin) -> bool {
    if registry == nil do return false
    if plugin.name == "" do return false

    // Check if plugin already exists
    if plugin.name in registry.transforms {
        return false
    }

    // Call init if provided
    if plugin.init != nil {
        if !plugin.init() {
            return false
        }
    }

    registry.transforms[plugin.name] = plugin
    return true
}

// plugin_register_validator registers a validator plugin
// Returns true on success, false if a plugin with the same name already exists
plugin_register_validator :: proc(registry: ^Plugin_Registry, plugin: Validator_Plugin) -> bool {
    if registry == nil do return false
    if plugin.name == "" do return false

    // Check if plugin already exists
    if plugin.name in registry.validators {
        return false
    }

    // Call init if provided
    if plugin.init != nil {
        if !plugin.init() {
            return false
        }
    }

    registry.validators[plugin.name] = plugin
    return true
}

// plugin_register_parser registers a parser plugin
// Returns true on success, false if a plugin with the same name already exists
plugin_register_parser :: proc(registry: ^Plugin_Registry, plugin: Parser_Plugin) -> bool {
    if registry == nil do return false
    if plugin.name == "" do return false

    // Check if plugin already exists
    if plugin.name in registry.parsers {
        return false
    }

    // Call init if provided
    if plugin.init != nil {
        if !plugin.init() {
            return false
        }
    }

    registry.parsers[plugin.name] = plugin
    return true
}

// plugin_register_output registers an output plugin
// Returns true on success, false if a plugin with the same name already exists
plugin_register_output :: proc(registry: ^Plugin_Registry, plugin: Output_Plugin) -> bool {
    if registry == nil do return false
    if plugin.name == "" do return false

    // Check if plugin already exists
    if plugin.name in registry.outputs {
        return false
    }

    // Call init if provided
    if plugin.init != nil {
        if !plugin.init() {
            return false
        }
    }

    registry.outputs[plugin.name] = plugin
    return true
}

// ============================================================================
// Plugin Lookup
// ============================================================================

// plugin_get_transform looks up a transform plugin by name
// Returns (plugin, true) if found, (zero_value, false) if not found
plugin_get_transform :: proc(registry: ^Plugin_Registry, name: string) -> (Transform_Plugin, bool) {
    if registry == nil do return {}, false
    plugin, ok := registry.transforms[name]
    return plugin, ok
}

// plugin_get_validator looks up a validator plugin by name
// Returns (plugin, true) if found, (zero_value, false) if not found
plugin_get_validator :: proc(registry: ^Plugin_Registry, name: string) -> (Validator_Plugin, bool) {
    if registry == nil do return {}, false
    plugin, ok := registry.validators[name]
    return plugin, ok
}

// plugin_get_parser looks up a parser plugin by name
// Returns (plugin, true) if found, (zero_value, false) if not found
plugin_get_parser :: proc(registry: ^Plugin_Registry, name: string) -> (Parser_Plugin, bool) {
    if registry == nil do return {}, false
    plugin, ok := registry.parsers[name]
    return plugin, ok
}

// plugin_get_output looks up an output plugin by name
// Returns (plugin, true) if found, (zero_value, false) if not found
plugin_get_output :: proc(registry: ^Plugin_Registry, name: string) -> (Output_Plugin, bool) {
    if registry == nil do return {}, false
    plugin, ok := registry.outputs[name]
    return plugin, ok
}

// ============================================================================
// Plugin Listing
// ============================================================================

// plugin_list_transforms returns the names of all registered transform plugins
// The returned slice must be freed by the caller
plugin_list_transforms :: proc(registry: ^Plugin_Registry, allocator := context.allocator) -> []string {
    if registry == nil do return nil

    names := make([dynamic]string, allocator)
    for name in registry.transforms {
        append(&names, name)
    }
    return names[:]
}

// plugin_list_validators returns the names of all registered validator plugins
// The returned slice must be freed by the caller
plugin_list_validators :: proc(registry: ^Plugin_Registry, allocator := context.allocator) -> []string {
    if registry == nil do return nil

    names := make([dynamic]string, allocator)
    for name in registry.validators {
        append(&names, name)
    }
    return names[:]
}

// plugin_list_parsers returns the names of all registered parser plugins
// The returned slice must be freed by the caller
plugin_list_parsers :: proc(registry: ^Plugin_Registry, allocator := context.allocator) -> []string {
    if registry == nil do return nil

    names := make([dynamic]string, allocator)
    for name in registry.parsers {
        append(&names, name)
    }
    return names[:]
}

// plugin_list_outputs returns the names of all registered output plugins
// The returned slice must be freed by the caller
plugin_list_outputs :: proc(registry: ^Plugin_Registry, allocator := context.allocator) -> []string {
    if registry == nil do return nil

    names := make([dynamic]string, allocator)
    for name in registry.outputs {
        append(&names, name)
    }
    return names[:]
}
