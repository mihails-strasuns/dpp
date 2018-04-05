#!/bin/bash

set -euo pipefail

bin/d++ --preprocess-only --d-file-name "bin/$1.d" "examples/$1.dpp"
dmd "-ofbin/$1" "bin/$1.d" -L-lcurl -L-lnanomsg
"bin/$1"
