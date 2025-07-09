package omath

import "core:fmt"
import "core:math"
import "core:math/big"

// Returns the factorial of n as a big integer.
// For example, factorial(5) returns 120 as big.Int.
factorial :: proc(n: u64) -> big.Int {
  prod := big.Int{}
  big.int_set_from_integer(&prod, 1)
  for i in 1 ..= n {
    big.int_mul_digit(&prod, &prod, big.DIGIT(i))
  }
  return prod
}

/*
main :: proc() {
  fac := factorial(100)

  fac_digits, ok := big.int_to_string(&fac)
  if ok != .Okay {panic("failed to write big int")}
  sum: int
  for digit in fac_digits {
    ascii := cast(int)digit
    digit_value := ascii - '0'
    sum += digit_value
  }
  fmt.println(sum)
}
*/

// Returns true if n is a palindrome, false otherwise.
// A palindrome is a number that reads the same forwards and backwards.
// For example, 121, 12321, and 1234321 are palindromes.
is_palindrome :: proc(n: i64) -> bool {
  remainders: [dynamic]i64
  var := n
  for var > 0 {
    append(&remainders, var % 10)
    var /= 10
  }
  for i in 0 ..< len(remainders) {
    if remainders[i] != remainders[len(remainders) - 1 - i] {return false}
  }
  return true
}

// Returns the sum of the squares of all integers from start to end.
// For example, sum_of_squares(1, 10) returns 1² + 2² + ... + 10² = 385.
sum_of_squares :: proc(start, end: int) -> int {
  sum := 0
  for i in start ..= end {
    sum += i * i
  }
  return sum
}

// Returns the square of the sum of all integers from start to end.
// For example, square_of_sum(1, 10) returns (1 + 2 + ... + 10)² = 55² = 3025.
square_of_sum :: proc(start, end: int) -> int {
  sum := 0
  for i in start ..= end {
    sum += i
  }
  return sum * sum
}

// Returns true if n is a square number, false otherwise,
// uses the square root to determine if n is square.
// A square number is an integer that is the square of another integer.
// For example, 1, 4, 9, 16, 25, 36, etc. are square numbers.
is_square_number :: proc(n: int) -> bool {
  root := math.round(math.sqrt(cast(f64)n))
  return n == cast(int)(root * root)
}