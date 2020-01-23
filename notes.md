# chroot spelunking

This workshop will go over some of the technology at play in so called
"containers" on Linux.

Resource isolation on Linux is achieved via a number of sub-systems which
were added to the kernel over the years. All current "containerization tools"
utilize some or all of these technologies.

Understanding how `chroot` and its various friends work on a mechanical level
will help clarify how Docker and its ilk function.


# Workshop Environment

The workshop environment is a Void Linux system with sufficient tools
installed to isolate a process. Refer to the included `MANIFEST` document
if you build your own environment.


# The Goal

Docker is not magic. Nor are `rkt` or `lxc`. They are simply a set of userspace
tools designed to make light work of a series of *just annoying enough*
steps to warrant spending vast amounts of time automating and abstracting.

The goal is not to poo-poo the aforementioned tools, but rather to appreciate
what they're doing for you behind the scenes. A greater understanding of
some kernel mechanics doesn't hurt either.


# Pay Your Respects

1979 - chroot, unix r7
1994 - bochs
1998 - vmware
2000 - jails, bsd
2002 - namespaces, originally plan9 (80s-90s)
2004 - zones, solaris
2005 - seccomp
2007 - cgroups, google
2008 - lxc, ibm, google, et al
2012 - (approx) seccomp-bpf, google (will drewry)
2013 - docker, dotCloud (solomon hykes)

## chroot

Nearly 40 years old - let that sink in.

It was a feature of V7 (the last true Unix) which is also when the following
tools were released:

* lex
* lint
* make
* bourne shell
* at
* awk
* find
* fortune
* tar
* touch
* uucp netowkring
* environment variables
* 1gb max. file size

This release was a real head-turner and apparently many old timers really
liked it a lot.

## namespaces

Plan 9 from Bell Labs:

* rob pike and ken thompson followed by a bunch of smart folks.
* distributed operating system.
* everything, including networks, is a file.
* a unified network protocol allows machines to share resources.
* processes have a namespaced view of the file-system.
* processes export functionality as paths which can be provided to another process' namespace.
* the windowing system is first-class userland.
* a window (process) creates a namespace which includes required functionality as a file:
    * mouse
    * cons
    * bitblit
    * ...
* the files may be on a remote server.
* as you will discover, linux namespaces are quite rudimentary by comparison.


# What Is Isolation?

Starting with `chroot`, let's define what *resource isolation* means in
terms of a Linux process.


## Protection Rings

The simplest, coarsest, and oldest form of isolation is in play
at the kernel level (yes, I am excluding other hardware technologies
intentionally). Protection rings separate userland from the kernel and were
introduced with Multics. Protection rings can be implemented in hardware or
software (the first version was soft); Linux uses *supervisor mode*.

Supervisor mode is a hardware flag that, when set, allows the running process
access to privileged instructions; modifying registers or some such. This
flag implements two rings and userland processes on Linux use the kernel's
*syscall* interface to utilize it.


## Chroot

Chroot changes the root filesystem that a process can read from or write to
and was originally implemented to aid in operating system builds. It remains
in heavy use for the same reason today.


## Namespaces

The concept of namespacing resources or processes is not new or peculiar to
Unix-based operating systems. In the context of this workshop, namespaces
refer to restricting the view that a process has of various exposed parts
of the host - global resources. Changes to the namespaced global resources
is visible to processes that are members of the namespace, but not others.


# A Shitty Container - 1

Let's SSH to your Linux instance:

`ssh ...`

Now we'll write a trivial program and create a directory for it to use as a
root filesystem.
```
mkdir rootfs

cat <<! >foo.c
#include <stdio.h>
int main(void) {
    printf("hello\n");
    return 0;
}
!
gcc -o rootfs/foo foo.c
```


# A Shitty Container - 2

When executing `chroot`, the first argument we usually use is the directory
that contains the new root filesystem. The second is the name of the program
to execute with the new root.

Let's execute this program with an isolated filesystem:

```
sudo chroot rootfs /foo
```

Foiled! An error!

The error indicates that the command wasn't found, so let's take a look -
humor the error message, if you will.

`ls -l rootfs`

The command is there. This error message is misleading.

Inspect the file to see what kind of binary it is:

`file rootfs/foo`

ELF, dynamically linked. Aha!


## Dynamically Linked Binaries

Without getting into the hairy details, dynamically linked binaries are common
on Linux and the first extrinsic dependency for a program of this nature is the
Linux Loader. The loader locates and loads dependent libraries for the program.


# Back To The Container

Let's find out what libraries are required by the program:

```
ldd rootfs/foo
```

We can see that `libc` and the loader are required to execute the program; copy
those files to the correct location in `rootfs/` and try again:

```
mkdir -p rootfs/{usr,}/lib
cp /usr/lib/libc.so.6 rootfs/usr/lib
cp /lib/ld-linux-x86-64.so.2 rootfs/lib
!sudo
```


# A Look Under The Covers

Let's use `strace` to take a look at the syscalls used by our trivial program
and then `strace` the chroot version to see how it differs.

`strace` is violent - is pauses the target process before every syscall is passed
across the ring and prints the syscall out with some useful context.

While `strace` is handy, it's out-dated, unusable in production, and has
already been replaced.

Brendan Gregg is the dude to check out for the state of the art.


## Trace the Program

```
strace rootfs/foo
```

Not all of the lines are important, but all tell you something about how
a process intereacts with the kernel (and thus, the underlying hardware or
abstraction therof).

