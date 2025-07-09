package ojson

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:time"
import "base:runtime"

Err :: enum i32 {
    None = 0,
    File_Error = 1,
    Parse_Error = 2,
    Marshal_Error = 3,
    Type_Error = 4,
    Field_Not_Found = 5,
    Allocation_Error = 6,
    Invalid_JSON_Format = 7,
    No_Content = 8,
    Time_Format_Error = 9,
    Unsupported_Type = 10,
}

// read_file reads a JSON file from the given path and returns its content as bytes.
// The caller is responsible for deleting the returned data.
read_file :: proc(path: string) -> (data: []u8, err: Err) {
    file_data, ok := os.read_entire_file(path)
    if !ok {
        log.errorf("Error reading JSON file '%s'", path)
        return nil, .File_Error
    }
    
    if len(file_data) == 0 {
        delete(file_data)
        return nil, .No_Content
    }
    
    return file_data, .None
}

// write_file writes data to a JSON file at the given path.
write_file :: proc(path: string, data: []u8) -> (err: Err) {
    ok := os.write_entire_file(path, data)
    if !ok {
        log.errorf("Failed to write JSON file '%s'", path)
        return .File_Error
    }
    return .None
}

// parse_json parses JSON bytes into the given struct type.
parse_json :: proc(data: []u8, target: ^$T) -> (err: Err) {
    json_err := json.unmarshal(data, target)
    if json_err != nil {
        log.errorf("Error parsing JSON: %v", json_err)
        return .Parse_Error
    }
    return .None
}

// to_json converts a struct to JSON bytes.
// The caller is responsible for deleting the returned data.
to_json :: proc(value: $T, opt: json.Marshal_Options) -> ([]u8, Err) {
    b, json_err := json.marshal(value, opt, context.allocator)
    if json_err != nil {
        log.errorf("Error marshaling to JSON: %v", json_err)
        return nil, .Marshal_Error
    }
    if b == nil {
        log.error("Marshaling to JSON returned nil data")
        return nil, .Allocation_Error
    }
    if len(b) == 0 {
        log.error("Marshaling to JSON returned empty data")
        return nil, .Invalid_JSON_Format
    }
    return b, .None
}

// read_and_parse reads a JSON file and parses it into the given struct type.
read_and_parse :: proc(path: string, target: ^$T) -> Err {
    data, err := read_file(path)
    if err != .None {
        return err
    }
    defer delete(data)
    
    return parse_json(data, target)
}

// marshal_and_write converts a struct to JSON and writes it to a file.
marshal_and_write :: proc(path: string, value: $T, opt: ..json.Marshal_Options) -> Err {
    jopt := json.Marshal_Options{}
    if len(opt) == 0 {
        jopt = get_default_json_options()
    } else {
        jopt = opt[0]
    }
    data, err := to_json(value, jopt)
    if err != .None {
        return err
    }
    defer delete(data)
    
    return write_file(path, data)
}

// json_to_map converts JSON data to a map[string]json.Value
// This is useful for dynamic JSON parsing when you don't know the structure ahead of time
json_to_map :: proc(data: []u8) -> (result: map[string]json.Value, err: Err) {
    value: json.Value
    json_err := json.unmarshal(data, &value)
    if json_err != nil {
        log.errorf("Error parsing JSON to map: %v", json_err)
        return nil, .Parse_Error
    }
    if obj, ok := value.(json.Object); ok {
        // Convert json.Object to map[string]json.Value
        result = make(map[string]json.Value)
        for key, val in obj {
            result[key] = val
        }
        return result, .None
    }
    
    return nil, .Type_Error
}

// get_field_from_map extracts a field from a JSON map and converts it to the target type
get_field_from_map :: proc(json_map: map[string]json.Value, field_name: string, target: ^$T) -> (err: Err) {
    value, exists := json_map[field_name]
    if !exists {
        return .Field_Not_Found
    }
    // Handle different target types
    when T == string {
        if str, ok := value.(json.String); ok {
            target^ = string(str)
            return .None
        }
    } else when T == int {
        if num, ok := value.(json.Float); ok {
            target^ = int(num)
            return .None
        }
        if num, ok := value.(json.Integer); ok {
            target^ = int(num)
            return .None
        }
    } else when T == f64 {
        if num, ok := value.(json.Float); ok {
            target^ = f64(num)
            return .None
        }
        if num, ok := value.(json.Integer); ok {
            target^ = f64(num)
            return .None
        }
    } else when T == bool {
        if b, ok := value.(json.Boolean); ok {
            target^ = bool(b)
            return .None
        }
    } else when T == time.Time {
        if str, ok := value.(json.String); ok {
            parsed_time, time_ok := time.datetime_to_time(time.datetime_from_string(string(str)))
            if time_ok {
                target^ = parsed_time
                return .None
            }
            return .Time_Format_Error
        }
    }
    return .Type_Error
}

// validate_json checks if the given bytes contain valid JSON
validate_json :: proc(data: []u8) -> bool {
    value: json.Value
    return json.unmarshal(data, &value) == nil
}

// Create default options for JSON marshaling
get_default_json_options :: proc() -> json.Marshal_Options {
    options := json.Marshal_Options{
        pretty = true,
        use_spaces = true,
        spaces = 2,
    }
    return options
}