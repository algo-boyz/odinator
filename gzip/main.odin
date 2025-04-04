package gzip

import "core:fmt"
import "core:os"
import "core:strings"
import "core:bufio"
import "core:bytes"
import "core:io"
import "core:compress/gzip"

// Function to read and decompress a gzip file, returning the raw bytes
read_gzip_file :: proc(path: string, allocator := context.allocator) -> ([]byte, gzip.Error) {
    result: []byte
    
    buf_gzip := bytes.Buffer{}
    defer bytes.buffer_destroy(&buf_gzip)

    // Create a gzip reader
    gz_err := gzip.load_from_file(path, &buf_gzip)
    if gz_err != nil {
        return result, gz_err
    }
    
    return bytes.buffer_to_bytes(&buf_gzip), nil
}

print_lines :: proc(data: []byte) -> (line_count: int, err: io.Error) {
    if data == nil || len(data) == 0 {
        return 0, io.Error.Empty
    }
    
    temp_buffer := bytes.Buffer{}
    bytes.buffer_write(&temp_buffer, data)
    
    r: bufio.Reader
    r_buffer: [2048]byte
    bufio.reader_init_with_buf(&r, bytes.buffer_to_stream(&temp_buffer), r_buffer[:])
    defer bufio.reader_destroy(&r)
    
    line_count = 0
    for {
        line, read_err := bufio.reader_read_string(&r, '\n', context.allocator)
        if read_err != nil {
            // handle last line has content but no newline character at the end
            if line != "" {
                trimmed := strings.trim_right(line, "\r\n")
                fmt.println(trimmed)
                line_count += 1
            }
            if read_err != io.Error.EOF {
                return line_count, read_err
            }
            break
        }
        
        defer delete(line, context.allocator)
        trimmed := strings.trim_right(line, "\r\n")
        fmt.println(trimmed)
        line_count += 1
    }
    return line_count, nil
}

main :: proc() {
    path := "example.txt.gz"

    result, read_err := read_gzip_file(path)
    if read_err != nil {
        fmt.eprintln("Error reading gzip file:", read_err)
        return
    }
    
    // Example: line by line
    line_count, process_err := print_lines(result)
    if process_err != nil {
        fmt.eprintln("Error processing lines:", process_err)
        return
    }
    fmt.println("processed", line_count, "lines")
    
    /*
    // Example: JSON unmarshal
    import "core:encoding/json"
    json_data, json_err := json.unmarshal(result.data)
    if json_err != nil {
        fmt.eprintln("JSON parsing error:", json_err)
        return
    }
    defer json.destroy_value(json_data)
    
    // Example: CSV reader

    import "core:encoding/csv"
    csv_buffer := bytes.Buffer{}
    bytes.buffer_write(&csv_buffer, result.data)
    csv_reader: csv.Reader
    csv.reader_init(&csv_reader, bytes.buffer_to_stream(&csv_buffer))
    defer csv.reader_destroy(&csv_reader)
    */
}