package regular

import "core:fmt"
import "core:text/regex"
import "core:testing"

REGEX_FILEPATH_PATTERN :: "^[a-zA-Z0-9_\\\\/\\.]*$"
REGEX_ALPHANUM_PATTERN :: "^[a-zA-Z0-9_]*$"

match :: proc{ match_no_flags, match_flags }

match_no_flags :: proc(grammar: string, pattern: string) -> (matched: bool) {
    return match_flags(grammar, pattern, {})
}

match_flags :: proc(grammar: string, pattern: string, flags: regex.Flags) -> (matched: bool) {

    match_iterator, err := regex.create_iterator(grammar, pattern, { .No_Capture } + flags)
    defer regex.destroy_iterator(match_iterator)
    if err != nil {
        fmt.eprintln("Could not create regex match iterator, defaulting to no match")
        return
    }

    _, _, matched = regex.match_iterator(&match_iterator)
    return
}

@(test)
match_test :: proc(t: ^testing.T) {
    matched := match("ABCdaf932903215/\\.", "^[a-zA-Z0-9_\\\\/\\.]*$")
    testing.expect(t, matched)

    new_matched := match("ABCdaf932903215*&*(*^", "^[a-zA-Z0-9_]*$")
    testing.expect(t, !new_matched)
}