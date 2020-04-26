#!/bin/bash
set -euo pipefail

# Pack Castle Game Engine release (source + binaries).
# Uses bash strict mode, see http://redsymbol.net/articles/unofficial-bash-strict-mode/
# (but without IFS modification, deliberately, we want to split on space).

OUTPUT_DIRECTORY=`pwd`
VERBOSE=false

# Require building release with latest stable FPC, as supported by CGE,
# see https://castle-engine.io/supported_compilers.php .
check_fpc_version ()
{
  local FPC_VERSION=`fpc -iV`
  local REQUIRED_FPC_VERSION='3.0.4'
  if [ "${FPC_VERSION}" '!=' "${REQUIRED_FPC_VERSION}" ]; then
    echo "pack_release: Expected FPC version ${REQUIRED_FPC_VERSION}, but got ${FPC_VERSION}"
    exit 1
  fi
}

# Compile build tool, put it on $PATH
prepare_build_tool ()
{
  if which make.exe > /dev/null; then
    HOST_EXE_EXTENSION='.exe'
  else
    HOST_EXE_EXTENSION=''
  fi
  echo "Host exe extension: '${HOST_EXE_EXTENSION}' (should be empty on Unix, '.exe' on Windows)"

  if [ "${VERBOSE}" '!=' 'true' ]; then
    CASTLE_FPC_OPTIONS="-vi-"
  fi

  cd "${CASTLE_ENGINE_PATH}"
  tools/build-tool/castle-engine_compile.sh
  local BIN_TEMP_PATH="/tmp/castle-engine-release-bin-$$/"
  mkdir -p "${BIN_TEMP_PATH}"
  cp "tools/build-tool/castle-engine${HOST_EXE_EXTENSION}" "${BIN_TEMP_PATH}"
  export PATH="${BIN_TEMP_PATH}:${PATH}"

  # sanity checks
  if ! which castle-engine > /dev/null; then
    echo 'pack_release: After installing CGE build tool, we still cannot find it on $PATH'
    exit 1
  fi
  FOUND_CGE_BUILD_TOOL="`which castle-engine`"
  EXPECTED_CGE_BUILD_TOOL="${BIN_TEMP_PATH}/castle-engine${HOST_EXE_EXTENSION}"
  if [ "${FOUND_CGE_BUILD_TOOL}" '!=' "${EXPECTED_CGE_BUILD_TOOL}" ]; then
    echo "pack_release: Unexpected CGE build tool on \$PATH: found ${FOUND_CGE_BUILD_TOOL}, expected ${EXPECTED_CGE_BUILD_TOOL}"
    exit 1
  fi
}

# Calculate $CGE_VERSION
calculate_cge_version ()
{
  CGE_VERSION="`castle-engine --version | awk '{print $2}'`"
  echo "Detected CGE version ${CGE_VERSION}"
}

# Call lazbuild $@.
# If it fails, try again.
#
# Workarounds lazbuild crashes with Lazarus 1.8,
# at least for Win32/i386 (when using cross-compiler from Linux/x86_64):
#   $0000000000563D4A line 1220 of ideexterntoolintf.pas
#   $00000000005AB34E line 590 of exttools.pas
#   $00000000005B0061 line 1525 of exttools.pas
#   $00000000005B15DE line 1814 of exttools.pas
lazbuild_twice ()
{
  if ! lazbuild "$@"; then
    echo 'lazbuild failed, trying again'
    lazbuild "$@"
  fi
}

# Download another repository from GitHub, compile with current build tool,
# move result to $3 .
# Assumes $CASTLE_BUILD_TOOL_OPTIONS defined.
# Changes current dir.
add_external_tool ()
{
  local GITHUB_NAME="$1"
  local EXE_NAME="$2"
  local OUTPUT_BIN="$3"
  shift 2

  local TEMP_PATH_TOOL=/tmp/castle-engine-release-$$/"${GITHUB_NAME}"/
  mkdir -p "${TEMP_PATH_TOOL}"
  cd "${TEMP_PATH_TOOL}"
  wget https://codeload.github.com/castle-engine/"${GITHUB_NAME}"/zip/master --output-document "${GITHUB_NAME}".zip
  unzip "${GITHUB_NAME}".zip
  cd "${GITHUB_NAME}"-master
  castle-engine $CASTLE_BUILD_TOOL_OPTIONS compile
  mv "${EXE_NAME}" "${OUTPUT_BIN}"
}

