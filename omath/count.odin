package omath

import "core:fmt"
import "core:strings"

START :: 1
TARGET :: 100

int_to_string :: proc(i: int) -> string {
  switch i {
  case 1 ..= 9:
    return single_digit(i)
  case 10 ..= 99:
    return two_digit(i)
  case 100 ..= 999:
    return three_digit(i)
  case 1000:
    return "onethousand"
  }
  unreachable()
}

single_digit :: proc(i: int) -> string {
  switch i {
  case 1:
    return "one"
  case 2:
    return "two"
  case 3:
    return "three"
  case 4:
    return "four"
  case 5:
    return "five"
  case 6:
    return "six"
  case 7:
    return "seven"
  case 8:
    return "eight"
  case 9:
    return "nine"
  case:
    unreachable()
  }
}

two_digit :: proc(i: int) -> string {
  switch i {
  case 10:
    return "ten"
  case 11:
    return "eleven"
  case 12:
    return "twelve"
  case 13:
    return "thirteen"
  case 14:
    return "fourteen"
  case 15:
    return "fifteen"
  case 16:
    return "sixteen"
  case 17:
    return "seventeen"
  case 18:
    return "eighteen"
  case 19:
    return "nineteen"
  case 20 ..= 29:
    return simple_two_digit("twenty", i - 20)
  case 30 ..= 39:
    return simple_two_digit("thirty", i - 30)
  case 40 ..= 49:
    return simple_two_digit("forty", i - 40)
  case 50 ..= 59:
    return simple_two_digit("fifty", i - 50)
  case 60 ..= 69:
    return simple_two_digit("sixty", i - 60)
  case 70 ..= 79:
    return simple_two_digit("seventy", i - 70)
  case 80 ..= 89:
    return simple_two_digit("eighty", i - 80)
  case 90 ..= 99:
    return simple_two_digit("ninety", i - 90)
  case:
    unreachable()
  }

  simple_two_digit :: proc(prefix: string, digit: int) -> string {
    if digit == 0 {return prefix}
    return strings.concatenate({prefix, single_digit(digit)})
  }
}

three_digit :: proc(i: int) -> string {
  prefix := single_digit(i / 100)
  if i % 100 == 0 {return strings.concatenate({prefix, "hundred"})}
  if i % 100 < 10 {return strings.concatenate({prefix, "hundred", "and", single_digit(i % 100)})}
  return strings.concatenate({prefix, "hundred", "and", two_digit(i % 100)})
}

/*
main :: proc() {
  count := 0
  for i in START ..= TARGET {
    str := int_to_string(i)
    fmt.println(str)
    count += len(str)
  }
  fmt.println(count)
}
*/