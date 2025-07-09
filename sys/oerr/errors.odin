package oerr

import "core:fmt"
import "core:strings"
import "base:runtime"

// Base error context that can be embedded in specific error types
Context :: struct {
	location: runtime.Source_Code_Location,
	message:  string,
	details:  map[string]any, // Optional key-value pairs for additional context
}

// Helper to create an error context
new_context :: proc(message: string, details: map[string]any = nil, loc := #caller_location) -> Context {
	ctx_details := make(map[string]any)
	if details != nil {
		for k, v in details {
			ctx_details[k] = v
		}
	}
	return Context{
		location = loc,
		message  = message,
		details  = ctx_details,
	}
}

Err :: struct {
	using ctx: Context,
}

// Implement Error interface for Err
message :: proc(err: ^Err) -> string {
	return err.message
}

location :: proc(err: ^Err) -> runtime.Source_Code_Location {
	return err.location
}

details :: proc(err: ^Err) -> map[string]any {
	return err.details
}

// Constructor for simple errors
new_err :: proc(message: string, details: map[string]any = nil, loc := #caller_location, allocator := context.allocator) -> ^Err {
	context.allocator = allocator
	err := new(Err)
	err.ctx = new_context(message, details, loc)
	return err
}

// Validation Error - common pattern
Validation_Error :: struct {
	using ctx: Context,
	field:     string,
	value:     any,
	expected:  string,
}

new_validation_error :: proc(field: string, value: any, expected: string, loc := #caller_location, allocator := context.allocator) -> ^Validation_Error {
	context.allocator = allocator
	err := new(Validation_Error)
	err.ctx = new_context(fmt.aprintf("validation failed for field '%s'", field), loc = loc)
	err.field = field
	err.value = value
	err.expected = expected
	return err
}

validation_error_message :: proc(err: ^Validation_Error) -> string {
	return fmt.aprintf("validation failed for field '%s': expected %s, got %v", err.field, err.expected, err.value)
}

validation_error_location :: proc(err: ^Validation_Error) -> runtime.Source_Code_Location {
	return err.location
}

validation_error_details :: proc(err: ^Validation_Error) -> map[string]any {
	details := make(map[string]any)
	// Copy existing details
	for k, v in err.details {
		details[k] = v
	}
	details["field"] = err.field
	details["value"] = err.value
	details["expected"] = err.expected
	return details
}

// Error chain for wrapping errors
Chain :: struct {
	using ctx: Context,
	cause:     any, // The underlying error
}

new_error_chain :: proc(message: string, cause: any, loc := #caller_location, allocator := context.allocator) -> ^Chain {
	context.allocator = allocator
	err := new(Chain)
	err.ctx = new_context(message, loc = loc)
	err.cause = cause
	return err
}

error_chain_message :: proc(err: ^Chain) -> string {
	return err.message
}

error_chain_location :: proc(err: ^Chain) -> runtime.Source_Code_Location {
	return err.location
}

error_chain_details :: proc(err: ^Chain) -> map[string]any {
	details := make(map[string]any)
	// Copy existing details
	for k, v in err.details {
		details[k] = v
	}
	details["cause"] = err.cause
	return details
}

// Get the root cause of an error chain
root_cause :: proc(error: any) -> any {
	if chain, ok := error.(^Chain); ok {
		return root_cause(chain.cause)
	}
	return error
}

// File operation errors
File_Type :: enum {
	NOT_FOUND,
	PERMISSION_DENIED,
	EXISTS,
	EOF,
	IO,
}

File_Error :: struct {
	using ctx: Context,
	type:      File_Type,
	path:      string,
	os_error:  int, // OS-specific error code
}

new_file_error :: proc(type: File_Type, path: string, os_error: int = 0, loc := #caller_location, allocator := context.allocator) -> ^File_Error {
	context.allocator = allocator
	err := new(File_Error)
	
	msg: string
	switch type {
	case .NOT_FOUND:         msg = "file not found"
	case .PERMISSION_DENIED: msg = "permission denied"
	case .EXISTS:    		 msg = "file already exists"
	case .IO:          		 msg = "I/O error"
	case .EOF:               msg = "eof"
	}
	
	err.ctx = new_context(msg, loc = loc)
	err.type = type
	err.path = path
	err.os_error = os_error
	return err
}

