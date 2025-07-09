package otime

import "base:intrinsics"
import "core:strconv"
import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:time"

DateError :: enum {
    NONE,

    FAILED_AT_YEAR, 
    FAILED_AT_MONTH,
    FAILED_AT_DAY,
    FAILED_AT_HOUR,
    FAILED_AT_MINUTE,
    FAILED_AT_SECOND,
    FAILED_AT_OFFSET_HOUR,
    FAILED_AT_OFFSET_MINUTE,

    YEAR_OUT_OF_BOUNDS,
    MONTH_OUT_OF_BOUNDS,
    DAY_OUT_OF_BOUNDS,
    HOUR_OUT_OF_BOUNDS,
    MINUTE_OUT_OF_BOUNDS,
    SECOND_OUT_OF_BOUNDS,
    OFFSET_HOUR_OUT_OF_BOUNDS,
    OFFSET_MINUTE_OUT_OF_BOUNDS,

    FAILED_AT_TIME_SEPERATOR,
    INVALID_DATE_FORMAT,
    INVALID_WEEKDAY,
}

time_separators : [] string = { "t", "T", " " }
offset_separators : [] string = { "z", "Z", "+", "-" }

DayOfTheWeek :: enum u8 {
    Mon = 0,
    Tue = 1,
    Wed = 2,
    Thu = 3,
    Fri = 4,
    Sat = 5,
    Sun = 6,
}

Date :: struct {
    year, month, day : u32,
    hour, minute     : u8,
    second           : f32,
    offset_hour      : i8,  // -23 to +23
    offset_minute    : i8,  // -59 to +59
    day_of_the_week  : DayOfTheWeek,
}

// Create a new date with current system time
now :: proc() -> Date {
    t := time.now()
    year, month, day := time.date(t)
    hour, minute, second := time.clock(t)
    
    date := Date{
        year = u32(year),
        month = u32(month),
        day = u32(day),
        hour = u8(hour),
        minute = u8(minute),
        second = f32(second),
        offset_hour = 0,
        offset_minute = 0,
    }
    date.day_of_the_week = calculate_day_of_week(date.year, date.month, date.day)
    return date
}

// Create a date from components
make_date :: proc(year: u32, month: u32, day: u32, hour: u8 = 0, minute: u8 = 0, second: f32 = 0, offset_hour: i8 = 0, offset_minute: i8 = 0) -> (Date, DateError) {
    date := Date{
        year = year,
        month = month,
        day = day,
        hour = hour,
        minute = minute,
        second = second,
        offset_hour = offset_hour,
        offset_minute = offset_minute,
    }
    // Validate
    if !between(year, 1, 9999) do return date, .YEAR_OUT_OF_BOUNDS
    if !between(month, 1, 12) do return date, .MONTH_OUT_OF_BOUNDS
    if !between(day, 1, days_in_month(year, month)) do return date, .DAY_OUT_OF_BOUNDS
    if !between(hour, 0, 23) do return date, .HOUR_OUT_OF_BOUNDS
    if !between(minute, 0, 59) do return date, .MINUTE_OUT_OF_BOUNDS
    if !between(second, 0, 60) do return date, .SECOND_OUT_OF_BOUNDS
    if !between(offset_hour, -23, 23) do return date, .OFFSET_HOUR_OUT_OF_BOUNDS
    if !between(offset_minute, -59, 59) do return date, .OFFSET_MINUTE_OUT_OF_BOUNDS
    
    date.day_of_the_week = calculate_day_of_week(year, month, day)
    return date, .NONE
}

