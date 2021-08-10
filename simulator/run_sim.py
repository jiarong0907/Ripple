#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
run_sim.py: Top-level Run simulation.
"""

# Built-in modules
import os
import sys
import imp
import networkx as nx


# ---- Read configuration from files ----
abs_path = os.path.abspath('./config/bellcanada.py')
# abs_path = os.path.abspath('./config/uunet_htc.py')
Config = imp.load_source('SimConfig', abs_path)


# Third-party modules
# User-defined modules
from sim.SimCore import *
import SimConfig as Config


if __name__ == '__main__':
    mySim = SimCore()
    mySim.main_course()
