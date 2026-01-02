#!/bin/bash
#SBATCH -p slimey
#SBATCH -J <name>_run
#SBATCH -e output/<short>%j.err
#SBATCH -o output/<short>%j.out
#SBATCH -N 2
#SBATCH --ntasks=32
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --chdir=/home/caleb/HPL

HPL=<name>

source helpers.sh
add_build <LAdir> <LAname>
add_build <MPdir> <MPname>

# Threading
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

export OMPI_MCA_btl_tcp_if_include=enp1s0 
export OMPI_MCA_btl=self,vader,tcp

export MPICH_INTERFACE_HOSTNAME=enp1s0
export MPICH_NET_DEVICES=ch3:nemesis:tcp,shm,self

pkill -f mpirun
pkill -f orted

cp -f HPL.dat opt/$HPL/bin/
cp -f HPL.dat output/dats/HPL-$SLURM_JOB_ID.dat
# echo $SLURM_NTASKS $SLURM_CPUS_PER_TASK
echo $(which mpirun)
mpirun -np 32 opt/$HPL/bin/xhpl
# srun opt/$HPL/bin/xhpl

# echo $OMP_NUM_THREADS
echo "FINISHED RUN: <name>"