%title: chroot spelunking
%author: mel boyce
%date: 2017-05-13

chroot spelunking
=================

We're going to dive into a variety of `chroot` scenarios

<br>
in order to better understand Docker et al.

<br>
ᕕ( ᐛ )ᕗ

<br>
Along the way, I'll include some Linux/Unix fundamentals

<br>
to strengthen your nerd muscle.

<br>
╰(°ㅂ°)╯

***

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
2012 - ~, seccomp-bpf, google (will drewry)
2013 - docker, dotCloud (solomon hykes)

***

# A Shitty Container - pt.1

`docker run -it --security-opt seccomp:unconfined --name peppy voidtoy`
`cd`

<br>
~~~
mkdir rootfs

cat <<! >foo.c
#include <stdio.h>
int main(void) {
    printf("hello\n");
    return 0;
}
!
~~~

<br>
`gcc -o rootfs/foo foo.c`

***

# A Shitty Container - pt.2

`chroot rootfs /foo`

<br>
Foiled! An error!

<br>
`ls -l rootfs/foo`

<br>
( •᷄ὤ•᷅)？  なに?

<br>
`file \!$`

<br>
`ldd \!$`

<br>
╭( ･ㅂ･)و  よし!

<br>
`mkdir -p rootfs/{usr/lib,lib}`
`cp /usr/lib/libc.so.6 rootfs/usr/lib`
`cp /lib/ld-linux-x86-64.so.2 rootfs/lib`
`\!chroot`

***

# Bash History Expansion

A few examples to whet your appetite.

*\!word*  | expands to the most recent command that starts with *word*
*\!\!*     | evaluates to the previous command line in full
*\!\**     | expands to all arguments to the previous command
*\!$*     | evaluates to the last argument of the previous command
*Ctrl+A* | move cursor to beginning of line
*Ctrl+E* | move cursor to end of line
*Ctrl+U* | kill the current line

<br>
Find a *readline* cheat-sheet and impress your peers!

***

# Let's Break It Down

<br>
## trace our binary

`strace rootfs/foo`

<br>
(´･＿･‘)

<br>
(☆^ー^☆)

<br>
## trace the chroot

`strace \!chroot`

<br>
(•’╻’• ۶)۶

***

# A Toy Chroot

First, we need a rootfs with some tools.

<br>
Exit back to your host: `Ctrl+D`

`docker run -it --name toy voidlinux/voidlinux /usr/bin/bash`

<br>
Exit the container; export the filesystem.

`docker export toy >toy.tar`

<br>
`tar xpvf \!$ -C toyfs`

<br>
`mkdir \!$`
`\!-2` or `\!tar`

<br>
`docker run -it --security-opt seccomp:unconfined --cap-add=SYS_ADMIN --name peppytoy -v $PWD/toyfs:/root/toyfs voidtoy`
`cd`

***

# Environment Variables

The *exec()* functions pass the environment.

`chroot toyfs /bin/env`

<br>
*env* executes a program with a modified environment.

`env -i FOO=BAR chroot toyfs /bin/env`

<br>
We can use *env* to execute *chroot* with a modified environment.

***

# Namespaces

There are 7 namespaces in Linux:

* *i* IPC
* *m* mount
* *n* network
* *p* PID
* *u* UTS
* *U* user
* *C* cgroup

***

# Namespaces: unshare

*unshare* executes a program with some namespaces
"unshared" from the parent.

<br>
Let's look at a process' network namespace.
And then *unshare* the network namespace.

<br>
~~~
chroot toyfs /usr/bin/ip a
unshare -n !!
~~~

<br>
Any combination of the 7 namespaces can be unshared.

<br>
We can use *unshare* to remove namespaces from *chroot*.

***

# Namespaces: nsenter

*nsenter* executes a program in the namespace(s) of
another process.

<br>
~~~
unshare -n chroot toyfs /usr/bin/bash &
pid=$!
ls -la /proc/$pid/ns
nsenter --net=!$/net chroot toyfs /usr/bin/ip a
fg
<Ctrl+C>
<Ctrl+D>
~~~

<br>
We can use *nsenter* to make *chroot* use other namespaces.

***

# Combining Things

*chroot*, *unshare*, *nsenter*, and *env* all execute
a program with a modified state.

<br>
This means you can do things like:

`env -i FOO=BAR unshare -n chroot toyfs /usr/bin/bash`

<br>
Any Linux process can be started with these programs.

Or a combination of them. How exciting!

***

# Mounts

Various mount types can be added to the chroot's filesystem.

<br>
Use `bind` mounts for data:

~~~
mkdir foo && echo "world" >foo/hello && mkdir toyfs/foo
mount -o bind foo toyfs/foo
chroot toyfs /usr/bin/bash
cat /foo/hello
<Ctrl+D>
umount toyfs/foo
~~~
Bind supports *read-only* mounts.

<br>
Other interesting mount types:

* proc
* sysfs
* devpts

***

# Mounts: namespace?

The mount namespace allows a process to be started
with a copy of the parent's mount tree.

This means that a process can create mount-points
without affecting the parent mount-tree.

<br>
There are some advanced tricks.

<br>
I won't be covering any ;)

***

# cgroups

Control groups provide the following for processes:

* Resource limits
* Prioritization
* Accounting
* Control

<br>
*cgroups* are managed via a filesystem:

`ls -la /sys/fs/cgroup/memory`

<br>
For the lazy, you can use *libcgroup-utils*.

***

# Capabilities

Originally used to try and break the reliance on *setuid*.

<br>
Quite complicated.

<br>
Still some flux in the space.

<br>
`man capabilities`

(⌣_⌣”)

***

# Networking

The *ip* tool provides a means of creating network namespaces.

`ip netns help`

<br>
*netns* could be a whole workshop on its own.

ヘ（´ｏ｀）ヘ

***

# seccomp

*seccomp* - secure computing mode

<br>
Limits access to syscalls.

<br>
*seccomp-bpf* - Berkley packet filter

<br>
Uses *bpf* to filter syscalls.

<br>

It's a firewall for the Kernel.

(⌬̀⌄⌬́)

<br>
Docker already supports *seccomp*
And it's enabled by default.

***

# Fin



NAMESPACE
ALL
THE
THINGS
