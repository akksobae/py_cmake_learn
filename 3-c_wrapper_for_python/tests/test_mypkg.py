#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import mypkg


def test_run_mypkg_ret():
    assert mypkg.message(0) == 0


def test_run_mypkg_out(capfd):
    mypkg.message(0)
    captured = capfd.readouterr()
    assert captured.out == "Hello world!\n"
