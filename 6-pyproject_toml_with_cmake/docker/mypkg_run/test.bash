#!/usr/bin/env bash

set -ex

make test
(
    cd /
    python3 -c "import mypkg"
)

pytest

make uninstall

(
    cd /
    if python3 -c "import mypkg"; then
        echo "Uninstallation failed."
        exit 1
    else
        echo "Uninstallation succeeded."
        exit 0
    fi
)
