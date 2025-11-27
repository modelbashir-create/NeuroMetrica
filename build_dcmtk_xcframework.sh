#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DCMTK_SOURCE="$ROOT_DIR/dcmtk-full-backup/source"
BUILD_ROOT="$ROOT_DIR/DCMTKBuild"
INSTALL_ROOT="$ROOT_DIR/DCMTKInstall"
ARTIFACT_DIR="$ROOT_DIR/DCMTKArtifacts"
OUTPUT_XCFRAMEWORK="$ARTIFACT_DIR/DCMTK.xcframework"

LIBS=(
  ofstd oflog dcmdata dcmimgle dcmimage dcmjpeg dcmjpls dcmect dcmfg dcmiod
  dcmpmap dcmrt dcmseg dcmsr dcmnet dcmqrdb dcmpstat dcmtls dcmsign dcmtract
)

command -v cmake >/dev/null 2>&1 || { echo "cmake is required"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is required"; exit 1; }
command -v libtool >/dev/null 2>&1 || { echo "libtool is required"; exit 1; }

mkdir -p "$BUILD_ROOT" "$INSTALL_ROOT" "$ARTIFACT_DIR"

build_variant() {
  local name="$1"       # e.g. macos, ios, ios-sim
  local system_name="$2" # e.g. iOS, tvOS, visionOS
  local sysroot="$3"     # e.g. macosx, iphoneos
  local archs="$4"       # semicolon-separated list
  local deployment_target="$5"

  local build_dir="$BUILD_ROOT/$name"
  local install_dir="$INSTALL_ROOT/$name"

  rm -rf "$build_dir" "$install_dir"
  mkdir -p "$build_dir" "$install_dir"

  local cmake_args=(
    -S "$DCMTK_SOURCE"
    -B "$build_dir"
    -G "Unix Makefiles"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$install_dir"
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_CXX_STANDARD=17
    -DCMAKE_OSX_ARCHITECTURES="$archs"
    -DCMAKE_OSX_SYSROOT="$sysroot"
    -DDCMTK_ENABLE_CHARSET_CONVERSION=oficonv
    -DDCMTK_ENABLE_BUILTIN_OFICONV_DATA=ON
    -DDCMTK_WITH_DOXYGEN=OFF
    -DBUILD_APPS=OFF # disable command-line tools to speed up builds
  )

  if [[ -n "$system_name" ]]; then
    cmake_args+=("-DCMAKE_SYSTEM_NAME=$system_name")
    # Follow DCMTK INSTALL cross-compilation guidance to avoid runtime checks.
    cmake_args+=(
      -DDCMTK_NO_TRY_RUN=TRUE
      -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
      -DDCMTK_ICONV_FLAGS_ANALYZED=TRUE
      -DDCMTK_FIXED_ICONV_CONVERSION_FLAGS=AbortTranscodingOnIllegalSequence
      -DDCMTK_STDLIBC_ICONV_HAS_DEFAULT_ENCODING=FALSE
    )
  fi

  if [[ -n "$deployment_target" ]]; then
    cmake_args+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=$deployment_target")
  fi

  echo "\n=== Configuring ${name} (${archs}) ==="
  cmake "${cmake_args[@]}"

  local cpu_count
  cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)

  echo "\n=== Building ${name} ==="
  cmake --build "$build_dir" --config Release -- -j"$cpu_count"

  echo "\n=== Installing ${name} ==="
  cmake --install "$build_dir" --config Release

  local lib_paths=()
  for lib in "${LIBS[@]}"; do
    lib_paths+=("$install_dir/lib/lib${lib}.a")
  done

  local combined_lib="$install_dir/lib/libdcmtk_combined.a"
  echo "\n=== Creating fat static library for ${name} ==="
  libtool -static -o "$combined_lib" "${lib_paths[@]}"
}

build_variant "macos" "" "macosx" "arm64;x86_64" "11.0"
build_variant "ios" "iOS" "iphoneos" "arm64" "13.0"
build_variant "ios-sim" "iOS" "iphonesimulator" "arm64;x86_64" "13.0"
build_variant "tvos" "tvOS" "appletvos" "arm64" "13.0"
build_variant "tvos-sim" "tvOS" "appletvsimulator" "arm64;x86_64" "13.0"
build_variant "visionos" "visionOS" "xros" "arm64" "1.0"
build_variant "visionos-sim" "visionOS" "xrsimulator" "arm64;x86_64" "1.0"

rm -rf "$OUTPUT_XCFRAMEWORK"

xcodebuild -create-xcframework \
  -library "$INSTALL_ROOT/macos/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/macos/include" \
  -library "$INSTALL_ROOT/ios/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/ios/include" \
  -library "$INSTALL_ROOT/ios-sim/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/ios-sim/include" \
  -library "$INSTALL_ROOT/tvos/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/tvos/include" \
  -library "$INSTALL_ROOT/tvos-sim/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/tvos-sim/include" \
  -library "$INSTALL_ROOT/visionos/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/visionos/include" \
  -library "$INSTALL_ROOT/visionos-sim/lib/libdcmtk_combined.a" -headers "$INSTALL_ROOT/visionos-sim/include" \
  -output "$OUTPUT_XCFRAMEWORK"

echo "\nXCFramework created at: $OUTPUT_XCFRAMEWORK"
