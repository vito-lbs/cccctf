# hacker_level

`hacker_level` asks you for your name, and tells you that you're not very
leet. Let's prove them wrong!

## Recon

The downloaded archive comes with both a Linux executable and a C source-code
file. The source file is immediately more interesting, becuase I don't have to
know x86 assembly or machine code, just C.

```c
    char name[64] = "";

    setbuf(stdin, NULL);		// turn off buffered I/O
    setbuf(stdout, NULL);

    printf("What's your name? ");
    fgets(name, sizeof name, stdin);

    calc_level(name);

    usleep(150000);
    printf("Hello, ");
    printf(name);

    usleep(700000);
    if (level == 0xCCC31337) {
```

Ignoring all the `usleep` calls that just troll us, we see that we read up to 64
bytes from stdin, put them in a cleared stack buffer, run them through a
`calc_level1` function, and compare the level against `0xCCC31337`.

```c
static void calc_level(const char *name) {
    for (const char *p = name; *p; p++) {
        level *= 257;
        level ^= *p;
    }
    level %= 0xcafe;
}
```

Further analysis of `calc_level` reveals that it cannot return a level larger
than 0xCAFE, which is less than 0xCCC31337. If you copied this file and edited
it to brute-force a name locally like I did, you can safely delete it :(

Fortunately, the `printf` call in `main` gives us more than enough control.

## Making `hacker_level` run locally

If you can make the given `hacker_level` binary work locally, skip this
section.

On the other hand, if you get a `No such file or directory` error, you're
probably trying to run a 32-bit binary on 64-bit Linux. Following some
[instructions from Stack Overflow][1], you can download what you need.

[1]: http://superuser.com/questions/344533/no-such-file-or-directory-error-in-bash-but-the-file-exists

These instructions worked for me on Ubuntu 15.04; it's pretty fast on the wired
network at #cccamp15 :)

```sh
# enable i386 architecture package downloads
sudo dpkg --add-architecture i386

# get i386 package lists
sudo apt-get update

# get some i386 packages
sudo apt-get install libc-i386 libc-dev-i386
```

## What is a printf exploit?

In C, `printf` takes one or more arguments. The first argument is a "format
string," that describes what the rest of the arguments should be. Some of the
formats are `%p` to output a `sizeof(void*)`-byte integer as pointer-style
(i.e. `0xcafed00d`), `%s` to output a null-terminated string, and `%n` to write
the number of characters `printf`-d so far into the `int*` argument.

That's really confusing!

```c
int chars_sent = 0;
printf("%p %s%n\n", 3202722474, "actually wasps", &chars_sent);
printf("%d\n", chars_sent);
```

This prints out:

```
0xbee5aaaa actually wasps
25
```

Additionally, you can also use different formats to output really long strings
from relatively short input strings.

This program prints out forty-five space characters, followed by the digit `7`:

```c
printf("%45d\n", 7);
```

You can learn more about `printf` with `man 3 printf`.

## Variable-length argument lists in C

It justs pops successive arguments off the stack!

### Non-shitty answer

```c
printf("%p %s%n\n", 3202722474, "actually wasps", &chars_sent);
```

In `gdb`:

```
(gdb) b printf
Breakpoint 1 at 0x8048330
(gdb) r
Starting program: /home/ubuntu/printf_demo

Breakpoint 1, 0xf7e4fa90 in printf () from /lib32/libc.so.6
(gdb) i reg
eax            0xffffd0a8	-12120
ecx            0xffffd0d0	-12080
edx            0xffffd0f4	-12044
ebx            0xf7fba000	-134504448
esp            0xffffd08c	0xffffd08c
ebp            0xffffd0b8	0xffffd0b8
esi            0x0	0
edi            0x8048370	134513520
eip            0xf7e4fa90	0xf7e4fa90 <printf>
eflags         0x292	[ AF SF IF ]
cs             0x23	35
ss             0x2b	43
ds             0x2b	43
es             0x2b	43
fs             0x0	0
gs             0x63	99
(gdb) x/16x $esp
0xffffd08c:	0x080484a6	0x0804856f	0xbee5aaaa	0x08048560
0xffffd09c:	0xffffd0a8	0x00000001	0xffffd164	0x00000000
0xffffd0ac:	0xd99ab800	0xf7fba41c	0xffffd0d0	0x00000000
0xffffd0bc:	0xf7e1e71e	0x00000000	0x08048370	0x00000000
```

That last dump of memory is relevant: doing some gdb detective work, we can
see that it includes:

1. `0x080484a6`: an instruction pointer to where we called printf from
2. `0x0804856f`: a pointer to the format string (the pointer ending with
`856f`),
3. `0xbee5aaaa`: our integer
4. `0xffffd0a8`: a pointer to `chars_sent`

Pretty cool, eh?
