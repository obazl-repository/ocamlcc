#!/bin/bash

# Function to echo commands
exe() { echo "\$ ${@/eval/}" ; "$@" ; }

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
# https://github.com/bazelbuild/bazel/blob/master/tools/bash/runfiles/runfiles.bash
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
    source "$0.runfiles/$f" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
    { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

# echo "MANIFEST: ${RUNFILES_MANIFEST_FILE}"
# echo "`cat ${RUNFILES_MANIFEST_FILE}`"

# echo "ARGS: $@"
OCAMLRUN=$1
shift
REPL=$1
shift

# set -x

OCAMLRUN=$(rlocation $OCAMLRUN)
REPL=$(rlocation $REPL)
STDLIBDIR=$(dirname $(rlocation ocamlcc/stdlib/_BS_vv/Stdlib.cmi))

# FIXME: pass -noinit etc. as args
CMD="$OCAMLRUN $REPL -noinit -nostdlib -I $STDLIBDIR $@"

if [ -z ${VERBOSE+x} ]
then
    $CMD
else
    exe eval $CMD
fi

