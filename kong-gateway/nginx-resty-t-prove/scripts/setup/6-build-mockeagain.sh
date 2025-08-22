#!/bin/bash

set -e
cd /runner/work/

git clone https://github.com/openresty/mockeagain.git
cd mockeagain/
make CC=$CC -j$JOBS