#!/bin/bash
#SBATCH -p slimey
#SBATCH -J hpl_run
#SBATCH -e output/%j.err
#SBATCH -o output/%j.out
#SBATCH -N 2
#SBATCH --ntasks=32
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --chdir=/home/caleb/HPL

HPL="HPL"

source helpers.sh
add_build opt/OpenBLAS openblas
add_build opt/OpenMPI openmpi

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1

export OMPI_MCA_btl_tcp_if_include=enp1s0 
export OMPI_MCA_btl=self,vader,tcp 

cp -f HPL.dat opt/$HPL/bin/
cp -f HPL.dat output/dats/HPL-$SLURM_JOB_ID.dat
mpirun -np 32 opt/$HPL/bin/xhpl