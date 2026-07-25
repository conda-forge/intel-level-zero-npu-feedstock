#!/usr/bin/env bash
set -exuo pipefail

# The main source is extracted into an explicit `target_directory` (see
# recipe.yaml) so the vendored third_party sources can nest inside it.
# The name is intentionally unversioned so this never needs touching on a
# version bump.
cd linux-npu-driver

# Keep the upstream build focused on the userspace driver:
#  * ENABLE_NPU_COMPILER_BUILD=OFF — the LLVM/MLIR-based driver compiler
#    is a much larger build and is shipped from a separate recipe.
#  * ENABLE_VALIDATION_BUILD=OFF / ENABLE_TOOLS_BUILD=OFF — no test apps.
#  * ENABLE_NPU_PERFETTO_BUILD=OFF — no Perfetto tracing (default).
#  * ENABLE_NPU_UNIT_TESTS=OFF — added by patch 0002, gates the
#    third_party/googletest-dependent umd unit_tests subdirs.
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
