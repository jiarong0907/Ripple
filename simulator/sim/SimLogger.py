#!/usr/bin/python
# -*- coding: utf-8 -*-

"""sim/SimLogger.py: A helper class for printing info
"""

# Built-in modules
# Third-party modules
# User-defined modules
import SimConfig as Config


class SimLogger:
    """
        DEBUG       = 4
        INFO        = 3
        CRITICAL    = 2
        ERROR       = 1

    """

    @classmethod
    def DEBUG(self, message):
        if Config.LOG_LEVEL >= 4:
            print(message)

    @classmethod
    def INFO(self, message):
        if Config.LOG_LEVEL >= 3:
            print(message)

    @classmethod
    def CRITICAL(self, message):
        if Config.LOG_LEVEL >= 2:
            print(message)

    @classmethod
    def ERROR(self, message):
        if Config.LOG_LEVEL >= 1:
            print(message)