Let's quickly step through some to get a feel for what that little C program
gets up to when it is converted into a process.

1. `execve()` executes a binary or shebang script
  * text, bss, data, and stack of caller are replaced (execve doesn't return)
  * the environment is sent along for the ride
  * if the caller is being traced, the new executable will be sent a SIGTRAP
    after execve is successful.

2. `brk()` and `sbrk()` allocate memory by moving the program break
  * the program break defines the end of the program's data segment
  * if brk() fails, it sets an error code of ENOMEM
  * the return data for brk() differs between glibc and the kernel
      * the kernel returns the program break on success
      * glibc returns 0 (zero) on success

3. `access()` does a permissions check.

4. `open()` opens a file and returns a file descriptor.

5. `fstat()` is a member of the `stat()` syscalls and returns information about a file.

6. `mmap()` memory maps a file (second to last arg is the FD).

7. `close()` closes an FD.

8. `read()` reads some number of bytes from an FD.

9. `write()` writes bytes to an FD.

The value on the right of the equals sign is useful. Sometimes.


## Trace the Chroot Version

```
sudo strace chroot rootfs /foo
```

Now we can see that the first `execve()` syscall is for `chroot`.

Everything from now until the `chroot()` syscall is scaffolding for `chroot`
itself.

`chroot()` performs the root filesystem namespacing, calls `chdir()` to
change to the newly provisioned rootdir, and then execs the C program.

From here out, it's functionally the same as `strace rootfs/foo`.

Now you should have a working understanding of chroot:

* A program is executed with a modified view of the root filesystem.


# A Toy Chroot

Let's use Docker to create a rootfs with some useful tools. We'll use this
to greater explore life on the inside.

```
docker run -it --name toy voidlinux/voidlinux /usr/bin/bash
```

Exit the container and export its filesystem:

```
<C-d>  # or exit
docker export toy >toy.tar
```

Unpack the rootfs into a directory:

```
mkdir toyfs
tar xpvf toy.tar -C toyfs
```


# Environment Variables

As we saw during the `strace` section, environment variables from the host are
automatically provided to a process via the `exec()` family of function calls.

```
sudo chroot toyfs /bin/env
```

This shows the environment in the chroot. It is the same as the environment
out of the chroot. Or is it? Nerd points awarded for those that recognize why
it may differ.

The `env` program is used to execute a program with a modified environment.

```
sudo env -i FOO=BAR chroot toyfs /bin/env
```

The `-i` flag wipes the environ that is passed to the command it executes.
KEY=VALUE pairs specify a custom environment. As you can see, the entire
environ for the *chrooted* program is replaced.


# Namespaces

There are 7 namespaces in Linux and they are opt-out. This table is lifted
directly from `man 7 namespaces`:

|Namespace|Isolates|
|:---|:---|
Cgroup|Cgroup root directory
IPC|System V IPC, POSIX message queues
Network|Network devices, stacks, ports, etc.
Mount|Mount points
PID|Process IDs
User|User and group IDs
UTS|Hostname and NIS domain name


## The Namespace API

Namespaces can be accessed in two ways: syscalls or `/proc`. The `/proc`
interface is rooted at `/prod/[pid]/ns/` and contains one entry for each
namespace that supports manipulation via the syscall `setns(2)`.

```bash
ls -la /proc/$$/ns
```

## Namespaces: unshare

These namespaces are controlled via `unshare`.

Let's unshare the network namespace.

To begin, let's see what the network namespace looks like by default:

`chroot toyfs /usr/bin/ip a`

Then, when we unshare the network namespace:

`unshare -n !!`

Any number of namespaces can be unshared at invocation.


## Namespaces: nsenter

`nsenter` executes a program in the namespace(s) of another process(es).

~~~
unshare -n chroot toyfs /usr/bin/bash &
pid=$!
ls -la /proc/$pid/ns
nsenter --net=!$/net chroot toyfs /usr/bin/ip a
fg
<Ctrl+C>
<Ctrl+D>
~~~

1. run a suspended process with no network namespace
2. attach another process to the suspended process' network namespace.


## Combining Things

The namespacing techniques we've seen so far all accept a program as an
argument and thus can be composed in-line.

These programs are not only useful for chroots; any program can be namespaced.

## Mounts

An important part of containerization is mounting.

Bind mounting replicates a mount point somewhere else on a filesystem. As it
transpires, this is the best way to add filesystems to the rootfs of a chroot.

~~~
mkdir foo && echo "world" >foo/hello && mkdir toyfs/foo
mount -o bind foo toyfs/foo
chroot toyfs /usr/bin/bash
cat /foo/hello
Ctrl+d
umount toyfs/foo
~~~

Bind can mount target mount-points as read-only.

### Other mount types

* proc
* sysfs
* devpts


## cgroups

Control groups came from Google.

Add a PID (text) to the `tasks` file in the `cgroup` directory in order to
pin a process to a control group.

A PID can be added to a number of `tasks` files.


## Capabilities

Just read the slide.


## Networking

The venerable `ip` tool (from `iproute2`) can create network namespaces.

A network namespace can have virtual network devices added to it.


## Seccomp

`seccomp` is conjuction with *BPF* provides a firewall for the kernel's
syscalls.

If you want to use `seccomp` yourself, prepare to get your hands dirty.

Docker supports seccomp "out of the box" and by default it blocks ~44 calls.

Linux has between 300 and 350 depending on the kernel version and the
archictecture.
