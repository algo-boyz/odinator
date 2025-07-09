package main

import "base:runtime"
import "core:fmt"
import "core:encoding/csv"
import "core:log"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import "../"

demo_write_csv :: proc() {
    log.info("Demo 1: Writing CSV Data")

    // Create sample CSV data
    csv_data := [][]string{
        {"name", "age", "salary", "active", "start_date", "middle_name", "bonus", "manager"},
        {"John Doe", "30", "75000.50", "true", "2023-01-15T09:00:00Z", "William", "5000.00", "false"},
        {"Jane Smith", "28", "82000.75", "true", "2022-11-01T08:30:00Z", "", "7500.50", "true"},
        {"Bob Johnson", "35", "68000.00", "false", "2021-06-10T10:15:00Z", "Robert", "", "false"},
    }

    // Write to CSV file
    filename := "employees.csv"
    err := ocsv.write_file(filename, csv_data)
    if err != .None {
        log.infof("Failed to write CSV: %v\n", err)
        return
    }

    log.infof("Successfully wrote %d rows to '%s'\n", len(csv_data), filename)

    log.info("\nCSV content:")
    for row, i in csv_data {
        log.infof("Row %d: %v\n", i, row)
    }
    fmt.println()
}

demo_read_csv :: proc() {
    log.info("Demo 2: Reading CSV and Converting to Structs")

    // Read the CSV file
    filename := "employees.csv"
    csv_data, err := ocsv.read_file(filename)
    if err != .None {
        log.infof("Failed to read CSV: %v\n", err)
        return
    }
    log.infof("Read %d rows from '%s'\n", len(csv_data), filename)

    if len(csv_data) < 2 {
        log.info("CSV file doesn't have enough data")
        return
    }

    // First row is the header
    header := csv_data[0]
    log.infof("Headers: %v\n", header)

    // Convert data rows to Person structs
    people: [dynamic]Person
    defer delete(people)

    for i := 1; i < len(csv_data); i += 1 {
        person: Person
        conv_err := ocsv.row_to_struct(csv_data[i], &person, header)
        if conv_err != .None {
            log.infof("Failed to convert row %d to Person struct: %v\n", i, conv_err)
            continue
        }
        append(&people, person)
    }

    // Display the converted structs
    log.info("\nConverted Person structs:")
    for person, i in people {
        log.infof("Person %d:\n", i+1)
        log.infof("  Name: %s\n", person.name)
        log.infof("  Age: %d\n", person.age)
        log.infof("  Salary: $%.2f\n", person.salary)
        log.infof("  Active: %t\n", person.is_active)
        log.infof("  Start Date: %v\n", person.start_date)

        if person.middle_name != nil {
            log.infof("  Middle Name: %s\n", person.middle_name^)
        } else {
            log.infof("  Middle Name: <not set>\n")
        }

        if person.bonus != nil {
            log.infof("  Bonus: $%.2f\n", person.bonus^)
        } else {
            log.infof("  Bonus: <not set>\n")
        }

        if person.is_manager != nil {
            log.infof("  Manager: %t\n", person.is_manager^)
        } else {
            log.infof("  Manager: <not set>\n")
        }
        fmt.println()
    }
}

// Example struct representing a person with various data types
Person :: struct {
    name:        string    `csv:"name"`,
    age:         i32       `csv:"age"`,
    salary:      f64       `csv:"salary"`,
    is_active:   bool      `csv:"active"`,
    start_date:  time.Time `csv:"start_date"`,

    // Optional fields (pointers)
    middle_name: ^string   `csv:"middle_name"`,
    bonus:       ^f64      `csv:"bonus"`,
    is_manager:  ^bool     `csv:"manager"`,
}

