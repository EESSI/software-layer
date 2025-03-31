#!/bin/bash
# Setup script to create fake NVIDIA libraries for testing

# Create directories for fake NVIDIA libraries
mkdir -p /tmp/nvidia_libs
mkdir -p /tmp/nvidia_libs_duplicate

# Create common NVIDIA libraries with minimal content
libraries=(
    "libcuda.so.1"
    "libnvidia-ml.so.1"
    "libnvidia-ptxjitcompiler.so.1"
    "libOpenCL.so.1"
    "libnvidia-fatbinaryloader.so.1"
    "libnvidia-opencl.so.1"
    "libcudadebugger.so.1"
    "libnvidia-compiler.so.1"
    "libnvidia-nvvm.so.1"
)

for lib in "${libraries[@]}"; do
    # Create fake library file with some minimal content
    echo "This is a fake $lib for testing purposes" > "/tmp/nvidia_libs/$lib"
    # Make it executable to pass potential file type checks
    chmod +x "/tmp/nvidia_libs/$lib"
    # Create a symlink for libraries without version number (if the library has one)
    if [[ "$lib" == *".so."* ]]; then
        base_lib=$(echo "$lib" | sed 's/\.so\.[0-9]*/.so/')
        ln -sf "/tmp/nvidia_libs/$lib" "/tmp/nvidia_libs/$base_lib"
    fi
    
    # Create duplicate libraries in a different location
    if [[ "$lib" == "libcuda.so.1" || "$lib" == "libnvidia-ml.so.1" ]]; then
        echo "This is a duplicate $lib for testing purposes" > "/tmp/nvidia_libs_duplicate/$lib"
        chmod +x "/tmp/nvidia_libs_duplicate/$lib"
        if [[ "$lib" == *".so."* ]]; then
            base_lib=$(echo "$lib" | sed 's/\.so\.[0-9]*/.so/')
            ln -sf "/tmp/nvidia_libs_duplicate/$lib" "/tmp/nvidia_libs_duplicate/$base_lib"
        fi
    fi
done

# Create a fake ldconfig cache that points to our fake libraries
mkdir -p /tmp/ldconfig

# Create a wrapper script for ldconfig
cat > /tmp/ldconfig/ldconfig << 'EOF'
#!/bin/bash
# Fake ldconfig command that returns our fake libraries

if [ "$1" = "-p" ]; then
    # Simulate ldconfig -p output with duplicate entries
    echo "libcuda.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libcuda.so.1"
    echo "libcuda.so.1 (libc6,x86-64) => /tmp/nvidia_libs_duplicate/libcuda.so.1"
    echo "libcuda.so (libc6,x86-64) => /tmp/nvidia_libs/libcuda.so"
    echo "libcuda.so (libc6,x86-64) => /tmp/nvidia_libs_duplicate/libcuda.so"
    echo "libnvidia-ml.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-ml.so.1"
    echo "libnvidia-ml.so.1 (libc6,x86-64) => /tmp/nvidia_libs_duplicate/libnvidia-ml.so.1"
    echo "libnvidia-ml.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-ml.so"
    echo "libnvidia-ml.so (libc6,x86-64) => /tmp/nvidia_libs_duplicate/libnvidia-ml.so"
    echo "libnvidia-ptxjitcompiler.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-ptxjitcompiler.so.1"
    echo "libnvidia-ptxjitcompiler.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-ptxjitcompiler.so"
    echo "libOpenCL.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libOpenCL.so.1"
    echo "libOpenCL.so (libc6,x86-64) => /tmp/nvidia_libs/libOpenCL.so"
    echo "libnvidia-fatbinaryloader.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-fatbinaryloader.so.1"
    echo "libnvidia-fatbinaryloader.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-fatbinaryloader.so"
    echo "libnvidia-opencl.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-opencl.so.1"
    echo "libnvidia-opencl.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-opencl.so"
    echo "libcudadebugger.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libcudadebugger.so.1"
    echo "libcudadebugger.so (libc6,x86-64) => /tmp/nvidia_libs/libcudadebugger.so"
    echo "libnvidia-compiler.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-compiler.so.1"
    echo "libnvidia-compiler.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-compiler.so"
    echo "libnvidia-nvvm.so.1 (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-nvvm.so.1"
    echo "libnvidia-nvvm.so (libc6,x86-64) => /tmp/nvidia_libs/libnvidia-nvvm.so"
fi
EOF
chmod +x /tmp/ldconfig/ldconfig

# Create a wrapper for ldd that returns minimal dependency info for our libraries
cat > /tmp/ldconfig/ldd << 'EOF'
#!/bin/bash
# Fake ldd command that doesn't show any missing dependencies
echo "linux-vdso.so.1 =>  (0x00007ffca39ed000)"
echo "libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f2ace77e000)"
echo "/lib64/ld-linux-x86-64.so.2 (0x00007f2aceb41000)"
EOF
chmod +x /tmp/ldconfig/ldd
