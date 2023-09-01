#!/usr/bin/env bash

set -ex

make test
(
    cd /
    python3 -c "import mypkg"
)
pytest
