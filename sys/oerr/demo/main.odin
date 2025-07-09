#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "base:runtime"
import "../"

Math_Error_Type :: enum {
	NEGATIVE_RESULT,
	ZERO_RESULT,
	OVERFLOW,
}

Math_Error :: struct {
	using ctx: oerr.Context,
	type:      Math_Error_Type,
	args:      [2]int,
	result:    int,
}

new_math_error :: proc(type: Math_Error_Type, args: [2]int, result: int, loc := #caller_location, allocator := context.allocator) -> ^Math_Error {
	context.allocator = allocator
	err := new(Math_Error)
	
	message: string
	switch type {
	case .NEGATIVE_RESULT: message = "operation resulted in negative value"
	case .ZERO_RESULT:     message = "operation resulted in zero"
	case .OVERFLOW:        message = "operation caused overflow"
	}
	
	err.ctx = oerr.new_context(message, loc = loc)
	err.type = type
	err.args = args
	err.result = result
	return err
}

math_error_message :: proc(err: ^Math_Error) -> string {
	return fmt.aprintf("Math error: %s when computing %d + %d = %d", err.ctx.message, err.args[0], err.args[1], err.result)
}

math_error_location :: proc(err: ^Math_Error) -> runtime.Source_Code_Location {
	return err.ctx.location
}

math_error_details :: proc(err: ^Math_Error) -> map[string]any {
	details := make(map[string]any)
	// Copy existing details first
	for k, v in err.ctx.details {
		details[k] = v
	}
	details["type"] = err.type
	details["args"] = err.args
	details["result"] = err.result
	return details
}

sum :: proc(a, b: int, loc := #caller_location) -> (result: int, err: ^Math_Error) {
	result = a + b
	
	// Check for overflow (simplified)
	if (a > 0 && b > 0 && result < 0) || (a < 0 && b < 0 && result > 0) {
		err = new_math_error(.OVERFLOW, {a, b}, result, loc)
		return
	}
	
	switch {
	case result < 0:
		err = new_math_error(.NEGATIVE_RESULT, {a, b}, result, loc)
	case result == 0:
		err = new_math_error(.ZERO_RESULT, {a, b}, result, loc)
	}
	
	return
}

// Configuration structure
Config :: struct {
	name:    string,
	version: int,
	enabled: bool,
}

// Simulate different types of failures
read_config :: proc(path: string) -> (config: Config, err: any) {
	switch path {
	case "":
		err = oerr.new_validation_error("path", path, "non-empty string")
		return
	case "nonexistent.conf":
		err = oerr.new_file_error(.NOT_FOUND, path, 2)
		return
	case "secret.conf":
		err = oerr.new_file_error(.PERMISSION_DENIED, path, 13)
		return
	case "corrupted.conf":
		file_err := oerr.new_file_error(.IO, path, 5)
		err = oerr.wrap(file_err, "failed to parse configuration file")
		return
	case "valid.conf":
		// Success case
		config = Config{
			name    = "MyApp",
			version = 1,
			enabled = true,
		}
		return
	}
	// Default case - unexpected path
	details := make(map[string]any)
	details["path"] = path
	err = oerr.new_err("unexpected configuration path", details)
	return
}

main :: proc() {
	fmt.println("=== Error Handling Demo ===\n")
	
	// Math operations demo
	fmt.println("1. Math Operations:")
	test_cases := [][2]int{{10, -11}, {5, -5}, {0, 0}, {max(int) - 1, 2}} // Fixed overflow test
	
	for args in test_cases {
		result, err := sum(args[0], args[1])
		if err != nil {
			oerr.print(err)
		} else {
			fmt.printf("sum(%d, %d) = %d\n", args[0], args[1], result)
		}
	}
	
	fmt.println("\n2. Error Wrapping Chain:")
	// Create a chain of wrapped errors
	details := make(map[string]any)
	details["timeout_ms"] = 5000
	details["host"] = "api.example.com"
	
	original := oerr.new_err("network timeout", details)
	wrapped := oerr.wrap(original, "failed to fetch user data")
	final := oerr.wrap(wrapped, "login process failed")
	oerr.print(final)
	
	// Show root cause extraction
	root := oerr.root_cause(final)
	fmt.printf("Root cause type: %T\n", root)
	
	fmt.println("\n3. File Operations:")
	config_paths := []string{"valid.conf"}
	
	for path in config_paths {
		config, err := read_config(path)
		if err != nil {
			fmt.printf("Failed to read '%s':\n", path)
			oerr.print(err)
		} else {
			fmt.printf("%s: %+v\n", path, config)
		}
		fmt.println() // Add spacing
	}
	
	fmt.println("4. Custom Error Formatting:")
	// Show different error types
	validation_err := oerr.new_validation_error("age", -5, "non-negative integer")
	file_err := oerr.new_file_error(.NOT_FOUND, "/etc/config.conf", 2)
	math_err := new_math_error(.OVERFLOW, {max(int) - 1, 2}, -2)
	
	fmt.println("Validation Error:")
	oerr.print(validation_err)
	
	fmt.println("File Error:")
	oerr.print(file_err)
	
	fmt.println("Custom Math Error:")
	oerr.print(math_err)
}