Build scripts for Total Compute stack
=====================================

This README is simply a quick-start guide on the build scripts themselves. For more
information on how to obtain and run the Total Compute stack, please refer to
the user guide.

Setup
-----

To patch the components and install the toolchains and build tools, run:

For Buildroot:
```sh
export PLATFORM=tc2
export FILESYSTEM=buildroot
./setup.sh
```

For Android:
```sh
export PLATFORM=tc2
export FILESYSTEM=android-swr
./setup.sh
```

For Android with AVB (Android Verified Boot):
```sh
export PLATFORM=tc2
export FILESYSTEM=android-swr
export AVB=true
./setup.sh
```

Build the stack
---------------

To build the whole stack:
```sh
./build-all.sh build
```

The platform and filesystem should already have been defined, but if not they
can be defined on the command line using:

```sh
./build-all.sh -p $PLATFORM -f $FILESYSTEM -a $AVB build
```

To build each component separately, run the corresponding script with the exact
same options.

Each script supports build, clean, patch and deploy commands.
build-all.sh also support the `all` command, for a clean complete build +
deploy.

Build files will be in output/tmp_build/$COMPONENT
The deployed binaries are then copied to output/deploy/$PLATFORM


Build Components and its dependencies
-------------------------------------

A new dependency to a component can be added in the form of $component=$dependency in dependencies.txt file

To build a component and rebuild those components that depend on it
```sh
./$filename build with_reqs
```