demo_struct_to_csv :: proc() {
    log.info("Demo 3: Converting Structs to CSV Rows")
    // Create some Persons
    middle_name := "Alexander"
    bonus := 12000.0
    is_manager := true
    start_date_alice, ok1 := time.datetime_to_time(2022, 1, 1, 0, 0, 0, 0)
    if !ok1 {
        log.info("Failed to create start date for Alice")
        return
    }
    start_date_charlie, ok2 := time.datetime_to_time(2023, 1, 1, 0, 0, 0, 0)
    if !ok2 {
        log.info("Failed to create start date for Charlie")
        return
    }
    people := []Person{
        {
            name = "Alice Cooper",
            age = 32,
            salary = 95000.0,
            is_active = true,
            start_date = start_date_alice,
            middle_name = &middle_name,
            bonus = &bonus,
            is_manager = &is_manager,
        },
        {
            name = "Charlie Brown",
            age = 29,
            salary = 72000.0,
            is_active = true,
            start_date = start_date_charlie,
            // middle_name, bonus, is_manager are nil (not set)
        },
    }

    // Convert structs to CSV rows
    csv_rows: [dynamic][]string
    defer {
        for row in csv_rows {
            delete(row)
        }
        delete(csv_rows)
    }

    // Add header row
    // Dynamically generate headers from struct tags
    header_row, header_err := ocsv.struct_to_header_row(Person{})
    if header_err == .None {
        append(&csv_rows, header_row)
    } else {
        log.infof("Failed to generate headers: %v\n", header_err)
        return
    }

    for person in people {
        row, row_err := ocsv.struct_to_row(person)
        if row_err != .None {
            log.infof("Failed to convert Person to CSV row: %v\n", row_err)
            continue
        }
        append(&csv_rows, row)
    }

    // Write to a new CSV file
    output_filename := "generated_employees.csv"
    write_err := ocsv.write_file(output_filename, csv_rows[:])
    if write_err != .None {
        log.infof("Failed to write generated CSV: %v\n", write_err)
        return
    }
    log.infof("Successfully generated CSV with %d rows to '%s'\n", len(csv_rows), output_filename)

    // Display the CSV rows
    log.info("\nGenerated CSV rows:")
    for row, i in csv_rows {
        log.infof("Row %d: %v\n", i, row)
    }
    fmt.println()
}

// Example struct for products
Product :: struct {
    id:          i32    `csv:"product_id"`,
    name:        string `csv:"product_name"`,
    price:       f32    `csv:"price"`,
    in_stock:    bool   `csv:"in_stock"`,
    category:    string `csv:"category"`,
}

demo_products :: proc() {
    log.info("Demo 4: Working with Products")

    // Create product data
    products := []Product{
        {id = 1001, name = "Laptop", price = 1299.99, in_stock = true, category = "Electronics"},
        {id = 1002, name = "Mouse", price = 29.99, in_stock = true, category = "Accessories"},
        {id = 1003, name = "Monitor", price = 449.50, in_stock = false, category = "Electronics"},
        {id = 1004, name = "Keyboard", price = 89.99, in_stock = true, category = "Accessories"},
    }

    // Convert products to CSV
    product_csv: [dynamic][]string
    defer {
        for row in product_csv {
            delete(row)
        }
        delete(product_csv)
    }

    // Add CSV header
    header_products, header_err := ocsv.struct_to_header_row(Product{})
    if header_err == .None {
        append(&product_csv, header_products)
    } else {
        log.infof("Failed to generate product headers: %v\n", header_err)
        return
    }

    // Convert each product to a CSV row
    for product in products {
        row, err := ocsv.struct_to_row(product)
        if err != .None {
            log.infof("Failed to convert product to CSV: %v\n", err)
            continue
        }
        append(&product_csv, row)
    }

    // Write products CSV
    products_filename := "products.csv"
    write_err := ocsv.write_file(products_filename, product_csv[:])
    if write_err != .None {
        log.infof("Failed to write products CSV: %v\n", write_err)
        return
    }

    log.infof("Successfully wrote %d products to '%s'\n", len(products), products_filename)

    // Read it back and display
    read_data, read_err := ocsv.read_file(products_filename)
    if read_err != .None {
        log.infof("Failed to read products CSV: %v\n", read_err)
        return
    }

    log.info("\nProducts from CSV:")
    if len(read_data) > 0 {
        log.infof("Headers: %v\n", read_data[0])
        for i := 1; i < len(read_data); i += 1 {
            log.infof("Product %d: %v\n", i, read_data[i])
        }
    }

    // Convert back to Product structs
    log.info("\nConverted back to Product structs:")
    if len(read_data) > 1 {
        for i := 1; i < len(read_data); i += 1 {
            product: Product
            conv_err := ocsv.row_to_struct(read_data[i], &product, read_data[0])
            if conv_err != .None {
                log.infof("Failed to convert row %d to Product: %v\n", i, conv_err)
                continue
            }

            log.infof("  ID: %d, Name: %s, Price: $%.2f, In Stock: %t, Category: %s\n",
                       product.id, product.name, product.price, product.in_stock, product.category)
        }
    } else {
        log.info("No product data to convert.")
    }
    fmt.println()
}

main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    log.info("=== OCSV Demo ===\n")

    // Demo 1: Create sample data and write to CSV
    demo_write_csv()

    // Demo 2: Read CSV and convert to structs
    demo_read_csv()

    // Demo 3: Convert structs to CSV rows
    demo_struct_to_csv()

    // Demo 4: Work with products
    demo_products()

    log.info("\n=== Done ===")
}