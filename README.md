# Description

Flux is my own [brainfuck](https://en.wikipedia.org/wiki/Brainfuck) interpreter written in x86_64
assembly using GAS with AT&T syntax. Flux works only on Linux due to the use of Linux syscalls.

Flux can run many examples from [here](https://github.com/rdebath/Brainfuck/tree/master/testing).

## Dependencies

- GAS (as)
- ld

## Installation

```sh
# make
# ./flux examples/hello.b
```
