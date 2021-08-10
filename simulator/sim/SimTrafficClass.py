#!/usr/bin/python
# -*- coding: utf-8 -*-

"""sim/SimTrafficClass.py: Class of traffic class. This is created according to the attack.json.
"""

# Built-in modules
# Third-party modules
import netaddr as na
# User-defined modules
import SimConfig as cfg


class SimTrafficClass:

    def __init__(self, **kwargs):
        self.name = kwargs.get('name', 'none')
        self.rolling = kwargs.get('rolling', -1)
        self.src = kwargs.get('src', 0)
        self.dst = kwargs.get('dst', 0)
        self.flow_rate = kwargs.get('flow_rate', 0)
        self.path = kwargs.get('path', 0)
        self.is_mal = kwargs.get('is_mal', 0)


    def __str__(self):
        ret =   'Traffic class name %s\n'           %(self.name) + \
                '\trolling: %d\n'                   %(self.rolling) + \
                '\tsrc: %s\n'                       %(self.src) + \
                '\tdst: %s\n'                       %(self.dst) + \
                '\tflow_rate: %s\n'                 %(self.flow_rate) + \
                '\tpath: %s\n'                      %(self.path) + \
                '\tis_mal: %s\n'                    %(self.is_mal)

        return ret