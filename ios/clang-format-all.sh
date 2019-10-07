#!/bin/sh

find . -not '(' \
       -path '*/Pods/*' -or \
       -name 'Reachability.*' -or \
       -name '*.pbobjc.*' \
     ')' -and '(' \
       -name '*.h' -or \
       -name '*.m' -or \
       -name '*.mm' \
     ')' \
     -exec clang-format -style=file -i {} '+'
