#!/bin/bash

set -e

# Ensure we're in the right directory.
cd "${BASH_SOURCE%/*}/"

# Run clang-format on all .h, .m or .mm files.
find . -not '(' \
       -path '*/Pods/*' -or \
       -name 'Reachability.*' -or \
       -name '*.pbobjc.*' \
     ')' -and '(' \
       -name '*.h' -or \
       -name '*.m' -or \
       -name '*.mm' \
     ')' \
     -exec ../utils/clang-format -style=file -i {} '+'
