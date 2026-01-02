#!/bin/bash
set -e

mkdir -p ~/HPL_FINAL
cd ~/HPL_FINAL
export HPL_ROOT=$(pwd)
export INSTALL_DIR="$(pwd)/opt"
export CLONE_DIR="$(pwd)/clone"
export BUILD_DIR="$(pwd)/build"

mkdir -p $INSTALL_DIR $CLONE_DIR $BUILD_DIR

export COMMON_FLAGS="-O3 -march=native -mfma -funroll-loops -fPIC"
export CC=gcc
export CFLAGS="$COMMON_FLAGS"
export CXX=g++
export CXXFLAGS="$COMMON_FLAGS"

#---------------------------------------

basic_cmake_github(){
    local repo_url="$1"
    shift 1
    local configure=OFF
    local name=""
    local checkout=""
    local cmake_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -configure)
                configure="$2"
                shift 2
                ;;
            -c|--checkout)
                checkout="$2"
                shift 2
                ;;
            -n|--name)
                name="$2"
                shift 2
                ;;
            --cmake-args)
                shift
                while [[ $# -gt 0 ]]; do
                    cmake_args+=("$1")
                    shift
                done
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$repo_url" ]]; then
        echo "Usage: build_cmake_project <repo> [-c <branch/ref>] [--configure <ON/OFF>] [--cmake-args <args>]"
        return 1
    fi

    if [[ -z "$CLONE_DIR" ]]; then
        echo "WARNING: CLONE_DIR unset"
    fi

    if [[ -z "$BUILD_DIR" ]]; then
        echo "WARNING: BUILD_DIR unset"
    fi

    if [[ -z "$INSTALL_DIR" ]]; then
        echo "ERROR: INSTALL_DIR unset"
        return 1
    fi

    # use github name if name is not offered
    if [[ -z "$name" ]]; then
        local name=$(basename "$repo_url" .git)
    fi
    
    #paths
    local clonepath="$CLONE_DIR/$name"
    local buildpath="$BUILD_DIR/$name"
    local installpath="$INSTALL_DIR/$name"

    echo "=== Cloning $name ==="
    cd $CLONE_DIR
    #Check if can clone
    if [[ ! -d "$name" ]]; then
        git clone "$repo_url" "$name"
    else
        echo "Repo exists, skipping clone."
    fi
    cd $name || return 1

    #Checkout branch
    [[ -n "$checkout" ]] && git checkout "$checkout"

    
    if [[ $configure = "ON" ]]; then
        #configure
        cd $clonepath || return 1
        echo "=== Configuring $name ==="
        ./configure --prefix=$installpath "${cmake_args[@]}" || return 1
        echo "=== Building $name ==="
        make -j$(nproc) all || return 1
        echo "=== Installing $name ==="
        make install || return 1
    elif [[ $configure = "OFF" ]]; then
        #Build
        echo "=== Building $name ==="
        mkdir -p $buildpath
        cd "$buildpath" || return 1
        cmake "$clonepath" -DCMAKE_INSTALL_PREFIX="$installpath" "${cmake_args[@]}" || return 1
        cmake --build $buildpath -j$(nproc) || return 1

        #Install
        echo "=== Installing $name ==="
        mkdir -p $installpath
        cmake --install $buildpath || return 1
    else 
        echo "ERROR: -configure neither ON or OFF"
    fi
}

basic_cmake_tarball() {
    local url="$1"
    shift 1
    local configure=OFF
    local tarfile=""
    local src_dir=""
    local name=""
    local cmake_args=()

    if [[ -z "$url" ]]; then
        echo "Usage: build_tarball_project <url> [-n <name>] [-configure <ON/OFF>] [--cmake-args <args>]"
        return 1
    fi

    if [[ -z "$CLONE_DIR" ]]; then
        echo "WARNING: CLONE_DIR unset"
    fi

    if [[ -z "$BUILD_DIR" ]]; then
        echo "WARNING: BUILD_DIR unset"
    fi

    if [[ -z "$INSTALL_DIR" ]]; then
        echo "ERROR: INSTALL_DIR unset"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -configure)
                configure="$2"
                shift 2
                ;;
            -n|--name)
                name="$2"
                shift 2
                ;;
            --cmake-args)
                shift
                while [[ $# -gt 0 ]]; do
                    cmake_args+=("$1")
                    shift
                done
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Derive name from URL if not provided
    [[ -z "$name" ]] && name=$(basename "$url" | sed -E 's/\.tar\.(gz|bz2|xz|tgz)$//')

    local clonepath="$CLONE_DIR/$name"
    local buildpath="$BUILD_DIR/$name"
    local installpath="$INSTALL_DIR/$name"

    cd "$CLONE_DIR" || return 1

    # Download tarball
    tarfile=$(basename "$url")
    if [[ ! -f "$tarfile" ]]; then
        wget "$url"
    else
        echo "Tarball $tarfile already exists, skipping download."
    fi

    # Extract
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
            return 1
        fi
    else 
        echo "Folder already exists, assuming already unpacked"
    fi

    if [[ $configure = "ON" ]]; then
        #configure
        cd $clonepath || return 1
        echo "=== Configuring $name ==="
        ./configure --prefix=$installpath "${cmake_args[@]}" || return 1
        echo "=== Building $name ==="
        make -j$(nproc) all || return 1
        echo "=== Installing $name ==="
        make install || return 1
    elif [[ $configure = "OFF" ]]; then
        #Build
        echo "=== Building $name ==="
        mkdir -p $buildpath
        cd "$buildpath" || return 1
        cmake "$clonepath" -DCMAKE_INSTALL_PREFIX="$installpath" "${cmake_args[@]}" || return 1
        cmake --build $buildpath -j$(nproc) || return 1

        #Install
        echo "=== Installing $name ==="
        mkdir -p $installpath
        cmake --install $buildpath || return 1
    else 
        echo "ERROR: -configure neither ON or OFF"
    fi
}

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

# Remove a build prefix from environment variables and unset exported variables
remove_build() {
    local prefix="$1"
    local name="$2"

    if [[ -z "$prefix" ]]; then
        echo "Usage: remove_build <prefix> [<name>]"
        return 1
    fi

    # If name not provided, use basename
    [[ -z "$name" ]] && name="$(basename "$prefix")"
    local uname="${name^^}"  # uppercase name for exported variables

    # Helper: remove a directory from a colon-separated variable
    remove_path() {
        local varname="$1"
        local dir="$2"
        local current
        eval "current=\$$varname"
        eval "export $varname=\"$(echo "$current" | tr ':' '\n' | grep -v "^$dir\$" | paste -sd ':' -)\""
    }

    # Remove bin
    remove_path PATH "$prefix/bin"

    # Remove lib/lib64
    remove_path LD_LIBRARY_PATH "$prefix/lib"
    remove_path LD_LIBRARY_PATH "$prefix/lib64"
    remove_path LIBRARY_PATH "$prefix/lib"
    remove_path LIBRARY_PATH "$prefix/lib64"

    # Remove include
    remove_path CPATH "$prefix/include"
    remove_path C_INCLUDE_PATH "$prefix/include"
    remove_path CPLUS_INCLUDE_PATH "$prefix/include"

    # Remove CMake prefix
    remove_path CMAKE_PREFIX_PATH "$prefix"

    # Unset exported variables
    unset "${uname}_LIBRARY"
    unset "${uname}_INCLUDE_DIR"

    echo "Removed build prefix: $prefix"
}

#--------------------

basic_cmake_github https://github.com/amd/blis.git -n AOCL -configure ON --cmake-args \
    --enable-blas zen3

basic_cmake_tarball https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.9.tar.gz -n OpenMPI -configure ON --cmake-args \
    --with-slurm

#--------------------
HPL=HPL_AOCL_OpenMPI
clonepath=$CLONE_DIR/$HPL
installpath=$INSTALL_DIR/$HPL
url=https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz

cd "$CLONE_DIR" || return 1
# Download tarball
tarfile=$(basename "$url")
if [[ ! -f "$tarfile" ]]; then
    wget "$url"
else
    echo "Tarball $tarfile already exists, skipping download."
fi

# Extract
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

cd $HPL_ROOT
cp -f Make.Slugalicious $clonepath

add_build $HPL_ROOT/opt/OpenMPI OpenMPI
add_build $HPL_ROOT/opt/AOCL AOCL

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
cd $HPL_ROOT
mkdir -p output/dats
chmod 777 hpl.cmd
sbatch hpl.cmd
squeue
