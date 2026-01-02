#!/bin/bash
#SBATCH -p slimey
#SBATCH -J struggle
#SBATCH -e output/AOCL_OpenMPI%j.err
#SBATCH -o output/AOCL_OpenMPI%j.out
#SBATCH --ntasks=4
#SBATCH -N 2
#SBATCH --tasks-per-node=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=0
#SBATCH --hint=compute_bound
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
#export GOMP_CPU_AFFINITY="0 1 2 3 4 5 6 7"
#export BLIS_IC_NT=$SLURM_CPUS_PER_TASK
#export BLIS_JC_NT=1

export OMPI_MCA_btl_tcp_if_include=enp1s0 
export OMPI_MCA_btl=self,vader,tcp

pkill -f mpirun
pkill -f orted

mkdir -p output/dats
cp -f HPL.dat opt/$HPL/bin/
cp -f HPL.dat output/dats/HPL-$SLURM_JOB_ID.dat
echo $(which mpirun)
chmod 777 opt/$HPL/bin/xhpl

#mpirun --display-map -np 1 hostname

#srun --mpi=pmix \
     --ntasks=4 \
     --cpus-per-task=8 \
     --cpu-bind=cores \
     opt/$HPL/bin/xhpl | tee hpl.out

mpirun -np 4 \
    --report-bindings \
    --bind-to core \
    --map-by ppr:1:l3cache \
    -x OMP_NUM_THREADS=$OMP_NUM_THREADS \
    -x OMP_PROC_BIND=TRUE \
    -x OMP_PLACES=$OMP_PLACES \
    -x BLIS_IC_NT=$BLIS_IC_NT \
    -x BLIS_JC_NT=$BLIS_JC_NT \
    -x BLIS_NUM_THREADS=$BLIS_NUM_THREADS \
    opt/$HPL/bin/xhpl | tee hpl.out

#mpirun --report-bindings --map-by socket:PE=8 --bind-to core -np $SLURM_NTASKS opt/$HPL/bin/xhpl | tee hpl.out

echo "FINISHED RUN: HPL_AOCL_OpenMPI"

HPL_STATUS=${PIPESTATUS[0]}

if [[ $HPL_STATUS -eq 0 ]]; then
    echo "HPL completed successfully. Creating tarball..."
    rm -f $HPL_ROOT/../CalebLin.tar
    tar -cvf $HPL_ROOT/../CalebLin.tar HPL.dat hpl.cmd hpl.out hplscript.sh
else
    echo "HPL failed (exit code $HPL_STATUS). Skipping tarball creation."
fi