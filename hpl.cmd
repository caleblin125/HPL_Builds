#!/bin/bash
#SBATCH -p gooey
#SBATCH -J HPL_AOCL_OpenMPI_run
#SBATCH -e output/AOCL_OpenMPI%j.err
#SBATCH -o output/AOCL_OpenMPI%j.out
#SBATCH -N 2
#SBATCH --ntasks=32
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --chdir=/home/caleb/HPL_FINAL

HPL_ROOT=/home/caleb/HPL_FINAL
HPL=HPL_AOCL_OpenMPI

add_build() {
    local prefix="$1"
    local name="$2"

    if [[ -z "$prefix" ]]; then
        echo "Usage: add_build <prefix> [<name>]"
        return 1
    fi

    # Normalize path
    prefix="$(cd "$prefix" 2>/dev/null && pwd)"
    if [[ -z "$prefix" ]]; then
        echo "Directory does not exist: $1"
        return 1
    fi

    # If name not provided, use basename
    [[ -z "$name" ]] && name="$(basename "$prefix")"

    # Add bin
    [[ -d "$prefix/bin" ]] && export PATH="$prefix/bin:$PATH"

    # Add lib or lib64
    if [[ -d "$prefix/lib" ]]; then
        export LD_LIBRARY_PATH="$prefix/lib:${LD_LIBRARY_PATH:-}"
        export LIBRARY_PATH="$prefix/lib:${LIBRARY_PATH:-}"
        #Export Variables
        declare -x "${name^^}_LIBRARY=$prefix/lib"
    elif [[ -d "$prefix/lib64" ]]; then
        export LD_LIBRARY_PATH="$prefix/lib64:${LD_LIBRARY_PATH:-}"
        export LIBRARY_PATH="$prefix/lib64:${LIBRARY_PATH:-}"
        #Export Variables
        declare -x "${name^^}_LIBRARY=$prefix/lib"
    fi

    # Add include
    [[ -d "$prefix/include" ]] && {
        export CPATH="$prefix/include:${CPATH:-}"
        export C_INCLUDE_PATH="$prefix/include:${C_INCLUDE_PATH:-}"
        export CPLUS_INCLUDE_PATH="$prefix/include:${CPLUS_INCLUDE_PATH:-}"
        # Export variables
        declare -x "${name^^}_INCLUDE_DIR=$prefix/include"
    }

    # Add CMake prefix path
    export CMAKE_PREFIX_PATH="$prefix:${CMAKE_PREFIX_PATH:-}"

    echo "Added build prefix: $prefix"
}

add_build $HPL_ROOT/opt/AOCL AOCL
add_build $HPL_ROOT/opt/OpenMPI OpenMPI

export BLIS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

export OMPI_MCA_btl_tcp_if_include=enp1s0 
export OMPI_MCA_btl=self,vader,tcp

pkill -f mpirun
pkill -f orted

mkdir -p output/dats
cp -f HPL.dat opt/$HPL/bin/
cp -f HPL.dat output/dats/HPL-$SLURM_JOB_ID.dat

if [[ -f "optimize/clone/ompi-collectives-tuning/output/decision.file" ]]; then
    echo "found mpi tuning collectives"
    cp optimize/clone/ompi-collectives-tuning/output/decision.file .
else
    echo "did not find mpi tuning collectives"
fi

lscpu | egrep "NUMA|Core|Socket"
numactl --hardware
ldd opt/$HPL/bin/xhpl | grep blas

echo $(which mpirun)
#echo "With tuned dynamic rules"
#mpirun -np 32 --bind-to core --map-by numa --mca coll_tuned_dynamic_rules_filename decision.file opt/$HPL/bin/xhpl
#cat hpl.out
echo "Without tuned dynamic rules"
mpirun -np 32 --bind-to core --map-by numa opt/$HPL/bin/xhpl
cat hpl.out
echo "FINISHED RUN: HPL_AOCL_OpenMPI"

rm -f $HPL_ROOT/../CalebLin.tar
tar -cvf $HPL_ROOT/../CalebLin.tar HPL.dat hpl.cmd hpl.out hplscript.sh decision.file

if [[ -f parseout.py ]]; then
    echo "parsing output"
    python3 parseout.py
fi