#!/usr/bin/env bash

set -ex

# ls /usr/local/lib/python3.11/site-packages/mypkg

make test
(
    cd /
    python3 -c "import mypkg"
)
pytest