from_string :: proc(date_str: string) -> (out: Date, err: DateError) {
    date := date_str
    
    // Parse date part (YYYY-MM-DD)
    if len(date) >= 10 && date[4] == '-' && date[7] == '-' {
        year_str := date[0:4]
        month_str := date[5:7]
        day_str := date[8:10]
        
        year, year_ok := strconv.parse_u64(year_str, 10)
        if !year_ok do return out, .FAILED_AT_YEAR
        
        month, month_ok := strconv.parse_u64(month_str, 10)
        if !month_ok do return out, .FAILED_AT_MONTH
        
        day, day_ok := strconv.parse_u64(day_str, 10)
        if !day_ok do return out, .FAILED_AT_DAY
        
        out.year = u32(year)
        out.month = u32(month)
        out.day = u32(day)
        
        // Validate date components
        if !between(out.month, 1, 12) do return out, .MONTH_OUT_OF_BOUNDS
        if !between(out.day, 1, days_in_month(out.year, out.month)) do return out, .DAY_OUT_OF_BOUNDS
        
        date = date[10:]
    }
    // Parse time separator if present
    if len(date) > 0 {
        if !slice.any_of(time_separators, date[0:1]) {
            return out, .FAILED_AT_TIME_SEPERATOR
        }
        date = date[1:]
    }
    // Parse time part (HH:MM:SS)
    if len(date) >= 8 && date[2] == ':' && date[5] == ':' {
        hour_str := date[0:2]
        minute_str := date[3:5]
        
        hour, hour_ok := strconv.parse_u64(hour_str, 10)
        if !hour_ok do return out, .FAILED_AT_HOUR
        
        minute, minute_ok := strconv.parse_u64(minute_str, 10)
        if !minute_ok do return out, .FAILED_AT_MINUTE
        
        out.hour = u8(hour)
        out.minute = u8(minute)
        
        if !between(out.hour, 0, 23) do return out, .HOUR_OUT_OF_BOUNDS
        if !between(out.minute, 0, 59) do return out, .MINUTE_OUT_OF_BOUNDS
        
        date = date[6:]
        
        // Find offset separator
        offset_pos := -1
        for sep in offset_separators {
            if pos := strings.index(date, sep); pos != -1 {
                offset_pos = pos
                break
            }
        }
        // Parse seconds
        second_str := date[:offset_pos if offset_pos != -1 else len(date)]
        second, second_ok := strconv.parse_f32(second_str)
        if !second_ok do return out, .FAILED_AT_SECOND
        
        out.second = second
        if !between(out.second, 0, 60) do return out, .SECOND_OUT_OF_BOUNDS
        // Parse timezone offset
        if offset_pos != -1 {
            offset_str := date[offset_pos:]
            if strings.to_lower(offset_str[0:1]) == "z" {
                out.offset_hour = 0
                out.offset_minute = 0
            } else {
                sign := offset_str[0:1]
                if len(offset_str) >= 6 && offset_str[3] == ':' {
                    offset_hour_str := offset_str[1:3]
                    offset_minute_str := offset_str[4:6]
                    
                    offset_hour, offset_hour_ok := strconv.parse_u64(offset_hour_str, 10)
                    if !offset_hour_ok do return out, .FAILED_AT_OFFSET_HOUR
                    
                    offset_minute, offset_minute_ok := strconv.parse_u64(offset_minute_str, 10)
                    if !offset_minute_ok do return out, .FAILED_AT_OFFSET_MINUTE
                    
                    out.offset_hour = i8(offset_hour)
                    out.offset_minute = i8(offset_minute)
                    
                    if sign == "-" {
                        out.offset_hour = -out.offset_hour
                        out.offset_minute = -out.offset_minute
                    }
                    if !between(out.offset_hour, -23, 23) do return out, .OFFSET_HOUR_OUT_OF_BOUNDS
                    if !between(out.offset_minute, -59, 59) do return out, .OFFSET_MINUTE_OUT_OF_BOUNDS
                }
            }
        }
    }
    // Calculate day of week
    if out.year > 0 && out.month > 0 && out.day > 0 {
        out.day_of_the_week = calculate_day_of_week(out.year, out.month, out.day)
    }
    return out, .NONE
}

