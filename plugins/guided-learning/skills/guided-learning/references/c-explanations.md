# Explaining C to a learner

Use real values from the project in every example. A bit table beats a sentence.

## Bit idioms

| Idiom | Code | What happens |
|---|---|---|
| Make a mask for bit n | `1UL << n` | a 1 moved n places left; `UL` = unsigned 32-bit, so bit 31 is legal (plain `1 << 31` is undefined) |
| 64-bit mask (pins ≥ 32) | `1ULL << n` | same, 64-bit; needed for `gpio_config_t.pin_bit_mask` |
| Set a bit | `x \| MASK` | OR: 1 wherever either has a 1 |
| Clear a bit | `x & ~MASK` | `~` flips every bit of the mask, AND keeps everything except that bit |
| Test a bit | `if (x & MASK)` | non-zero means the bit is set |
| Combine fields | `a \| (b << 8) \| (c << 16)` | each field moved into its own byte |
| Extract a byte | `(x >> (8 * k)) & 0xFF` | shift byte k down to the bottom, AND keeps only 8 bits |
| Toggle 0 ↔ 1 | `i ^ 1` | XOR with 1 flips the lowest bit |
| Rising edge | `(now & F) && !(before & F)` | set now, not set before |

Show values as hex **and** binary for at least one example, with bit numbers above the columns.

## Common "why not X?" answers

- **`#define` constant vs `static const`:** in C (unlike C++), a `const` variable is not a constant expression, so it can't initialise a file-scope variable or size an array in all cases. A `static const` object may also be placed in flash (`.rodata`), which matters for code that runs in an ISR during flash writes. Integer constants can also be `enum` values, which are constant expressions and have a type the debugger shows.
- **Function-like macro vs function:** a macro is text replacement before compiling. Use it when the result must be a compile-time constant (file-scope initialisers), or for token pasting (`SEG_##x`). Otherwise prefer a `static inline` function: it has type checking and evaluates each argument once. Macro rules: parenthesise every argument and the whole result, cast to the right type, and never pass an argument with side effects (`WORD(i++, …)`).
- **`static` at file scope:** visible only inside this `.c` file ("private"). **`static` inside a function:** keeps its value between calls and lives in RAM like a global.
- **`volatile`:** every read and write really goes to memory (the compiler may not cache it in a register or drop "useless" writes); on Xtensa it also adds a `memw` barrier. It does not make several operations atomic.
- **Shadow copy:** a private copy owned by the single writer, so the writer never has to read the shared variable back.
