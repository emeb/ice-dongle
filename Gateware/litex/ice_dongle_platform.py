#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2020 Piotr Esden-Tempski <piotr@esden.net>
# Copyright (c) 2021 Sylvain Munaut <tnt@246tNt.com>
# Copyright (c) 2022 Eric Brombaugh <ebrombaugh1@cox.net>
# SPDX-License-Identifier: BSD-2-Clause

# ice-dongle FPGA:
# - Design files: https://github.com/icebreaker-fpga/icebreaker

from litex.build.dfu import DFUProg
from litex.build.generic_platform import *
from litex.build.lattice import LatticeiCE40Platform

# IOs ----------------------------------------------------------------------------------------------

_io_v0 = [
    # Clk / Rst
    ("clk12", 0, Pins("35"), IOStandard("LVCMOS33")),

    # Leds
    ("user_ledr_n",   0, Pins("39"), IOStandard("LVCMOS33")), # Color-specific alias
    ("user_ledg_n",   0, Pins("40"), IOStandard("LVCMOS33")), # Color-specific alias
    ("user_ledb_n",   0, Pins("41"), IOStandard("LVCMOS33")), # Color-specific alias

    # Button
    ("user_btn_n",    0, Pins( "2"), IOStandard("LVCMOS33"), Misc("PULLUP")),

    # USB
    ("usb", 0,
        Subsignal("d_p", Pins("42")),
        Subsignal("d_n", Pins("38")),
        Subsignal("pullup", Pins("37")),
        IOStandard("LVCMOS33")
    ),

    # Serial
    ("serial", 0,
        Subsignal("rx", Pins("12")),
        Subsignal("tx", Pins("11"), Misc("PULLUP")),
        IOStandard("LVCMOS33")
    ),

    # SPIFlash
    ("spiflash", 0,
        Subsignal("cs_n", Pins("16"), IOStandard("LVCMOS33")),
        Subsignal("clk",  Pins("15"), IOStandard("LVCMOS33")),
        Subsignal("miso", Pins("17"), IOStandard("LVCMOS33")),
        Subsignal("mosi", Pins("14"), IOStandard("LVCMOS33")),
        Subsignal("wp",   Pins("18"), IOStandard("LVCMOS33")),
        Subsignal("hold", Pins("19"), IOStandard("LVCMOS33")),
    ),
    ("spiflash4x", 0,
        Subsignal("cs_n", Pins("16"), IOStandard("LVCMOS33")),
        Subsignal("clk",  Pins("15"), IOStandard("LVCMOS33")),
        Subsignal("dq",   Pins("14 17 18 19"), IOStandard("LVCMOS33")),
    ),
]

# Connectors ---------------------------------------------------------------------------------------

_connectors_v0 = [
    ("EYESPI",   "36 34 32 31 28 27 26 25 23 21 20 48 47 46 45 44"),
    ("QWIIC",   "3 43")
]


# Platform -----------------------------------------------------------------------------------------

class Platform(LatticeiCE40Platform):
    default_clk_name   = "clk12"
    default_clk_period = 1e9/12e6

    def __init__(self, revision="v0", toolchain="icestorm"):
        assert revision in ["v0"]
        io, connectors = {
            "v0": (_io_v0, _connectors_v0),
        }[revision]
        LatticeiCE40Platform.__init__(self, "ice40-up5k-sg48", io, connectors, toolchain=toolchain)

    def create_programmer(self):
        return DFUProg(vid="1d50", pid="6146")

    def do_finalize(self, fragment):
        LatticeiCE40Platform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk12", loose=True), 1e9/12e6)
