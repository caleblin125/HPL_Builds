source helpers.sh

mkdir -p ~/HPL
cd ~/HPL
export INSTALL_DIR="$(pwd)/opt"
export CLONE_DIR="$(pwd)/clone"
export BUILD_DIR="$(pwd)/build"

mkdir -p $INSTALL_DIR $CLONE_DIR $BUILD_DIR

export CXX="g++"
export CXXFLAGS=" -O3 -march=native "

#openblas
# basic_cmake_github https://github.com/OpenMathLib/OpenBLAS.git --cmake-args \
#     -DTARGET=ZEN

# aocl
basic_cmake_github https://github.com/amd/blis.git -n AOCL -configure ON --cmake-args \
    --enable-blas zen3

# mpich
basic_cmake_tarball https://www.mpich.org/static/downloads/4.3.2/mpich-4.3.2.tar.gz -n MPICH -configure ON

#openmpi
basic_cmake_tarball https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.9.tar.gz -n OpenMPI -configure ON --cmake-args \
    --with-slurm

#HPC-X
# cd $CLONE_DIR
# HPCX_NAME="hpcx-v2.18.1-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64"
# HPCX_URL="https://content.mellanox.com/hpc/hpc-x/v2.18.1/hpcx-v2.18.1-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64.tbz"
# if [[ ! -f "$HPCX_NAME.tbz" ]]; then 
#     wget $HPCX_URL
# fi
# if [[ ! -d "$INSTALL_DIR/HPCX/$HPCX_NAME"]]; then
#     mkdir -p $INSTALL_DIR/HPCX
#     tar -xjf $HPCX_NAME -C $INSTALL_DIR/HPCX
# fi
# cd $INSTALL_DIR/HPCX/$HPCX_NAME
# source hpcx-init.sh
# cd ~/HPL

#Using modules
# module load intel-oneapi/mpi/latest
# module load nvhpc/25.7/nvhpc-hpcx/25.7

# module load intel-oneapi/compiler-rt intel-oneapi/mpi/latest intel-oneapi/tbb intel-oneapi/mkl/latest
#HPL 

remove_build $INSTALL_DIR/OpenMPI openmpi
remove_build $INSTALL_DIR/AOCL aocl

add_build $INSTALL_DIR/OpenMPI openmpi
add_build $INSTALL_DIR/AOCL aocl

HPL=HPL-AOCL
basic_cmake_tarball "https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz" -n $HPL -configure ON

echo "Needed Libraries"
readelf -d $INSTALL_DIR/$HPL/bin/xhpl | grep NEEDED
echo "BLAS used"
strings $INSTALL_DIR/$HPL/bin/xhpl | grep -Ei "openblas|blis|mkl"
echo "OPENMPI used"
ldd $INSTALL_DIR/$HPL/bin/xhpl | grep mpi

#Slurm run
cd ~/HPL
chmod 777 hpl.slurm
sbatch hpl.slurm