do_pack_platform ()
{
  local OS="$1"
  local CPU="$2"
  shift 2
  
  # restore CGE path, otherwise it points to a temporary (and no longer existing)
  # dir after one execution of do_pack_platform
  export CASTLE_ENGINE_PATH="${ORIGINAL_CASTLE_ENGINE_PATH}"

  case "$OS" in
    win32|win64) local EXE_EXTENSION='.exe' ;;
    *)           local EXE_EXTENSION=''     ;;
  esac

  # Pass options to compile indicating target OS/CPU for everything
  export CASTLE_FPC_OPTIONS="-T${OS} -P${CPU}"
  export CASTLE_BUILD_TOOL_OPTIONS="--os=${OS} --cpu=${CPU}"
  local  CASTLE_LAZBUILD_OPTIONS="--os=${OS} --cpu=${CPU}"
  local  MAKE_OPTIONS=""

  if [ "${VERBOSE}" '!=' 'true' ]; then
    CASTLE_FPC_OPTIONS="${CASTLE_FPC_OPTIONS} -vi-"
    CASTLE_BUILD_TOOL_OPTIONS="${CASTLE_BUILD_TOOL_OPTIONS} --compiler-option=-vi-"
    CASTLE_LAZBUILD_OPTIONS="${CASTLE_LAZBUILD_OPTIONS} -q"
    MAKE_OPTIONS="${MAKE_OPTIONS} --quiet"
  fi

  # Create temporary CGE copy, for packing
  local TEMP_PATH=/tmp/castle-engine-release-$$/
  mkdir -p "$TEMP_PATH"
  local TEMP_PATH_CGE=/tmp/castle-engine-release-$$/castle_game_engine/
  cp -R "${CASTLE_ENGINE_PATH}" "${TEMP_PATH_CGE}"

  cd "${TEMP_PATH_CGE}"

  # Initial cleanups after "cp -R ...".
  # .cache and .cge-jenkins-lazarus are created in Jenkins + Docker job, where $HOME is equal to CGE dir.
  rm -Rf .git .svn .cache .cge-jenkins-lazarus

  # Extend castleversion.inc with GIT hash
  # (useful to have exact version in case of snapshots).
  # $GIT_COMMIT is defined by Jenkins, see https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-belowJenkinsSetEnvironmentVariables
  if [ -n "${GIT_COMMIT:-}" ]; then
    echo "+ ' (commit ${GIT_COMMIT})'" >> src/base/castleversion.inc
  fi

  # update environment to use CGE in temporary location
  export CASTLE_ENGINE_PATH="${TEMP_PATH_CGE}"
  lazbuild_twice $CASTLE_LAZBUILD_OPTIONS packages/castle_base.lpk
  lazbuild_twice $CASTLE_LAZBUILD_OPTIONS packages/castle_window.lpk
  lazbuild_twice $CASTLE_LAZBUILD_OPTIONS packages/castle_components.lpk

  # Make sure no leftovers from previous compilations remain, to affect tools
  make cleanmore $MAKE_OPTIONS

  # Compile most tools with FPC, and castle-editor with lazbuild
  make tools
  lazbuild_twice $CASTLE_LAZBUILD_OPTIONS tools/castle-editor/code/castle_editor.lpi

  # Place tools binaries in bin/ subdirectory
  mkdir -p "${TEMP_PATH_CGE}"bin-to-keep
  cp tools/build-tool/castle-engine"${EXE_EXTENSION}" \
     tools/texture-font-to-pascal/texture-font-to-pascal"${EXE_EXTENSION}" \
     tools/image-to-pascal/image-to-pascal"${EXE_EXTENSION}" \
     tools/castle-curves/castle-curves"${EXE_EXTENSION}" \
     tools/sprite-sheet-to-x3d/sprite-sheet-to-x3d"${EXE_EXTENSION}" \
     tools/to-data-uri/to-data-uri"${EXE_EXTENSION}" \
     tools/castle-editor/castle-editor"${EXE_EXTENSION}" \
     "${TEMP_PATH_CGE}"bin-to-keep
  # Add DLLs on Windows
  case "$OS" in
    win32|win64)
      cp "${CASTLE_ENGINE_PATH}"/tools/build-tool/data/external_libraries/"${CPU}"-"${OS}"/*.dll \
         "${CASTLE_ENGINE_PATH}"/tools/build-tool/data/external_libraries/"${CPU}"-"${OS}"/openssl/*.dll \
         "${TEMP_PATH_CGE}"bin-to-keep
      ;;
  esac

  # Make sure no leftovers from tools compilation remain
  make cleanmore $MAKE_OPTIONS

  # After make clean, make sure bin/ exists and is filled with what we need
  mv "${TEMP_PATH_CGE}"bin-to-keep "${TEMP_PATH_CGE}"bin

  # Add PasDoc docs
  make -C doc/pasdoc/ clean html $MAKE_OPTIONS
  rm -Rf doc/pasdoc/cache/

  # Add tools
  add_external_tool view3dscene view3dscene"${EXE_EXTENSION}" "${TEMP_PATH_CGE}"bin
  add_external_tool castle-view-image castle-view-image"${EXE_EXTENSION}" "${TEMP_PATH_CGE}"bin

  local ARCHIVE_NAME="castle-engine-${CGE_VERSION}-${OS}-${CPU}.zip"
  cd "${TEMP_PATH}"
  rm -f "${ARCHIVE_NAME}"
  zip -r "${ARCHIVE_NAME}" castle_game_engine/
  mv -f "${ARCHIVE_NAME}" "${OUTPUT_DIRECTORY}"
  rm -Rf "${TEMP_PATH}"
}

ORIGINAL_CASTLE_ENGINE_PATH="${CASTLE_ENGINE_PATH}"

check_fpc_version
prepare_build_tool
calculate_cge_version
do_pack_platform win64 x86_64
do_pack_platform win32 i386
do_pack_platform linux x86_64
