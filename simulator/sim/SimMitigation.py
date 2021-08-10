#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimMitigation.py:
"""

# Built-in modules
from time import *
import sys
from heapq import heappush, heappop
import math
import json

# Third-party modules
import networkx as nx
import netaddr as na
# User-defined modules
import SimConfig as Config
from .SimEvent import *
from .SimLogger import *


class SimMitigation:
    """
    """
    def __init__(self):
        print('init SimMitigation')

    def get_least_utilized_path(self, all_path):
        max_avail_bw = float('-inf')
        max_path = None
        for path in all_path:
            this_avail_bw = self.get_bottleneck_link_avail_bw(path)
            if max_avail_bw < this_avail_bw:
                max_avail_bw = this_avail_bw
                max_path = path
        assert max_path != None
        return max_path

    # get minimum avaiable bandwidth in the path, use to check feasibility for rerouting
    def get_bottleneck_link_avail_bw(self, path):
        bottleneck_bw = float('inf')
        for i in range(len(path) - 1):
            src = path[i]
            dst = path[i+1]
            linkobj = self.linkobjs[(str(src), str(dst))]
            if linkobj.unasgn_bw < bottleneck_bw:
                bottleneck_bw = linkobj.unasgn_bw

        return bottleneck_bw


    # This function is slow, can use ripple_crossfire_reroute_sol as the substition.
    def ripple_crossfire_reroute(self, ev_time):
        if self.has_rerouted == True:
            return

        # Set the mark to enable recomputing
        self.need_update = True

        finished_count = 0
        for ip in self.suspflows_crossfire:
            finished_count += 1
            if finished_count % 10 == 0:
                percentage = finished_count * 100.0 / len(self.suspflows_crossfire)
                sys.stdout.write("Sim Time: %-3.2fs (reroute: %-3.2f%%)    " %(self.timer, percentage)   + \
                                    "Exec Time: %-5.3f seconds    "    %(time()-self.exec_st_time) + \
                                    "#Flows:%-4d\r\n"                  %(len(self.flows))
                                )
                sys.stdout.flush()

            # print(self.hostobjs.keys())
            src_hostobj = self.hostobjs[na.IPAddress(ip)]
            n_flows     = src_hostobj.n_flows
            flow_rate   = src_hostobj.flow_rate
            src_ip      = src_hostobj.flow_srcip
            dst_ip      = src_hostobj.flow_dstip
            srcsw       = src_hostobj.flow_srcsw
            dstsw       = src_hostobj.flow_dstsw

            # find k path for rerouting
            all_path = self.build_pathdb_kpath_yen(srcsw, dstsw)
            current_path = self.tcobjs[src_hostobj.tc].path

            least_utilized_path = self.get_least_utilized_path(all_path)
            bottlenecked_bw = self.get_bottleneck_link_avail_bw(least_utilized_path)

            # stop rerouting if the target link is not congested anymore
            if self.get_bottleneck_link_avail_bw(current_path) > 100000:
                return

            SimLogger.DEBUG('Computing rerouting for '+str(ip))
            if least_utilized_path == current_path:
                SimLogger.DEBUG('reroute to the same path')
                continue

            # if after rerouting the current path has lower utilization, then we don't reroute
            current_available = self.get_bottleneck_link_avail_bw(current_path)
            SimLogger.DEBUG('current_available = '+str(current_available))
            SimLogger.DEBUG('bottlenecked_bw = '+str(bottlenecked_bw))

            if current_available + n_flows*flow_rate >= bottlenecked_bw:
                SimLogger.DEBUG('reroute to the same path')
                continue

            if bottlenecked_bw < n_flows*flow_rate:
                SimLogger.DEBUG('required bw is '+str(n_flows*flow_rate)+', but avaliable bw is '+str(bottlenecked_bw))
                SimLogger.ERROR('Cannot reroute')
                exit(1)

            rerouted_flowobjs = self.get_flows_host(src_ip)
            for flowobj in rerouted_flowobjs:
                flow_sip = flowobj.src_ip
                flow_dip = flowobj.dst_ip
                flow_sport = flowobj.src_port
                flow_dport = flowobj.dst_port

                # Decrement/increment active flow counters at sim core and links
                for lk in flowobj.links:
                    self.linkobjs[lk].n_active_flows -= 1
                # Remove flow entry from switches along path
                for nd in flowobj.path:
                    self.switchobjs[nd].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)
                # Remove flow entry from links along path
                for lk in flowobj.links:
                    self.linkobjs[lk].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)

                # Register entries at SimSwitch & SimLink instances
                list_links = self.get_links_on_path(least_utilized_path)
                self.install_flow_to_path(least_utilized_path, list_links, flow_sip, flow_dip, flow_sport, flow_dport)
                # Update the installed flow's states to 'active'
                flowobj.install_flow(ev_time, least_utilized_path, list_links)
                # Decrement/increment active flow counters at sim core and links
                for lk in list_links:
                    self.linkobjs[lk].n_active_flows += 1

            # Recalculate flow rates
            self.need_update = True
            self.calc_flow_rates_min_max(ev_time)
        self.has_rerouted = True

    # Using SOL's solution to reduce simulation time
    def ripple_crossfire_reroute_sol(self, ev_time):
        if self.has_rerouted == True:
            return

        # Set the mark to enable recomputing
        self.need_update = True

        rolling = -1
        if Config.ROLLING != 1:
            if self.congested_links[0] == self.targetlinks['link0']:
                rolling = 1
            elif self.congested_links[0] == self.targetlinks['link1']:
                rolling = 2
        else:
            if Config.MULTI_IP == 0:
                rolling = (self.rolling_current % 2) + 1
            else:
                rounds = int((ev_time - Config.ATTACK_START)/(Config.ATTACK_PERIOD + Config.ROLLING_GAP))
                if rounds % 2 == 0:
                    rolling = 1
                else:
                    rolling = 2
                if rolling == self.last_roll:
                    self.clean_state()
                    self.need_update = False
                    return
                else:
                    self.last_roll = rolling

        if Config.HAS_CLASSIFICATION == 1:
            if Config.SAMPLED_CLASSIFICATION == 1:
                solution_path = Config.REROUTE1_SAMCLASS if rolling == 1 else Config.REROUTE2_SAMCLASS
            else:
                solution_path = Config.REROUTE1 if rolling == 1 else Config.REROUTE2
        else:
            solution_path = Config.REROUTE1_NOCLASS if rolling == 1 else Config.REROUTE2_NOCLASS

        # read path from json
        with open(solution_path) as f:
            json_dict = json.load(f)

        tcs = json_dict['tcs'] # traffic class
        for tc in sorted(tcs.keys()):
            name        = str(tc)
            src         = tcs[tc]['src']
            dst         = tcs[tc]['dst']
            npath       = tcs[tc]['npath']

            flowobjs_this_tc = self.get_flows_by_tc(name)
            nflows_this_tc = len(flowobjs_this_tc)

            if nflows_this_tc == 0:
                print('tc = ', tc)
            assert nflows_this_tc != 0

            paths = tcs[tc]['paths']
            # print(paths)
            flow_indx = 0
            for item in sorted(paths.keys()):
                path = paths[item]['hops']
                frac = float(paths[item]['flowFraction'])

                for i in range(flow_indx, min(int(flow_indx+nflows_this_tc*frac), nflows_this_tc)):
                    flowobj     = flowobjs_this_tc[i]
                    flow_sip    = flowobj.src_ip
                    flow_dip    = flowobj.dst_ip
                    flow_sport  = flowobj.src_port
                    flow_dport  = flowobj.dst_port

                    assert flowobj.src_node.flow_srcsw == src and flowobj.dst_node.flow_dstsw == dst and flowobj.tc == name

                    # Decrement/increment active flow counters at sim core and links
                    for lk in flowobj.links:
                        self.linkobjs[lk].n_active_flows -= 1
                    # Remove flow entry from switches along path
                    for nd in flowobj.path:
                        self.switchobjs[nd].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)
                    # Remove flow entry from links along path
                    for lk in flowobj.links:
                        self.linkobjs[lk].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)

                    # Register entries at SimSwitch & SimLink instances
                    list_links = self.get_links_on_path(path)
                    self.install_flow_to_path(path, list_links, flow_sip, flow_dip, flow_sport, flow_dport)
                    # Update the installed flow's states to 'active'
                    flowobj.install_flow(ev_time, path, list_links)
                    # Decrement/increment active flow counters at sim core and links
                    for lk in list_links:
                        self.linkobjs[lk].n_active_flows += 1

                # update flow index
                flow_indx = flow_indx+int(nflows_this_tc*frac)

        self.has_rerouted = True
        # Recalculate flow rates
        self.need_update = True
        self.calc_flow_rates_min_max(ev_time)
        flows = self.linkobjs[self.congested_links[0]].flows
        nmal = nnorm = 0
        for key in flows:
            flowobj = flows[key]
            if flowobj.is_mal:
                nmal += 1
            else:
                nnorm += 1

        if Config.ROLLING == 1:
            self.clean_state()
            self.rolling_current += 1

    def sdn_crossfire_reroute_sol(self, ev_time):
        if self.has_rerouted == True:
            return

        # Set the mark to enable recomputing
        self.need_update = True

        rolling = -1
        if Config.ROLLING != 1:
            if self.congested_links[0] == self.targetlinks['link0']:
                rolling = 1
            elif self.congested_links[0] == self.targetlinks['link1']:
                rolling = 2

        if Config.ROLLING == 1:
            if Config.MULTI_IP == 0:
                rolling = (self.rolling_current % 2) + 1
            else:
                # rolling = 1
                rounds = int((ev_time - Config.SOL_TIME_DPCLASS - Config.ATTACK_START)/(Config.ATTACK_PERIOD + Config.ROLLING_GAP))
                if rounds % 2 == 0:
                    rolling = 1
                else:
                    rolling = 2
                print(ev_time, rolling)
                if rolling == self.last_roll:
                    # self.clean_state()
                    # self.need_update = False
                    return
                else:
                    self.last_roll = rolling

        # solution_path = Config.REROUTE1 if rolling == 1 else Config.REROUTE2
        if Config.HAS_CLASSIFICATION == 1:
            if Config.SAMPLED_CLASSIFICATION == 1:
                solution_path = Config.REROUTE1_SAMCLASS if rolling == 1 else Config.REROUTE2_SAMCLASS
            else:
                solution_path = Config.REROUTE1 if rolling == 1 else Config.REROUTE2
        else:
            solution_path = Config.REROUTE1_NOCLASS if rolling == 1 else Config.REROUTE2_NOCLASS
        # SimLogger.CRITICAL('Solution path is '+solution_path)

        # read path from json
        with open(solution_path) as f:
            json_dict = json.load(f)

        tcs = json_dict['tcs'] # traffic class
        for tc in sorted(tcs.keys()):
            name        = str(tc)
            src         = tcs[tc]['src']
            dst         = tcs[tc]['dst']
            npath       = tcs[tc]['npath']

            flowobjs_this_tc = self.get_flows_by_tc(name)
            nflows_this_tc = len(flowobjs_this_tc)

            paths = tcs[tc]['paths']
            # print(paths)
            flow_indx = 0
            for item in sorted(paths.keys()):
                path = paths[item]['hops']
                frac = float(paths[item]['flowFraction'])
                # SimLogger.CRITICAL("name=%s, src=%s, dst=%s, frac=%f, path=%s" %(name, src, dst, frac, path))

                for i in range(flow_indx, min(int(flow_indx+nflows_this_tc*frac), nflows_this_tc)):
                    flowobj     = flowobjs_this_tc[i]
                    flow_sip    = flowobj.src_ip
                    flow_dip    = flowobj.dst_ip
                    flow_sport  = flowobj.src_port
                    flow_dport  = flowobj.dst_port

                    assert flowobj.src_node.flow_srcsw == src and flowobj.dst_node.flow_dstsw == dst and flowobj.tc == name

                    # Decrement/increment active flow counters at sim core and links
                    for lk in flowobj.links:
                        self.linkobjs[lk].n_active_flows -= 1
                    # Remove flow entry from switches along path
                    for nd in flowobj.path:
                        self.switchobjs[nd].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)
                    # Remove flow entry from links along path
                    for lk in flowobj.links:
                        self.linkobjs[lk].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)

                    # Register entries at SimSwitch & SimLink instances
                    list_links = self.get_links_on_path(path)
                    self.install_flow_to_path(path, list_links, flow_sip, flow_dip, flow_sport, flow_dport)
                    # Update the installed flow's states to 'active'
                    flowobj.install_flow(ev_time, path, list_links)
                    # Decrement/increment active flow counters at sim core and links
                    for lk in list_links:
                        self.linkobjs[lk].n_active_flows += 1


                # update flow index
                flow_indx = flow_indx+int(nflows_this_tc*frac)
        self.has_rerouted = True
        # Recalculate flow rates
        self.need_update = True
        self.calc_flow_rates_min_max(ev_time)
        if Config.ROLLING == 1:
            self.clean_state()
            self.rolling_current += 1


    def sdn_crossfire_reroute_native(self, ev_time):
        if self.has_rerouted == True:
            return

        # Set the mark to enable recomputing
        self.need_update = True

        # For each ip in suspflow, find another route
        for ip in self.suspflows_crossfire:
            # print(self.hostobjs.keys())
            src_hostobj = self.hostobjs[na.IPAddress(ip)]
            n_flows     = src_hostobj.n_flows
            flow_rate   = src_hostobj.flow_rate
            src_ip      = src_hostobj.flow_srcip
            dst_ip      = src_hostobj.flow_dstip
            srcsw       = src_hostobj.flow_srcsw
            dstsw       = src_hostobj.flow_dstsw

            # find k path for rerouting
            all_path = self.build_pathdb_kpath_yen(srcsw, dstsw)
            current_path = self.tcobjs[src_hostobj.tc].path


            least_utilized_path = self.get_least_utilized_path(all_path)
            bottlenecked_bw = self.get_bottleneck_link_avail_bw(least_utilized_path)

            if least_utilized_path == current_path:
                SimLogger.DEBUG('reroute to the same path')
                continue

            # if after rerouting the current path has lower utilization, then we don't reroute
            current_available = self.get_bottleneck_link_avail_bw(current_path)
            if current_available + n_flows*flow_rate >= bottlenecked_bw:
                SimLogger.DEBUG('reroute to the same path')
                continue

            if bottlenecked_bw < n_flows*flow_rate:
                SimLogger.ERROR('Cannot reroute')
                exit(1)

            rerouted_flowobjs = self.get_flows_host(src_ip)
            for flowobj in rerouted_flowobjs:
                flow_sip = flowobj.src_ip
                flow_dip = flowobj.dst_ip
                flow_sport = flowobj.src_port
                flow_dport = flowobj.dst_port

                # Decrement/increment active flow counters at sim core and links
                for lk in flowobj.links:
                    self.linkobjs[lk].n_active_flows -= 1
                # Remove flow entry from switches along path
                for nd in flowobj.path:
                    self.switchobjs[nd].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)
                # Remove flow entry from links along path
                for lk in flowobj.links:
                    self.linkobjs[lk].remove_flow(flow_sip, flow_dip, flow_sport, flow_dport)

                # Register entries at SimSwitch & SimLink instances
                list_links = self.get_links_on_path(least_utilized_path)
                self.install_flow_to_path(least_utilized_path, list_links, flow_sip, flow_dip, flow_sport, flow_dport)
                # Update the installed flow's states to 'active'
                flowobj.install_flow(ev_time, least_utilized_path, list_links)
                # Decrement/increment active flow counters at sim core and links
                for lk in list_links:
                    self.linkobjs[lk].n_active_flows += 1

                # Recalculate flow rates
                self.need_update = True
                self.calc_flow_rates_min_max(ev_time)
        self.has_rerouted = True

