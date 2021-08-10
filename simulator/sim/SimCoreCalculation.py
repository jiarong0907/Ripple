#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimCoreCalculation.py: Class SimCoreCalculation, containing flow rate recalculation functions.
Inherited by SimCore.
"""

# Built-in modules
import math
import sys
from time import *
# Third-party modules
# User-defined modules
import SimConfig as Config
from .SimLogger import *

class SimCoreCalculation:
    """Flow rate calculation-related codes for SimCore class.
    """
    def __init__(self):
        """
        """

    def update_all_flows(self, ev_time):
        """
        """
        for fl in self.flows:
            flowobj = self.flows[fl]
            bytes_recent = flowobj.update_flow(ev_time)

            if (flowobj.status == 'active'):
                for lk in flowobj.links:
                    # Update link byte counters
                    self.link_byte_cnt[lk]  += bytes_recent


    def update_link_util(self):
        for key in self.linkobjs:
            linkobj = self.linkobjs[key]
            linkobj.unasgn_bw = linkobj.cap
            for fl in linkobj.flows:
                flow = linkobj.flows[fl]
                if flow.status != 'active':
                    continue
                self.linkobjs[key].unasgn_bw -= flow.curr_rate

    def calc_fr_minmax_crossfire(self, ev_time):
        for key in self.flows:
            self.flows[key].curr_rate = float('inf')

        for lk in self.links:
            linkobj                 = self.linkobjs[lk]
            linkobj.unasgn_bw       = linkobj.cap
            linkobj.n_active_flows  = linkobj.get_n_active_flows()
            linkobj.n_unasgn_flows  = linkobj.n_active_flows

            if (linkobj.n_unasgn_flows > 0):
                linkobj.bw_per_flow     = linkobj.unasgn_bw / float(linkobj.n_unasgn_flows)
                sorted_flows = []
                for key in linkobj.flows:
                    flow = linkobj.flows[key]
                    flow.assigned = False
                    sorted_flows.append(flow)

                sorted_flows.sort(cmp=None, key=lambda x:min(float(x.flow_rate), float(x.curr_rate)), reverse=False)
                for i in range(len(sorted_flows)):
                    flow = sorted_flows[i]
                    if flow.status != 'active' or flow.assigned == True:
                        continue

                    if flow.flow_rate < linkobj.bw_per_flow or flow.curr_rate < linkobj.bw_per_flow: # source constrained
                        flow.assign_bw(ev_time, min(flow.flow_rate, flow.curr_rate))
                        linkobj.unasgn_bw -= min(flow.flow_rate, flow.curr_rate)
                        linkobj.n_unasgn_flows -= 1
                        flow.assigned = True
                        if linkobj.n_unasgn_flows == 0:
                            break
                        linkobj.bw_per_flow = linkobj.unasgn_bw / float(linkobj.n_unasgn_flows)
                        continue

                    flow.assign_bw(ev_time, linkobj.bw_per_flow)
                    linkobj.unasgn_bw -= linkobj.bw_per_flow
                    linkobj.n_unasgn_flows -= 1
                    flow.assigned = True

        # update link utilization
        self.update_link_util()

    def calc_flow_rates_min_max(self, ev_time):
        if self.need_update == False:
            return

        SimLogger.INFO('Computing the flow rate...')

        if Config.ATTACK_TYPE == 'CROSSFIRE':
            self.calc_fr_minmax_crossfire(ev_time)
        else:
            print('calc_flow_rates_min_max: Unidentified attack type')
            exit(1)

        # after computing reset it to False
        self.need_update = False