to_string :: proc(date: Date, time_sep := 'T') -> (out: string, err: DateError) {
    // Validate input
    if !between(date.year, 1, 9999) do return "", .YEAR_OUT_OF_BOUNDS
    if !between(date.month, 1, 12) do return "", .MONTH_OUT_OF_BOUNDS
    if !between(date.day, 1, days_in_month(date.year, date.month)) do return "", .DAY_OUT_OF_BOUNDS
    if !between(date.hour, 0, 23) do return "", .HOUR_OUT_OF_BOUNDS
    if !between(date.minute, 0, 59) do return "", .MINUTE_OUT_OF_BOUNDS
    if !between(date.second, 0, 60) do return "", .SECOND_OUT_OF_BOUNDS
    if !between(date.offset_hour, -23, 23) do return "", .OFFSET_HOUR_OUT_OF_BOUNDS
    if !between(date.offset_minute, -59, 59) do return "", .OFFSET_MINUTE_OUT_OF_BOUNDS
    
    b : strings.Builder
    strings.builder_init_len_cap(&b, 0, 32)
    
    fmt.sbprintf(&b, "%04d-%02d-%02d", date.year, date.month, date.day)
    strings.write_rune(&b, time_sep)
    fmt.sbprintf(&b, "%02d:%02d:%06.3f", date.hour, date.minute, date.second)
    
    if date.offset_hour == 0 && date.offset_minute == 0 {
        strings.write_rune(&b, 'Z')
    } else {
        if date.offset_hour < 0 || date.offset_minute < 0 {
            strings.write_rune(&b, '-')
        } else {
            strings.write_rune(&b, '+')
        }
        fmt.sbprintf(&b, "%02d:%02d", abs(date.offset_hour), abs(date.offset_minute))
    }
    return strings.to_string(b), .NONE
}

// Format date with custom format string
format :: proc(date: Date, format_str: string) -> string {
    result := format_str
    // Year formats
    result, _ = strings.replace_all(result, "YYYY", fmt.tprintf("%04d", date.year))
    result, _ = strings.replace_all(result, "YY", fmt.tprintf("%02d", date.year % 100))
    
    // Month formats
    result, _ = strings.replace_all(result, "MM", fmt.tprintf("%02d", date.month))
    result, _ = strings.replace_all(result, "MMM", get_month_name_short(date.month))
    result, _ = strings.replace_all(result, "MMMM", get_month_name_full(date.month))
    
    // Day formats
    result, _ = strings.replace_all(result, "DD", fmt.tprintf("%02d", date.day))
    result, _ = strings.replace_all(result, "D", fmt.tprintf("%d", date.day))
    
    // Weekday formats
    result, _ = strings.replace_all(result, "dddd", get_weekday_name_full(date.day_of_the_week))
    result, _ = strings.replace_all(result, "ddd", get_weekday_name_short(date.day_of_the_week))
    
    // Hour formats
    result, _ = strings.replace_all(result, "HH", fmt.tprintf("%02d", date.hour))
    result, _ = strings.replace_all(result, "H", fmt.tprintf("%d", date.hour))
    result, _ = strings.replace_all(result, "hh", fmt.tprintf("%02d", date.hour % 12 if date.hour % 12 != 0 else 12))
    result, _ = strings.replace_all(result, "h", fmt.tprintf("%d", date.hour % 12 if date.hour % 12 != 0 else 12))
    
    // Minute formats
    result, _ = strings.replace_all(result, "mm", fmt.tprintf("%02d", date.minute))
    result, _ = strings.replace_all(result, "m", fmt.tprintf("%d", date.minute))
    
    // Second formats
    result, _ = strings.replace_all(result, "ss", fmt.tprintf("%02.0f", date.second))
    result, _ = strings.replace_all(result, "s", fmt.tprintf("%.0f", date.second))
    
    // AM/PM
    result, _ = strings.replace_all(result, "A", "AM" if date.hour < 12 else "PM")
    result, _ = strings.replace_all(result, "a", "am" if date.hour < 12 else "pm")
    
    return result
}

// Calculate day of week using Zeller's congruence
calculate_day_of_week :: proc(year: u32, month: u32, day: u32) -> DayOfTheWeek {
    y := year
    m := month
    // Adjust for Zeller's congruence (Jan and Feb are counted as months 13 and 14 of previous year)
    if m < 3 {
        m += 12
        y -= 1
    }
    // Zeller's congruence
    h := (day + ((13 * (m + 1)) / 5) + y + (y / 4) - (y / 100) + (y / 400)) % 7
    // Convert to enum (Zeller: 0=Sat, 1=Sun, 2=Mon, ...)
    // enum: 0=Mon, 1=Tue, ..., 6=Sun
    weekday := (h + 5) % 7
    return DayOfTheWeek(weekday)
}

// Date arithmetic
add_days :: proc(date: Date, days: i32) -> Date {
    result := date
    if days > 0 {
        for i in 0..<days {
            result = next_day(result)
        }
    } else if days < 0 {
        for i in 0..<(-days) {
            result = previous_day(result)
        }
    }
    return result
}

