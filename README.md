# chroot-spelunking

These are the slides, presenter notes, and a training environment for learning
about chroot as it relates to containers.

There are many presentations and blogs about this topic, but this is mine.


## Running the environment

First build the Docker image. This will take some time due to `gcc` - the
presenter can begin while this is installing, however.

First, change directory so you are "in" the same directory as the `Dockerfile`,
then:

`docker build -t voidtoy .`

This command will download a root filesystem and a few dependencies and
build a Docker image that will be used in the workshop.

*NOTE!* On at least one Mac, the above command fails. Try:

`docker build . -t voidtoy`


## Environment

The `Dockerfile` has the details of what the container will look like if
that sort of thing interests you.
