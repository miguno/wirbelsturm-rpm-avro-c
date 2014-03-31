#!/usr/bin/env bash
#
# This script packages an avro-c release tarball as RHEL6/CentOS6 RPM using fpm.

### CONFIGURATION BEGINS ###

INSTALL_ROOT_DIR=/usr
MAINTAINER="<michael@michael-noll.com>"

### CONFIGURATION ENDS ###

function print_usage() {
  myself=`basename $0`
  echo "Usage: $myself <avroc-tarball-download-url>"
  echo
  echo "Examples:"
  echo "  \$ $myself http://www.eu.apache.org/dist/avro/avro-1.7.6/c/avro-c-1.7.6.tar.gz"
}

if [ $# -ne 1 ]; then
  print_usage
  exit 1
fi

DOWNLOAD_URL="$1"
TARBALL=`basename $DOWNLOAD_URL`
VERSION=`echo $TARBALL | sed -r 's/^avro-c-([0-9\.]+)\.tar\.gz$/\1/'`

echo "Creating an RPM for avro-c release version $VERSION..."

# Prepare environment
OLD_PWD=`pwd`
BUILD_DIR=`mktemp -d /tmp/avro-c-build.XXXXXXXXXX`
cd $BUILD_DIR

cleanup_and_exit() {
  local exitCode=$1
  rm -rf $BUILD_DIR
  cd $OLD_PWD
  exit $exitCode
}

# Download and extract the requested release tarball
wget $DOWNLOAD_URL || cleanup_and_exit $?
tar -xzf $TARBALL || cleanup_and_exit $?

# Build the RPM
DIR=${TARBALL%.tar.gz}
cd $DIR
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$BUILD_DIR/installdir -DCMAKE_BUILD_TYPE=RelWithDebInfo -DTHREADSAFE=true || cleanup_and_exit $?
# Fix known bug AVRO-1222 (https://issues.apache.org/jira/browse/AVRO-1222)
mv -i avro-c.pc src || cleanup_and_exit $?
make || cleanup_and_exit $?
make test || cleanup_and_exit $?
make install || cleanup_and_exit $?
# Package the RPM
cd $BUILD_DIR/installdir
fpm -s dir -t rpm -a all \
    -n avro-c \
    -v $VERSION \
    --maintainer "$MAINTAINER" \
    --vendor "Apache Avro Project" \
    --url http://avro.apache.org \
    --description "A data serialization system" \
    -p $OLD_PWD/avro-c-VERSION.el6.ARCH.rpm \
    -a "x86_64" \
    --prefix $INSTALL_ROOT_DIR \
    * || cleanup_and_exit $?

echo "You can verify the proper creation of the RPM file with:"
echo "  \$ rpm -qpi avro-c-*.rpm    # show package info"
echo "  \$ rpm -qpR avro-c-*.rpm    # show package dependencies"
echo "  \$ rpm -qpl avro-c-*.rpm    # show contents of package"

# Clean up
cleanup_and_exit 0
