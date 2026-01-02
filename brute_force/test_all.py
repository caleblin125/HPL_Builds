import os
import itertools
import copy
import re

root = "/home/caleb/HPL"
os.chdir(root)
print("navigated to root", root)

os.chdir("brute_force")
makefile = "Make.Slugalicious"
with open(makefile) as file:
    makeTextSample = file.read()

batchfile = "hpl.slurm"
with open(batchfile) as file:
    batchTextSample = file.read()

buildfile = "script.sh"
with open(buildfile) as file:
    buildTextSample = file.read()
os.chdir(root)

def checkPathDir(path:str):
    return path if os.path.isdir(path) else ""

def findPath(root:str, names:list[str]):
    path = ""
    for n in names:
        path = checkPathDir(os.path.join(root, n))
        if path != "":
            return path
    print("unable to find", names, "in", root)
    return path

def findFile(root:str, regex:str):
    path = ""
    for file in os.listdir(root):
        path = os.path.join(root, file) if re.match(regex, file) else ""
        if path != "":
            return path
    print("unable to find", regex, "in", root)
    return path

class BLAS():
    def __init__(self, name:str, dir, link=None):
        self.name = name
        if dir[0] == r"/":
            self.dir = dir
        else:
            self.dir = os.path.join(root, dir)
        if not os.path.isdir(self.dir):
            print(name, "is invalid:", dir)
            return
        if link == None:
            self.lib = findFile(findPath(self.dir, ["lib"]),r".*bl.s.*\.a")
        else:
            self.lib = os.path.join(self.dir, "lib", link)
        self.inc = findPath(self.dir, ["inc", "include"])

    def load(self, d:dict):
        d["LAdir"] = self.dir 
        d["LAinc"] = self.inc
        d["LAlib"] = self.lib
        d["LAname"] = self.name

class MPI():
    def __init__(self, name:str, dir):
        self.name = name
        if dir[0] == r"/":
            self.dir = dir
        else:
            self.dir = os.path.join(root, dir)
        if not os.path.isdir(self.dir):
            print(name, "is invalid:", dir)
            return
        self.lib = findFile(findPath(self.dir, ["lib"]),r".*mpi((\.a)|(\.so))")
        self.inc = findPath(self.dir, ["inc", "include"])

    def load(self, d:dict):
        d["MPdir"] = self.dir 
        d["MPinc"] = self.inc
        d["MPlib"] = self.lib
        d["MPname"] = self.name

blases = [
    BLAS("OpenBLAS", "opt/OpenBLAS"),
    BLAS("AOCL", "opt/AOCL"),
    BLAS("MKL", "/software/u24/intel/oneAPI/2024.2.1/mkl/2024.2", link="libmkl_rt.so")
] 

mpis = [
    MPI("OpenMPI", "opt/OpenMPI"),
    # MPI("HPCX", "opt/HPCX/hpcx-v2.18.1-gcc-mlnx_ofed-ubuntu22.04-cuda12-x86_64/ompi")
    MPI("MPICH", "opt/MPICH")
]

def replace(text:str, d:dict[(str, str)]):
    text = copy.copy(text)
    for key, value in d.items():
        text = text.replace(f"<{key}>", value)
    return text

os.makedirs("brute_force/", exist_ok=True)
for blas, mpi in itertools.product(blases, mpis):
    print("\n", blas.name, mpi.name)
    name = f"HPL_{blas.name}_{mpi.name}"
    short = f"{blas.name}_{mpi.name}"
    path = f"brute_force/{name}"

    d = dict()

    blas.load(d)
    mpi.load(d)
    d["name"] = name
    d["short"] = short
    d["path"] = path
    print(d)

    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, makefile), "w") as file:
        file.write(replace(makeTextSample, d))
    with open(os.path.join(path, batchfile), "w") as file:
        file.write(replace(batchTextSample, d))
    with open(os.path.join(path, buildfile), "w") as file:
        file.write(replace(buildTextSample, d))
    os.chmod(os.path.join(path, makefile), 0o777)
    os.chmod(os.path.join(path, batchfile), 0o777)
    os.chmod(os.path.join(path, buildfile), 0o777)