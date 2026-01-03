#!/bin/bash
set -e

export SCRIPT_ROOT=$(pwd)
export INSTALL_DIR="$(pwd)/opt"
export CLONE_DIR="$(pwd)/clone"
#export BUILD_DIR="$(pwd)/build"

mkdir -p $INSTALL_DIR $CLONE_DIR #$BUILD_DIR

export COMMON_FLAGS="-O3 -march=native -mfma -funroll-loops -fPIC"
export CC=gcc
export CFLAGS="$COMMON_FLAGS"
export CXX=g++
export CXXFLAGS="$COMMON_FLAGS"

export MPI_INSTALL_PATH=$HOME/HPL_FINAL/opt/OpenMPI

cd $CLONE_DIR
wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-5.6.2.tar.gz
tar -xvf osu-micro-benchmarks-5.6.2.tar.gz
cd osu-micro-benchmarks-5.6.2
./configure --prefix=$INSTALL_DIR/osu-micro-benchmarks CC=$MPI_INSTALL_PATH/bin/mpicc CXX=$MPI_INSTALL_PATH/bin/mpicxx
make
make install

cd $CLONE_DIR
git clone https://github.com/intel/mpi-benchmarks.git
cd mpi-benchmarks
make IMB-MPI1 CC=$MPI_INSTALL_PATH/bin/mpicc CXX=$MPI_INSTALL_PATH/bin/mpicxx

cd $CLONE_DIR
git clone https://github.com/open-mpi/ompi-collectives-tuning.git
cd ompi-collectives-tuning
sed -i 's/\bpython\b/python3/g' run_and_analyze.sh

cp $SCRIPT_ROOT/config .
export SHELL=/bin/bash
export SLURM_SHELL=/bin/bash

#Add this fix if the bash scripts are using shell not bash
#for collective in ${collectives// / } ; do
#    sed -i '1c\#!/usr/bin/env bash' $work_dir/output/$collective/${collective}_coltune.sh
#done
bash ./run_and_analyze.sh --config-file=config --scheduler=slurm