add_months :: proc(date: Date, months: i32) -> Date {
    result := date
    new_month := i32(result.month) + months
    new_year := i32(result.year)
    
    // Handle year overflow/underflow
    for new_month > 12 {
        new_month -= 12
        new_year += 1
    }
    for new_month < 1 {
        new_month += 12
        new_year -= 1
    }
    result.month = u32(new_month)
    result.year = u32(new_year)

    // Adjust day if it's invalid for the new month
    max_day := days_in_month(result.year, result.month)
    if result.day > max_day {
        result.day = max_day
    }
    result.day_of_the_week = calculate_day_of_week(result.year, result.month, result.day)
    return result
}

add_years :: proc(date: Date, years: i32) -> Date {
    result := date
    result.year = u32(i32(result.year) + years)
    
    // Handle leap year edge case (Feb 29 -> Feb 28)
    if result.month == 2 && result.day == 29 && !is_leap_year(result.year) {
        result.day = 28
    }
    result.day_of_the_week = calculate_day_of_week(result.year, result.month, result.day)
    return result
}

// Date comparison
is_before :: proc(a, b: Date) -> bool {
    if a.year != b.year do return a.year < b.year
    if a.month != b.month do return a.month < b.month
    if a.day != b.day do return a.day < b.day
    if a.hour != b.hour do return a.hour < b.hour
    if a.minute != b.minute do return a.minute < b.minute
    return a.second < b.second
}

is_after :: proc(a, b: Date) -> bool {
    return is_before(b, a)
}

is_equal :: proc(a, b: Date) -> bool {
    return a.year == b.year && a.month == b.month && a.day == b.day &&
           a.hour == b.hour && a.minute == b.minute && a.second == b.second
}

// Get difference in days between two dates
days_between :: proc(from, to: Date) -> i32 {
    if is_equal(from, to) do return 0
    
    earlier := from
    later := to
    sign := i32(1)
    
    if is_after(from, to) {
        earlier = to
        later = from
        sign = -1
    }
    days := i32(0)
    current := earlier
    
    for !is_equal(current, later) {
        if current.year == later.year && current.month == later.month {
            days += i32(later.day - current.day)
            break
        }
        days += i32(days_in_month(current.year, current.month) - current.day + 1)
        current = Date{
            year = current.year,
            month = current.month + 1,
            day = 1,
            hour = current.hour,
            minute = current.minute,
            second = current.second,
            offset_hour = current.offset_hour,
            offset_minute = current.offset_minute,
        }
        if current.month > 12 {
            current.month = 1
            current.year += 1
        }
    }
    return days * sign
}

is_weekend :: proc(date: Date) -> bool {
    return date.day_of_the_week == .Sat || date.day_of_the_week == .Sun
}

is_leap_year :: proc(year: u32) -> bool {
    return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
}

is_twentieth_century :: proc(year: u32) -> bool {
    return year >= 1901 && year <= 2000
}

is_twenty_first_century :: proc(year: u32) -> bool {
    return year >= 2001 && year <= 2100
}

next_day :: proc(date: Date) -> Date {
    next_day_of_week := get_next_day_of_week(date.day_of_the_week)
    next_day, next_month, next_year := get_next_day_month_year(date.day, date.month, date.year)
    return Date{
        year = next_year,
        month = next_month,
        day = next_day,
        hour = date.hour,
        minute = date.minute,
        second = date.second,
        offset_hour = date.offset_hour,
        offset_minute = date.offset_minute,
        day_of_the_week = next_day_of_week,
    }
}

previous_day :: proc(date: Date) -> Date {
    prev_day_of_week := get_previous_day_of_week(date.day_of_the_week)
    prev_day, prev_month, prev_year := get_previous_day_month_year(date.day, date.month, date.year)
    return Date{
        year = prev_year,
        month = prev_month,
        day = prev_day,
        hour = date.hour,
        minute = date.minute,
        second = date.second,
        offset_hour = date.offset_hour,
        offset_minute = date.offset_minute,
        day_of_the_week = prev_day_of_week,
    }
}

