#!/usr/bin/env bash

set -e # Abort on error.

export PING_SLEEP=30s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$WORKDIR/build.out

touch $BUILD_OUTPUT

dump_output() {
   echo Tailing the last 500 lines of output:
   tail -500 $BUILD_OUTPUT
}
error_handler() {
  echo ERROR: An error was encountered with the build.
  dump_output
  exit 1
}

# If an error occurs, run our error handler to output a tail of the build.
trap 'error_handler' ERR

# Set up a repeating loop to send some output to Travis.
bash -c "while true; do echo \$(date) - building ...; sleep $PING_SLEEP; done" &
PING_LOOP_PID=$!

if [[ $(uname) == Darwin ]]; then
  export LIBRARY_SEARCH_VAR=DYLD_FALLBACK_LIBRARY_PATH
elif [[ $(uname) == Linux ]]; then
  export LIBRARY_SEARCH_VAR=LD_LIBRARY_PATH
fi

export PYTHON="$PYTHON"
export PYTHON_LDFLAGS="$PREFIX/lib"
export LDFLAGS="$LDFLAGS -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
export CFLAGS="$CFLAGS -fPIC -I$PREFIX/include"

src_dir="$(pwd)"
mkdir ../build
cd ../build
cmake $src_dir \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DENABLE_FORTRAN=0 \
  -DENABLE_NETCDF=1 \
  -DENABLE_METVIEW=1

make -j $CPU_COUNT >> $BUILD_OUTPUT 2>&1
eval ${LIBRARY_SEARCH_VAR}=$PREFIX/lib

if [[ $(uname) == Linux ]]; then
    echo "libGL:" >> $BUILD_OUTPUT 2>&1
    find $PREFIX -name libGL.so.1 >> $BUILD_OUTPUT 2>&1
    echo "PATH:" >> $BUILD_OUTPUT 2>&1
    echo $PATH >> $BUILD_OUTPUT 2>&1
    echo "LD_LIBRARY_PATH:" >> $BUILD_OUTPUT 2>&1
    echo $LD_LIBRARY_PATH >> $BUILD_OUTPUT 2>&1
    # Tell Linux where to find libGL.so.1 and other libs needed for Qt
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BUILD_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/
fi

ctest --output-on-failure -j $CPU_COUNT >> $BUILD_OUTPUT 2>&1
make install >> $BUILD_OUTPUT 2>&1

# The build finished without returning an error so dump a tail of the output.
dump_output

# Nicely terminate the ping output loop.
kill $PING_LOOP_PID
