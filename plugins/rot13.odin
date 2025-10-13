package ocsv_plugins

// ROT13 Transform Plugin Example
// Demonstrates how to create a custom transform plugin for OCSV

import ocsv "../src"

// rot13_transform applies the ROT13 cipher to the input string
// ROT13 is a simple letter substitution cipher that replaces a letter with the
// letter 13 positions after it in the alphabet
rot13_transform :: proc(value: string, allocator := context.allocator) -> string {
    result := make([]u8, len(value), allocator)

    for ch, i in value {
        if ch >= 'A' && ch <= 'Z' {
            // Uppercase letters: A-Z → N-Z, A-M
            result[i] = byte((ch - 'A' + 13) % 26 + 'A')
        } else if ch >= 'a' && ch <= 'z' {
            // Lowercase letters: a-z → n-z, a-m
            result[i] = byte((ch - 'a' + 13) % 26 + 'a')
        } else {
            // Non-alphabetic characters remain unchanged
            result[i] = byte(ch)
        }
    }

    return string(result)
}

// ROT13_Plugin is the plugin definition
// Register this with plugin_registry_create() to use it
ROT13_Plugin :: ocsv.Transform_Plugin{
    name = "rot13",
    description = "ROT13 cipher transformation - rotates alphabetic characters by 13 positions",
    transform = rot13_transform,
    // No init/cleanup needed for this simple plugin
    init = nil,
    cleanup = nil,
}

// Example usage:
// ```odin
// registry := ocsv.plugin_registry_create()
// defer ocsv.plugin_registry_destroy(registry)
//
// ocsv.plugin_register_transform(registry, ROT13_Plugin)
//
// transform, ok := ocsv.plugin_get_transform(registry, "rot13")
// if ok {
//     result := transform.transform("Hello World")
//     // result = "Uryyb Jbeyq"
// }
// ```