get_weekday_name_full :: proc(day: DayOfTheWeek) -> string {
    switch day {
    case .Mon: return "Monday"
    case .Tue: return "Tuesday"
    case .Wed: return "Wednesday"
    case .Thu: return "Thursday"
    case .Fri: return "Friday"
    case .Sat: return "Saturday"
    case .Sun: return "Sunday"
    }
    return "Unknown"
}

get_weekday_name_short :: proc(day: DayOfTheWeek) -> string {
    switch day {
    case .Mon: return "Mon"
    case .Tue: return "Tue"
    case .Wed: return "Wed"
    case .Thu: return "Thu"
    case .Fri: return "Fri"
    case .Sat: return "Sat"
    case .Sun: return "Sun"
    }
    return "Unk"
}

get_month_name_full :: proc(month: u32) -> string {
    switch month {
    case 1: return "January"
    case 2: return "February"
    case 3: return "March"
    case 4: return "April"
    case 5: return "May"
    case 6: return "June"
    case 7: return "July"
    case 8: return "August"
    case 9: return "September"
    case 10: return "October"
    case 11: return "November"
    case 12: return "December"
    }
    return "Unknown"
}

get_month_name_short :: proc(month: u32) -> string {
    switch month {
    case 1: return "Jan"
    case 2: return "Feb"
    case 3: return "Mar"
    case 4: return "Apr"
    case 5: return "May"
    case 6: return "Jun"
    case 7: return "Jul"
    case 8: return "Aug"
    case 9: return "Sep"
    case 10: return "Oct"
    case 11: return "Nov"
    case 12: return "Dec"
    }
    return "Unk"
}

@private
get_next_day_month_year :: proc(day: u32, month: u32, year: u32) -> (next_day: u32, next_month: u32, next_year: u32) {
    next_day = day + 1
    next_month = month
    next_year = year
    if next_day > days_in_month(year, month) {
        next_day = 1
        next_month += 1
        if next_month > 12 {
            next_month = 1
            next_year += 1
        }
    }
    return
}

@private
get_previous_day_month_year :: proc(day: u32, month: u32, year: u32) -> (prev_day: u32, prev_month: u32, prev_year: u32) {
    prev_day = day - 1
    prev_month = month
    prev_year = year
    if prev_day == 0 {
        prev_month -= 1
        if prev_month == 0 {
            prev_month = 12
            prev_year -= 1
        }
        prev_day = days_in_month(prev_year, prev_month)
    }
    return
}

@private
get_next_day_of_week :: proc(day: DayOfTheWeek) -> DayOfTheWeek {
    return DayOfTheWeek((u8(day) + 1) % 7)
}

@private
get_previous_day_of_week :: proc(day: DayOfTheWeek) -> DayOfTheWeek {
    return DayOfTheWeek((u8(day) + 6) % 7)  // +6 is equivalent to -1 mod 7
}

@private
days_in_month :: proc(year: u32, month: u32) -> u32 {
    switch month {
    case 1, 3, 5, 7, 8, 10, 12:
        return 31
    case 4, 6, 9, 11:
        return 30
    case 2:
        return 29 if is_leap_year(year) else 28
    }
    return 0
}

// Helper functions for bounds checking
@private
between :: proc(a, lo, hi: $T) -> bool where intrinsics.type_is_numeric(T) {
    return a >= lo && a <= hi
}

@private
are_all_numbers :: proc(s: string) -> bool {
    for r in s {
        if r < '0' || r > '9' do return false
    }
    return true
}

// Initialize with default values
init :: proc() -> Date {
    return Date{
        day = 1,
        month = 1,
        year = 1900,
        day_of_the_week = .Mon,
    }
}

// Check if date string format is valid (lightweight validation)
is_date_lax :: proc(date_str: string) -> bool {
    if len(date_str) < 8 do return false
    // Check for basic date format YYYY-MM-DD
    if len(date_str) >= 10 {
        return are_all_numbers(date_str[0:4]) &&
               date_str[4] == '-' &&
               are_all_numbers(date_str[5:7]) &&
               date_str[7] == '-' &&
               are_all_numbers(date_str[8:10])
    }
    // Check for basic time format HH:MM:SS
    if len(date_str) >= 8 {
        return are_all_numbers(date_str[0:2]) &&
               date_str[2] == ':' &&
               are_all_numbers(date_str[3:5]) &&
               date_str[5] == ':' &&
               are_all_numbers(date_str[6:8])
    }
    return false
}