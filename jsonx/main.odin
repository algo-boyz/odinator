package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

// Define a struct that matches your JSON structure
Person :: struct {
    name: string,
    age: int,
    email: string,
    addresses: []Address,
}

Address :: struct {
    street: string `json:"street_line_one"`,
    city: string,
    country: string,
}

main :: proc() {
    path := "test.json"

    // Read the JSON file
    data, ok := os.read_entire_file(path)
    if !ok {
        fmt.println("failed to read file %s", path)
        return
    }
    defer delete(data)
    
    // Parse JSON content into struct
    person: Person
    if err := json.unmarshal(data, &person); err != nil {
        fmt.printf("Error parsing JSON: %v\n", err)
        return
    }
    
    // Use the struct
    fmt.printf("Name: %s\n", person.name)
    fmt.printf("Age: %d\n", person.age)
    fmt.printf("Email: %s\n", person.email)
    
    fmt.println("\nAddresses:")
    
    for address in person.addresses {
        fmt.printf("- %s, %s, %s\n", 
            address.street,
            address.city,
            address.country)
    }
}