# chroot-spelunking

These are the slides, presenter notes, and a training environment for learning
about chroot as it relates to containers.

There are many presentations and blogs about this topic, but this is mine.


## Running the environment

First build the Docker image. This will take some time due to `gcc` - the
presenter can begin while this is installing, however.

`docker build -t voidtoy .`


## Environment

The `Dockerfile` has the details.


## Before starting

Once the installation has completed, execute the following:

`cd`

This will change the working directory to `/root`, the `root` user's home
directory.
