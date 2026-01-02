#!/bin/bash
set -e

source ~/HPL/helpers.sh

mkdir -p ~/HPL
cd ~/HPL
export INSTALL_DIR="$(pwd)/opt"
export CLONE_DIR="$(pwd)/clone"
export BUILD_DIR="$(pwd)/build"

mkdir -p $INSTALL_DIR $CLONE_DIR $BUILD_DIR

export CC="gcc"
export CCFLAGS=" -O3 -march=native -fma -funroll-loops "
export CXX="gcc"
export CXXFLAGS=" -O3 -march=native -fma -funroll-loops "

HPL=<name>
cd "$CLONE_DIR" || return 1
url=https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz
# Download tarball
tarfile=$(basename "$url")
if [[ ! -f "$tarfile" ]]; then
    wget "$url"
else
    echo "Tarball $tarfile already exists, skipping download."
fi

# Extract
clonepath=$CLONE_DIR/$HPL
installpath=$INSTALL_DIR/$HPL
mkdir -p $installpath

if [[ ! -d "$clonepath" ]]; then 
    mkdir -p "$clonepath"
    if [[ "$tarfile" == *.tar.gz || "$tarfile" == *.tgz ]]; then
        tar -xzf "$tarfile" -C "$clonepath" --strip-components=1
    elif [[ "$tarfile" == *.tar.bz2 ]]; then
        tar -xjf "$tarfile" -C "$clonepath" --strip-components=1
    elif [[ "$tarfile" == *.tar.xz ]]; then
        tar -xJf "$tarfile" -C "$clonepath" --strip-components=1
    else
        echo "Unsupported archive format: $tarfile"
    fi
else 
    echo "Folder already exists, assuming already unpacked"
fi

cd ~/HPL
cp -f <path>/Make.Slugalicious $clonepath

add_build <MPdir> <MPname>
add_build <LAdir> <LAname>

cd $clonepath
echo "=== Building $name ==="
# make arch=Slugalicious clean
make arch=Slugalicious -j$(nproc) all
echo "=== Installing $name ==="
mkdir -p $installpath/bin $installpath/lib $installpath/include
cp -f bin/Slugalicious/xhpl $installpath/bin/
cp -f lib/Slugalicious/libhpl.a $installpath/lib/
cp -rf include/* $installpath/include/

echo "-----------------------"
echo "Needed Libraries"
readelf -d $installpath/bin/xhpl | grep NEEDED
echo "BLAS used"
strings $installpath/bin/xhpl | grep -Ei "openblas|blis|mkl"
echo "MPI used"
ldd $installpath/bin/xhpl | grep mpi

#Slurm run
cd ~/HPL/<path>
chmod 777 hpl.slurm
sbatch hpl.slurm
squeue
