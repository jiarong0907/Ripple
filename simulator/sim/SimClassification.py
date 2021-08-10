#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimClassification.py:
"""

# Built-in modules
from time import *
import sys
from heapq import heappush, heappop
import random

# Third-party modules
import networkx as nx
# User-defined modules
import SimConfig as Config
from .SimEvent import *
from .SimLogger import *


class SimClassification:
    """
    """
    def __init__(self):
        print('init SimClassification')

    def classify_crossfire(self, ev_time):
        if self.has_classified_crossfire == True:
            return

        global_mal_srcip = []
        # each switch classify traffic and generate its local suspflows
        for sw in self.switches:
            malicious_srcip  = []
            small_flow_count = dict()

            for lk in self.linkobjs:
                linkobj = self.linkobjs[lk]
                # check on links that start from this switch
                if str(linkobj.node1) != str(sw):
                    continue
                # check every flow
                for fl in linkobj.flows:
                    assert (Config.SAMPLED_CLASSIFICATION == 0 or Config.SAMPLED_CLASSIFICATION == 1)
                    flow = linkobj.flows[fl]
                    # work in sampled mode
                    if Config.SAMPLED_CLASSIFICATION == 1:
                        assert (Config.SYSTEM_TYPE == 'SDN')
                        # sampled part of flows
                        if str(flow.src_node.ip) not in self.sampled_sip:
                            continue
                    # only care about small flows
                    if flow.curr_rate > Config.CROSSFIRE_RATE_THRESH:
                        continue
                    if str(flow.src_node.ip) not in small_flow_count:
                        small_flow_count[str(flow.src_node.ip)] = 1
                    else:
                        small_flow_count[str(flow.src_node.ip)] += 1

            for key in small_flow_count.keys():
                if small_flow_count[key] > Config.CROSSFIRE_NFLOW_THRESH:
                    malicious_srcip.append(key)

            for item in malicious_srcip:
                if item not in global_mal_srcip:
                    global_mal_srcip.append(item)

        sync_ev_time = ev_time + Config.PERIOD_ClASS + Config.SYNC_PERIOD / 2.0 + self.sync_delay
        # Schedule a suspflow synchronization event
        heappush(self.ev_queue, (sync_ev_time, EvSyncSuspflows(ev_time=sync_ev_time,\
                                                                   suspflows=global_mal_srcip,\
                                                                   susp_type='CROSSFIRE')))
        self.has_classified_crossfire = True