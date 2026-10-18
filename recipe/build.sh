#!/usr/bin/env bash
set -exuo pipefail

# The upstream tree is hoisted straight into $SRC_DIR (see recipe.yaml), so
# there is nothing to cd into -- we are already at the project root.
#
# Keep the upstream build focused on the userspace driver:
#  * ENABLE_NPU_COMPILER_BUILD=OFF — the LLVM/MLIR-based driver compiler
#    is a much larger build and is shipped from a separate recipe.
#  * ENABLE_VALIDATION_BUILD=OFF / ENABLE_TOOLS_BUILD=OFF — no test apps.
#  * ENABLE_NPU_PERFETTO_BUILD=OFF — no Perfetto tracing (default).
#  * ENABLE_NPU_UNIT_TESTS=OFF — added by patch 0002, gates the
#    third_party/googletest-dependent umd unit_tests subdirs. It defaults
#    to ON upstream-style (like ENABLE_VALIDATION_BUILD), so passing it
#    explicitly here is what actually turns the unit tests off.
# Upstream's third_party/cmake/level-zero.cmake first tries pkg-config;
# the level-zero-devel host dep above provides level-zero.pc so the
# build does not need to fetch the kobuk PPA .debs or fall back to
# building Level Zero from source.
mkdir -p build
pushd build

cmake ${CMAKE_ARGS} \
    -G Ninja \
    -DENABLE_NPU_COMPILER_BUILD=OFF \
    -DENABLE_NPU_PERFETTO_BUILD=OFF \
    -DENABLE_VALIDATION_BUILD=OFF \
    -DENABLE_TOOLS_BUILD=OFF \
    -DENABLE_NPU_UNIT_TESTS=OFF \
    -DENABLE_NPU_LOGGING=ON \
    ..

cmake --build . --parallel "${CPU_COUNT}"

# Install only the userspace driver component. This skips:
#   * fw-npu (kernel firmware — cannot live in $CONDA_PREFIX)
#   * driver-compiler-npu (packaged separately)
#   * validation-npu, tools (not built)
cmake --install . --component level-zero-npu --prefix "$PREFIX"

popd

# Stand-in for https://github.com/conda-forge/level-zero-feedstock/pull/92:
# until the loader searches its own directory, it never finds this driver in
# $CONDA_PREFIX/lib. ZE_ENABLE_ALT_DRIVERS replaces discovery, so list every
# driver the loader knows by default, not only this one.
mkdir -p "$PREFIX/etc/conda/env_vars.d"
cat > "$PREFIX/etc/conda/env_vars.d/intel-level-zero-npu.json" <<'EOF'
{
  "ZE_ENABLE_ALT_DRIVERS": "libze_intel_gpu.so.1,libze_intel_gpu_legacy1.so.1,libze_intel_vpu.so.1,libze_intel_npu.so.1"
}
EOF
