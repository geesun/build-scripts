Build-scripts - readme.

1/ The Theory.
~~~~~~~~~~~~~~

Building software should be repeatable and straightforward.
Engineers building the same code in different ways will yield different results, making the development process less deterministic.

These simple build scripts aim to remove the randomness from development and provide a simple framework that can be used by the developer on the desktop and by and automated build and test system.

ARM should be moving to single binaries built from common source wherever possible, these build scripts take the concept further enabling a single build to create binaries for a number (if not all) of similar platforms in one go. The scripts will also provide a mechanism for building a single platform where they need to be delivered in isolation.

Any change which breaks the ability to build multiple platforms is bad, so will be rejected at code review!

The build is controlled by a variant file (see build-scripts/variants), the variant specifies which components need to be build and provide configuration parameters for each component. Variants either describe a single platform (e.g. Juno) or all platforms for a segment (e.g. juno-busybox, which includes Juno). There arethen derived variants for the particular rootfs you want (OE, Android, Busybox).

The scripts also provide for a build-all that will build all components, but also provide for building invidual components in isolation.

The build scripts provide the following functions:
- clean - clean out the build objects
- build - perform a build
- package - package up the built binaries
- all - do a clean, build and package in one go!

2/ Structure
~~~~~~~~~~~~

There are 2 special files - framework.sh and build-all.sh

framework.sh - this file contains helper environment variable and is responsible for makeing the calls in the individual build scripts, it also provides error handling so that each build script doens't need to.

build-all.sh - this scripts is resonsible for checking the arguments pased to the build, loading framework.sh and then executing the individual build scripts.

There are then a series of individual build scripts for each component, each script contains 3 functions :
- do_build() - the build stage
- do_clean() - the clean stage
- do_package() - the package stage.
Each function must be protected with a "component_BUILD_ENABLED" variable to enable the variant to control if the build for a component is to be executed by that variant.

Each script must include a description of the variables it uses, but also must
 include the following lines at the botton to enable it to work with the build framework:
	DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	source $DIR/framework.sh $1 $2

build-target-bins.sh is a special script that must be run last, it is responsible for collecting together the build output and putting it in platform specific directories ready for testing or release.

3/ running the build
~~~~~~~~~~~~~~~~~~~~

You can either build everything or an individual component, you can call the build script from anywhere withing workspace (i.e. from the root or further in).

<path to build-scripts>/build-all.sh <variant> {cmd}
<path to build-scripts>/build-linux.sh <variant> {cmd}

where:
<variant> is any of the filename in build-scripts/variants
<cmd> is one of build, clean, package, all - if you clean cmd blank the script will call 'build'.

Examples:

./build-scripts/build-all.sh juno-busybox
./build-scripts/build-all.sh juno-busybox clean
./build-scripts/build-all.sh juno-busybox package
./build-scripts/build-all.sh juno-busybox all

4/ Variants
~~~~~~~~~~~

Variant files provide configuration parameters for all the platforms and components supported by that variant.

They consist of a series of variables that configure the individual build scripts. Variables required for a particular component are defined at the top of each build script.

Variants also declare the compilers and tools required for each build step so that the build scripts can be used by multiple types of build (32 and 64bit for example).

5/ Results of the build
~~~~~~~~~~~~~~~~~~~~~~~

Built binaries will be stored in ./output in subfolders per platform (and not per variant).
