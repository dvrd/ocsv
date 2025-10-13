package ocsv_plugins

// Email Validator Plugin Example
// Demonstrates how to create a custom validator plugin for OCSV

import "core:strings"
import ocsv "../src"

// validate_email performs basic email format validation
// Returns (true, "") if valid, (false, error_message) if invalid
//
// This is a simplified validator that checks for:
// - Presence of @ symbol
// - Presence of domain extension (.)
// - Non-empty username and domain
//
// For production use, consider using a proper email validation library
// or RFC 5322 compliant regex
validate_email :: proc(value: string) -> (bool, string) {
    trimmed := strings.trim_space(value)

    // Empty check
    if len(trimmed) == 0 {
        return false, "Email cannot be empty"
    }

    // Must contain @
    if !strings.contains(trimmed, "@") {
        return false, "Email must contain @ symbol"
    }

    // Split at @
    parts := strings.split(trimmed, "@")
    defer delete(parts)

    if len(parts) != 2 {
        return false, "Email must have exactly one @ symbol"
    }

    username := parts[0]
    domain := parts[1]

    // Username checks
    if len(username) == 0 {
        return false, "Email username cannot be empty"
    }

    // Domain checks
    if len(domain) == 0 {
        return false, "Email domain cannot be empty"
    }

    // Must have domain extension
    if !strings.contains(domain, ".") {
        return false, "Email must contain domain extension (.com, .org, etc.)"
    }

    // Check for consecutive dots
    if strings.contains(trimmed, "..") {
        return false, "Email cannot contain consecutive dots"
    }

    // Basic format check: cannot start or end with @ or .
    if strings.has_prefix(trimmed, "@") || strings.has_suffix(trimmed, "@") {
        return false, "Email cannot start or end with @"
    }
    if strings.has_prefix(trimmed, ".") || strings.has_suffix(trimmed, ".") {
        return false, "Email cannot start or end with ."
    }

    return true, ""
}

// Email_Validator_Plugin is the plugin definition
// Register this with plugin_registry_create() to use it
Email_Validator_Plugin :: ocsv.Validator_Plugin{
    name = "email",
    description = "Basic email format validation (checks for @, domain, and basic structure)",
    validate = validate_email,
    // No init/cleanup needed for this simple plugin
    init = nil,
    cleanup = nil,
}

// Example usage:
// ```odin
// registry := ocsv.plugin_registry_create()
// defer ocsv.plugin_registry_destroy(registry)
//
// ocsv.plugin_register_validator(registry, Email_Validator_Plugin)
//
// validator, ok := ocsv.plugin_get_validator(registry, "email")
// if ok {
//     valid, msg := validator.validate("user@example.com")
//     // valid = true, msg = ""
//
//     valid2, msg2 := validator.validate("invalid-email")
//     // valid2 = false, msg2 = "Email must contain @ symbol"
// }
// ```