file_error_message :: proc(err: ^File_Error) -> string {
	return fmt.aprintf("%s: %s", err.message, err.path)
}

file_error_location :: proc(err: ^File_Error) -> runtime.Source_Code_Location {
	return err.location
}

file_error_details :: proc(err: ^File_Error) -> map[string]any {
	details := make(map[string]any)
	// Copy existing details
	for k, v in err.details {
		details[k] = v
	}
	details["type"] = err.type
	details["path"] = err.path
	if err.os_error != 0 {
		details["os_error"] = err.os_error
	}
	return details
}

// Formatting utilities
format :: proc(error: any, allocator := context.allocator) -> string {
	context.allocator = allocator
	
	if error == nil {
		return "no error"
	}
	
	// Handle different error types
	switch err in error {
	case ^Err:
		return format_basic_error(err, allocator)
	case ^Validation_Error:
		return format_validation_error(err, allocator)
	case ^File_Error:
		return format_file_error(err, allocator)
	case ^Chain:
		return format_chain_error(err, allocator)
	}
	
	// Fallback to basic formatting
	return fmt.aprintf("%v", error)
}

@(private)
format_basic_error :: proc(err: ^Err, allocator := context.allocator) -> string {
	msg := message(err)
	loc := location(err)
	details := details(err)
	
	result := fmt.aprintf("%v: %s", loc, msg)
	
	if len(details) > 0 {
		detail_strs := make([dynamic]string, allocator = allocator)
		defer delete(detail_strs)
		
		for key, value in details {
			append(&detail_strs, fmt.aprintf("%s=%v", key, value))
		}
		details_str := strings.join(detail_strs[:], ", ")
		result = fmt.aprintf("%s [%s]", result, details_str)
	}
	
	return result
}

@(private)
format_validation_error :: proc(err: ^Validation_Error, allocator := context.allocator) -> string {
	msg := validation_error_message(err)
	loc := validation_error_location(err)
	return fmt.aprintf("%v: %s", loc, msg)
}

@(private)
format_file_error :: proc(err: ^File_Error, allocator := context.allocator) -> string {
	msg := file_error_message(err)
	loc := file_error_location(err)
	result := fmt.aprintf("%v: %s", loc, msg)
	
	if err.os_error != 0 {
		result = fmt.aprintf("%s (OS error: %d)", result, err.os_error)
	}
	return result
}

@(private)
format_chain_error :: proc(err: ^Chain, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator = allocator)
	defer strings.builder_destroy(&sb)
	
	// Format current error
	current_msg := error_chain_message(err)
	current_loc := error_chain_location(err)
	fmt.sbprintf(&sb, "%v: %s", current_loc, current_msg)
	
	// Add cause chain
	if err.cause != nil {
		cause_str := format(err.cause, allocator)
		fmt.sbprintf(&sb, "\nCaused by: %s", cause_str)
	}
	return strings.clone(strings.to_string(sb), allocator)
}

// Error checking utilities
is_error :: proc(error: any) -> bool {
	return error != nil
}

// Wrap an error with additional context
wrap :: proc(error: any, message: string, loc := #caller_location, allocator := context.allocator) -> ^Chain {
	if error == nil do return nil
	return new_error_chain(message, error, loc, allocator)
}

// Unwrap an error to get the root cause
unwrap :: proc(error: any) -> any {
	if error == nil do return nil
	if chain, ok := error.(^Chain); ok {
		return chain.cause
	}
	return error
}

// ANSI color codes for terminal output
@(private="package")
ESC :: "\033["
@(private="package")
RESET :: ESC + "0m"
@(private="package")
RED :: ESC + "91m"  // Changed to bright red
@(private="package")
color :: proc(color_code, input: string) -> string {
	return fmt.aprintf("%s%s%s", color_code, input, RESET)
}
@(private="package")
red :: proc(input: string) -> string {
	return color(RED, input)
}

// Convenience function to print error to stderr
print :: proc(error: any, allocator := context.allocator) {
	if error == nil do return
	
	msg := format(error, allocator)
	defer delete(msg, allocator)
	
	fmt.eprintf("%s\n", red(msg))
}