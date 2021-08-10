#!/usr/bin/python
# -*- coding: utf-8 -*-

"""sim/SimHost.py: Class of host profile including IP addr, malicious state, number of flows, etc.
"""

# Built-in modules
# Third-party modules
import netaddr as na
# User-defined modules
import SimConfig as cfg


class SimHost:
    def __init__(self, **kwargs):
        self.name = kwargs.get('name', 'none')
        self.ip = kwargs.get('ip', na.IPAddress(0))
        self.is_mal = kwargs.get('is_mal', False) # mal or norm
        self.rolling = kwargs.get('rolling', -1)
        self.n_flows = kwargs.get('n_flows', 0)
        self.flow_rate = kwargs.get('flow_rate', 0)
        self.flow_srcip = kwargs.get('flow_srcip', 0)
        self.flow_dstip = kwargs.get('flow_dstip', 0)
        self.flow_srcsw = kwargs.get('flow_srcsw', 0)
        self.flow_dstsw = kwargs.get('flow_dstsw', 0)
        self.host_type = kwargs.get('host_type', 'none')
        self.tc = kwargs.get('tc', 'none')
        self.attack_type = kwargs.get('attack_type', 'none')


    def __str__(self):
        ret =   'Host name %s\n'                    %(self.name) + \
                '\tIP address: %s\n'                %(self.ip) + \
                '\tis_mal: %s\n'                    %(self.is_mal) + \
                '\trolling: %d\n'                   %(self.rolling) + \
                '\tn_flows: %s\n'                   %(self.n_flows) + \
                '\tflow_srcip: %s\n'                %(self.flow_srcip) + \
                '\tflow_dstip: %s\n'                %(self.flow_dstip) + \
                '\tflow_srcsw: %s\n'                %(self.flow_srcsw) + \
                '\tflow_dstsw: %s\n'                %(self.flow_dstsw) + \
                '\tflow_rate: %s\n'                 %(self.flow_rate) + \
                '\thost_type: %s\n'                 %(self.host_type) + \
                '\ttc: %s\n'                        %(self.tc) + \
                '\tattack_type: %s\n'               %(self.attack_type)

        return ret