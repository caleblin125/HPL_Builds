#!/bin/bash
#SBATCH -p gooey
#SBATCH -J struggle
#SBATCH -e output/AOCL_OpenMPI%j.err
#SBATCH -o output/AOCL_OpenMPI%j.out
#SBATCH -N 2
#SBATCH --tasks-per-node=8
#SBATCH --cpus-per-task=2
#SBATCH --chdir=/home/caleb/HPL_MULTITHREAD

HPL_ROOT=/home/caleb/HPL_MULTITHREAD
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

export BLIS_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PLACES=cores
export OMP_PROC_BIND=FALSE

#export BLIS_IC_NT=$SLURM_CPUS_PER_TASK
#export BLIS_JC_NT=1

export OMPI_MCA_hwloc_base_binding_policy=none
export OMPI_MCA_rmaps_base_mapping_policy=slot

export OMPI_MCA_btl_tcp_if_include=enp1s0 
export OMPI_MCA_btl=self,vader,tcp

pkill -f mpirun
pkill -f orted

mkdir -p output/dats
cp -f HPL.dat opt/$HPL/bin/
cp -f HPL.dat output/dats/HPL-$SLURM_JOB_ID.dat
echo $(which mpirun)
chmod 777 opt/$HPL/bin/xhpl

lscpu | egrep "NUMA|Core|Socket"
numactl --hardware
ldd opt/$HPL/bin/xhpl | grep blas

mpirun --report-bindings --bind-to core --map-by numa:pe=$SLURM_CPUS_PER_TASK -np $SLURM_NTASKS opt/$HPL/bin/xhpl | tee hpl.out
HPL_STATUS=${PIPESTATUS[0]}
#cat hpl.out

#opt/$HPL/bin/xhpl | tee hpl.out

echo "FINISHED RUN: HPL_AOCL_OpenMPI"

if [[ $HPL_STATUS -eq 0 ]]; then
    echo "HPL completed successfully. Creating tarball..."
    rm -f $HPL_ROOT/../CalebLin.tar
    tar -cvf $HPL_ROOT/../CalebLin.tar HPL.dat hpl.cmd hpl.out hplscript.sh
else
    echo "HPL failed (exit code $HPL_STATUS). Skipping tarball creation."
fi

if [[ -f parseout.py ]]; then
    echo "parsing output"
    python3 parseout.py
fi

#ssh compute-3-of-4 "top -bn1 | grep 'Cpu(s)' && free | awk '/Mem:/ {printf \"Mem: %.1f%% used\n\", \$3/\$2*100}'"

#ssh compute-3-of-4 '
#for p in $(pgrep xhpl); do
#  echo "PID $p threads: $(ls /proc/$p/task | wc -l)";
#  taskset -cp $p;
#done
#'
