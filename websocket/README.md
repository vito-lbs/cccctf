# Exploiting websockets (web 100)

## Recon

It's a form that uses JavaScript to submit a query to a websocket connection.
If your prefix matches entries in the haystack, it returns the first two
matches, which are their address, and value.

`7300b939,CAMP15*silverneedle` is a silver needle found by entering "s".. The
goal is to find the golden needle. `7300b939` is the address, and
`CAMP15*silverneedle` is the value.

Immediately, we can see that `7300b939` is hex, and the `73` is the hex
representation of the ASCII/UTF-8 "s". What we probably need to do is find
prefixes that return needles, and enlongate those prefixes until we eventually
get a golden needle.

Because I like my comfort zone, I decided to solve this with nice linear Ruby
code and not the callback hell-world of in-browser JavaScript.

### A quick vent

Ruby has a shitload of unmaintained fully-integrated websocket libraries, and
none of the ones I found let you set an `Origin` header on the HTTP request that
gets upgraded to a websockets connection.

So I wrote a websocket library that will never be maintained! #yolo

## How Websockets work

The client sends a regular HTTP request to the server, and includes some request
headers that basically say "make this a websocket connection."

The server replies with its half of the handshake, and from then on, the
connection used for that request-response cycle shuttles websocket frames back
and forth.

A websocket frame is, of course, just bytes: a type header, a length header, and
length bytes of messages. `\x81\x05\x48\x65\x6c\x6c\x6f` is a text frame that
contains the string `Hello`.

## How the service works from a client's perspective

Send a frame containing text, receive either a frame containing the string
`not found`, or one or more frames containing found needles.

### The part i fucked up

I didn't write my receive code to expect more than one needle for a given
prefix.

![Oops!](http://media.giphy.com/media/12dC9ZtdU9mk4o/giphy.gif)

## Finding promising subhaystacks

It looks like our addresses are all four bytes, and we can send a minimum of
a single byte. We loop through all the first bytes and remember the ones that
had results. We have <= 256 subhaystacks that are promising.

Next, we loop through all the prefixes for each subhaystack, and remember the
promising ones. We have <= (256 * 256 = 65536) subhaystacks now.

On the third pass (sorting through approx. 50k subhaystacks), my code that
looked for needles that didn't match `silver` produced a hit!
