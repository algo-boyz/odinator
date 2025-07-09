#+feature dynamic-literals
package oj

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:time"
import "base:runtime"
import "../"

// Example usage structures for demos
Person :: struct {
    name: string `json:"name"`,
    age: int `json:"age"`,
    email: string `json:"email"`,
    salary: f64 `json:"salary"`,
    is_active: bool `json:"is_active"`,
    start_date: string `json:"start_date"`, // Using string for simplicity in demo
    addresses: []Address `json:"addresses"`,
    metadata: map[string]string `json:"metadata,omitempty"`,
}

Address :: struct {
    street: string `json:"street"`,
    city: string `json:"city"`,
    country: string `json:"country"`,
    postal_code: string `json:"postal_code,omitempty"`,
}

// Demo functions similar to your CSV package
demo_write_json :: proc() {
    log.info("Demo 1: Writing JSON Data")
    
    // Create sample JSON data
    person := Person{
        name = "John Doe",
        age = 30,
        email = "john.doe@example.com",
        salary = 75000.50,
        is_active = true,
        start_date = "2023-01-15T09:00:00Z",
        addresses = {
            {
                street = "123 Main St",
                city = "New York",
                country = "USA",
                postal_code = "10001",
            },
            {
                street = "456 Oak Ave",
                city = "Los Angeles",
                country = "USA",
                postal_code = "90210",
            },
        },
        metadata = {
            "department" = "Engineering",
            "team" = "Backend",
        },
    }
    
    filename := "person.json"
    err := ojson.marshal_and_write(filename, person)
    if err != .None {
        log.errorf("Failed to write JSON: %v", err)
        return
    }
    
    log.infof("Successfully wrote person data to '%s'", filename)
    fmt.println()
}

demo_read_json :: proc() {
    log.info("Demo 2: Reading JSON and Converting to Struct")
    
    filename := "person.json"
    person: Person
    err := ojson.read_and_parse(filename, &person)
    if err != .None {
        log.errorf("Failed to read JSON: %v", err)
        return
    }
    
    log.infof("Successfully read person data from '%s'", filename)
    
    // Display the parsed struct
    log.info("Person data:")
    log.infof("  Name: %s", person.name)
    log.infof("  Age: %d", person.age)
    log.infof("  Email: %s", person.email)
    log.infof("  Salary: $%.2f", person.salary)
    log.infof("  Active: %t", person.is_active)
    log.infof("  Start Date: %s", person.start_date)
    
    log.info("  Addresses:")
    for address, i in person.addresses {
        log.infof("    %d: %s, %s, %s %s", i+1, address.street, address.city, address.country, address.postal_code)
    }
    
    log.info("  Metadata:")
    for key, value in person.metadata {
        log.infof("    %s: %s", key, value)
    }
    fmt.println()
}

demo_dynamic_json :: proc() {
    log.info("Demo 3: Dynamic JSON Parsing")
    
    json_string := `{
        "user_id": 12345,
        "username": "jane_smith",
        "profile": {
            "first_name": "Jane",
            "last_name": "Smith",
            "bio": "Software developer"
        },
        "settings": {
            "theme": "dark",
            "notifications": true
        }
    }`
    
    data := transmute([]u8)json_string
    json_map, err := ojson.json_to_map(data)
    if err != .None {
        log.errorf("Failed to parse dynamic JSON: %v", err)
        return
    }
    defer delete(json_map)
    
    log.info("Dynamic JSON parsing:")
    
    // Extract individual fields
    user_id: int
    if get_err := ojson.get_field_from_map(json_map, "user_id", &user_id); get_err == .None {
        log.infof("  User ID: %d", user_id)
    }
    
    username: string
    if get_err := ojson.get_field_from_map(json_map, "username", &username); get_err == .None {
        log.infof("  Username: %s", username)
    }
    
    // For nested objects, we'd need to extract them as json.Value and parse recursively
    log.info("  (Note: Nested object needs more juice)")
    fmt.println()
}

// Utility function to run all demos
main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    log.info("=== OJSON Demo ===\n")

    // Demo 1: Create sample data and write to json file
    demo_write_json()

    // Demo 2: Read json file and convert to struct
    demo_read_json()

    // Demo 3: How to handle json without knowing the structure beforehand
    demo_dynamic_json()

    log.info("\n=== Done ===")
}