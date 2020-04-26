#!/bin/bash
set -eu

# Allow calling this script from it's dir.
if [ -f teapot-to-pascal.lpr ]; then
  cd ../../../
fi

# Call this from ../../ (or just use `make examples').
# Find the build tool, use it to compile
if which tools/build-tool/castle-engine > /dev/null; then
  CASTLE_ENGINE="`pwd`/tools/build-tool/castle-engine"
else
  CASTLE_ENGINE=castle-engine
fi

"${CASTLE_ENGINE}" simple-compile tools/internal/teapot-to-pascal/teapot-to-pascal.lpr
