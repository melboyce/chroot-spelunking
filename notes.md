# chroot spelunking

---
ACHTUNG!
There are sections of command-line usage that rely on history in order to
explain some useful shell conveniences that some folk dn't know about.
Don't muck around unless you aren't interested in following along with
those sections.
---

* Docker, rkt, lxc, et al are built on top of chroot and some other kernel features.
* Understanding them is a good idea.
* Chroots are not new and begat some improved implementations.
* Over time, Linux has absorbed some functionality which allow for isolation.
* Chroots and the associated isolation mechanisms which enable
  "containerization" are facilitated by a number of these kernel features.

## Introduction

*What will you get out of this?*

### Linux/Unix Fundamentals

Efficient use of the shell and a better understanding of a Linux environment
should come in handy.

### Debugging Skills

Improving your knowledge of the underlying mechanics of containers will
increase your ability to diagnose problems.

### Tuning Skills

Tuning is not limited to performance; consider security and isolation tuning.


## Pay Your Respects

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

### chroot

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

### namespaces

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


## A Shitty Container

Let's spin up a Docker container to play within:

`docker run -it --security-opt seccomp:unconfined --name peppy voidtoy`
`cd`

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

1. make the rootfs
2. write a small c program to test with
3. explain heredocs
4. compile the program

### heredocs (sidebar)
A heredoc starts with the following token: `<<WORD`.
Everything from that point on is escaped fully until `WORD` is entered on
its own line.

The `cat` command recieves the content of the heredoc on `stdin`,
echoes it to `stdout` which has been redirected to a file: `foo.c`.

There was a time when editors were unavailable or not required.


## Back to The Shitty Container

Foiled! An error!

The error indicates that the command wasn't found, so let's take a look -
humor the error message, if you will.

`ls -l rootfs`

The command is there. This error message is misleading.

Inspect the file to see what kind of binary it is:

`file rootfs/foo`

ELF, dynamically linked. Aha!

Get the linked SOs for the program:
`ldd rootfs/foo`

When the C program was compiled, it needed to be linked to libc and the
program interpreter.  As the chroot doesn't have those files (it only has
the executable in the rootdir), execution fails.

Let's copy them into the rootfs and try again.
Explain the brackets. ;)

```
mkdir -p rootfs/{usr/lib,lib}
cp /usr/lib/libc.so.6 rootfs/usr/lib
cp /lib/ld-linux-x86-64.so.2 rootfs/lib
!chroot
```

### chroot command

The first argument is a directory and the second is a process - the process
which will be "chrooted". When the process starts, its view of the filesystem
will be recuded to the contents of the directory specified. This is foretold
by the program argument itself: `/foo`.

This is the foundation of a "Linux container".


## Bash history expansion (sidebar)

`!word` executes the most recent program which starts with *word*.

`!!` will be replaced in-place by the entirety of the previous command.

`!*` evaluates to all arguments of the previous command

`!$` evaluates to the last argument of the previous command.

`Ctrl+A` and `Ctrl+E` move the cursor to the beginning and end of the current
line repsectively.

`Ctrl+U` *kills* the current line.


## Let's Break It Down

### basic tracing with strace

`strace` is violent - is pauses the target process before every syscall is passed
across the ring and prints the syscall out with some useful context.

While `strace` is handy, it's out-dated, unusable in production, and has
already been replaced. AFAIK the transition is happening at the moment.

Brendan Gregg is the dude to check out for the state of the art.

### strace rootfs/foo

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

### sudo strace chroot rootfs /foo

Now we can see that the first `execve()` syscall is for `chroot`.

Everything from now until the `chroot()` syscall is scaffolding for `chroot`
itself.

`chroot()` performs the root filesystem namespacing, calls `chdir()` to
change to the newly provisioned rootdir, and then execs the C program.

From here out, it's functionally the same as `strace rootfs/foo`.

Now you should have a working understanding of chroot:

* A program is executed with a modified view of the root filesystem.


## A Toy Chroot

Let's use Docker to create a rootfs with some useful tools.

`docker run -it voidlinux/voidlinux --name toy /usr/bin/bash`

Exit the container and export its filesystem:

`docker export toy >toy.tar`

Windows users may need to use the `--output` flag.

Unpack the rootfs into a directory:

`tar xpvf toy.tar -C toyfs/`

As the directory doesn't exist, `tar` will error; create the directory:

`mkdir !$`

Execute the tar command again:

`!tar` or `!-2`

Run a new environment with the rootfs mapped in:

`docker run -it --security-opt seccomp:unconfined --cap-add=SYS_ADMIN --name peppytoy -v $PWD/toyfs:/root/toyfs voidtoy`


## Environment Variables

As we saw during the `strace` section, environment variables from the host are
automatically provided to a process via the `exec()` family of function calls.

`chroot toyfs /bin/env`

This shows the environment in the chroot. It is the same as the environment
out of the chroot.

The `env` program is used to execute a program with a modified environment.

`env -i FOO=BAR chroot toyfs /bin/env`

The `-i` flag wipes the environ that is passed to the next command.
KEY=VALUE pairs specify a custom environment.


## Namespaces

There are 7 namespaces in Linux and they are opt-out.

* IPC (i)
* mount (m)
* network (n)
* PID (p)
* UTS (u)
* user (U)
* cgroup (c)


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
