# RFC-3339 date format parser

Parse the [RFC 3339 date & time spec](https://datatracker.ietf.org/doc/html/rfc3339)

```odin
    import dates "RFC_3339_date_parser"

    date, err := dates.from_string("1996-02-29 16:39:57-08:00")
    fmt.println(dates.to_string(date)) // prints: 1996-02-29 16:39:57-08:00 NONE

    assert(dates.is_date_lax("1996-02-29 doesn't matter")) // quickly determines if string looks like a date
```