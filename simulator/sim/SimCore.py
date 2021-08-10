#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimCore.py: Class SimCore, the core class of FlowSim simulator.
"""


# Built-in modules
import os
import csv
import sys
import json
from heapq import heappush, heappop
from math import ceil, log
from time import time
import random
import logging
# Third-party modules
import networkx as nx
import netaddr as na

# User-defined modules
import SimConfig as Config
from .SimFlow import *
from .SimSwitch import *
from .SimLink import *
from .SimHost import *
from .SimTrafficClass import *
from .SimPathDB import *
from .SimCoreEventHandling import *
from .SimCoreLogging import *
from .SimCoreCalculation import *
from .SimClassification import *
from .SimMitigation import *


class SimCore(SimCoreCalculation, SimCoreEventHandling, SimCoreLogging, \
              SimPathDB, SimClassification, SimMitigation):
    """Core class of FlowSim simulator.

    Attributes:
        sim_time (float64): Total simulation time
        timer (float64): Simulation timer, which keeps current time progress
        topo (networkx.Graph): An undirected graph to keep network topology
        ev_queue (list of 2-tuples): Event queue. Each element is a 2-tuple of (ev_time, event obj)
    """

    def __init__(self):
        """Constructor of SimCore class.
        """
        # ---- Simulator timer and counters ---- #
        self.sim_time = Config.SIM_TIME
        sys.setrecursionlimit(1000000) # to avoid RuntimeError: maximum recursion depth exceeded
        self.rolling_current = 0
        self.timer = 0.0
        self.base_ip = na.IPAddress('10.0.0.0')
        self.src_port = 0
        self.dst_port = 0
        self.last_roll = 0
        self.is_attacked = False
        self.has_rerouted = False
        self.has_dropped = False
        # We use this to track whether we need to recompute the flow rate
        # It can help us save a lot of computation time
        # Three cases we need to recompute the flow rate, new flow comes, new flow ends, mitigation takes effect
        self.need_update = False
        self.has_classified_crossfire = False
        self.congested_links = []
        self.suspflows_crossfire = []
        self.ev_queue = []
        self.n_flow_event = 0 # the number of flow related even, the sim will stop when it is zero
        random.seed(int(time()))

        # ---- Parse CSV and set up topology graph's nodes and edges accordingly ---- #
        self.topo = nx.read_gml(Config.TOPO)
        self.switches = []
        self.links = []
        self.switchobjs = {}
        self.tcobjs = {} # trafic class (tc)
        self.linkobjs = {}
        self.link_mapper = {}
        self.build_topo()

        self.path_db = {}
        self.setup_path_db()

        self.sync_delay = 1.0
        self.calc_sync_delay()

        # ---- Create hosts, assign edge switches * IPs ---- #
        self.hostobjs = {}
        self.targetlinks = {}
        self.create_hosts()
        # self.print_all_hosts()
        # self.display_topo_details()

        # # ---- Keeping flow records ---- #
        self.flows = {}
        self.sampled_sip = []
        self.has_sampled = False

        # # ---- Constructor of base classes ---- #
        SimCoreLogging.__init__(self)
        SimCoreCalculation.__init__(self)

    def display_topo(self):
        """Display topology (nodes and links only)

        Args:
            None

        """
        print('Nodes:', self.switches)
        print()
        print('Links:', self.links)


    def display_topo_details(self):
        """Display topology - nodes and links along with parameters

        Args:
            None

        """
        self.print_all_switches()
        self.print_all_edges()
        self.print_all_hosts()

    def print_all_flows_per_switch(self):
        print('='*80)
        print('Flow summary per switch')
        for sw in self.switches:
            print('switch '+str(sw)+' has '+ str(self.switchobjs[sw].n_hosts)+' hosts')
            for ht in self.hostobjs:
                hostobj = self.hostobjs[ht]
                if hostobj.flow_srcsw == str(sw) and hostobj.host_type == 'send' :
                    print('host '+str(hostobj.name)+' has '+str(hostobj.n_flows)+\
                        ' flows, sending rate = '+str(hostobj.flow_rate))
            print()
        print('='*80)

    def print_all_switches(self):
        for sw in self.switches:
            print(self.switchobjs[sw])

    def print_all_edges(self):
        for lk in self.links:
            print(self.linkobjs[lk])

    def print_all_hosts(self):
        for key in self.hostobjs:
            print(self.hostobjs[key])

    def calc_sync_delay(self):
        SimLogger.INFO('='*80)
        SimLogger.INFO("Computing synchronization delay...")

        # get shortest paths for all src, dst pair
        shortest_path = {}
        for key in self.path_db:
            if key not in shortest_path.keys():
                shortest_path[key] = self.path_db[key]
            else:
                if len(shortest_path[key]) > len(self.path_db[key]):
                    shortest_path[key] = self.path_db[key]

        # get the longest shortest path
        longest_path_hop = 0
        sumlen = 0
        for key in shortest_path:
            sumlen += len(shortest_path[key])
            if len(shortest_path[key]) > longest_path_hop:
                longest_path_hop = len(shortest_path[key])


        SimLogger.INFO('longest_path_hop='+str(longest_path_hop))
        SimLogger.INFO('avg_path_hop='+str(sumlen/float(len(shortest_path))))
        if Config.SYSTEM_TYPE == 'RIPPLE':
            # We assume the worst scenario, the root locates int one edge of the longest path
            # This is one direction delay
            self.sync_delay = longest_path_hop * Config.LINK_DELAY
        elif Config.SYSTEM_TYPE == 'SDN':
            # Use the same assumption with RIPPLE
            # We assume the controller has two more hops
            self.sync_delay = (longest_path_hop + 3) * Config.LINK_DELAY
        else:
            SimLogger.ERROR('ERROR: Cannot identify the system type:'+str(Config.SYSTEM_TYPE)+'. Exiting...')
            exit(1)

        SimLogger.INFO('self.sync_delay='+str(self.sync_delay))
        SimLogger.INFO("Finish computing synchronization delay...")

    def build_topo(self):
        print('='*80)
        print("Reading *.gml and converting it to networkx object")

        self.switches = self.topo.nodes()
        self.links = self.topo.edges()
        # make the link bidirectional
        new_links = []
        for lk in self.links:
            new_links.append(lk)
            new_links.append((lk[1], lk[0]))
        self.links = new_links

        for sw in self.switches:
            tmpdict = {}
            tmpdict['name'] = str(sw)
            self.switchobjs[tmpdict['name']] = SimSwitch(**tmpdict)

        for lk in self.links:
            tmpdict = {}
            tmpdict['node1'] = str(lk[0])
            tmpdict['node2'] = str(lk[1])
            self.linkobjs[(tmpdict['node1'], tmpdict['node2'])] = SimLink(**tmpdict)

        for lk in self.links:
            self.link_mapper[lk] = lk

        print("Finish reading *.gml and converting it to networkx object")


    def get_links_on_path(self, path):
        """Get a list of links along the specified path.

        Args:
            path (list of strings): List of node names along the path

        Returns:
            list of 2-tuples: List of links along the path, each represented by
                              a 2-tuple of node names.

        """
        ret = []

        for i in range(len(path)-1):
            ret.append(self.link_mapper[(path[i], path[i+1])])

        return ret


    def install_flow_to_path(self, path, links, src_ip, dst_ip, src_port, dst_port):
        """Install flow entries to the specified path.

        Args:
            path (list of str): Path
            links (list of 2-tuples): Links along the path
            src_ip (netaddr.IPAddress)
            dst_ip (netaddr.IPAddress)

        Returns:
            None

        """
        for nd in path:
            self.switchobjs[nd].install_flow(src_ip, dst_ip, src_port, dst_port)

        #for lk in self.get_links_on_path(path):
        for lk in links:
            flowobj = self.flows[(src_ip, dst_ip, src_port, dst_port)]
            self.linkobjs[lk].install_flow(src_ip, dst_ip, src_port, dst_port, flowobj)

    def initIPAddr(self, src, dst):
        src_nhost = self.switchobjs[src].n_hosts
        if src_nhost == 0:
            self.switchobjs[src].base_ip = self.base_ip
            self.switchobjs[src].end_ip = self.base_ip + Config.IP_SEGMENT - 1
            self.base_ip = self.base_ip + Config.IP_SEGMENT

        dst_nhost = self.switchobjs[dst].n_hosts
        if dst_nhost == 0:
            self.switchobjs[dst].base_ip = self.base_ip
            self.switchobjs[dst].end_ip = self.base_ip + Config.IP_SEGMENT - 1
            self.base_ip = self.base_ip + Config.IP_SEGMENT

    def create_certain_host(self, tc_name, src, dst, src_ip, dst_ip, is_mal, n_flows, rolling, flow_rate, attack_type):
        src_nhost = self.switchobjs[src].n_hosts
        dst_nhost = self.switchobjs[dst].n_hosts

        # self.nhost_tmp += 1

        params = {'name':'host_'+src+"_"+str(src_nhost), 'ip':src_ip, 'is_mal':is_mal, 'n_flows':n_flows, \
                        'rolling':rolling, 'flow_rate':flow_rate, 'flow_srcip':src_ip, \
                        'flow_dstip':dst_ip, 'flow_srcsw':src, 'flow_dstsw':dst, \
                        'host_type':'send', 'tc':tc_name, 'attack_type':attack_type}
        if src_ip in self.hostobjs.keys():
            print('collision')
            print(self.hostobjs[src_ip])
            exit(0)

        self.hostobjs[src_ip] = SimHost(**params)
        # self.nfow_tmp += self.hostobjs[src_ip].n_flows
        params = {'name':'host_'+dst+"_"+str(dst_nhost), 'ip':dst_ip, 'is_mal':is_mal, 'n_flows':n_flows, \
                        'rolling':rolling, 'flow_rate':flow_rate, 'flow_srcip':src_ip, \
                        'flow_dstip':dst_ip, 'flow_srcsw':src, 'flow_dstsw':dst, \
                        'host_type':'recv', 'tc':tc_name, 'attack_type':attack_type}
        self.hostobjs[dst_ip] = SimHost(**params)

    def create_hosts_nomral(self, tc_name, src, dst, fr, rolling):
        # setup host ip
        self.initIPAddr(src, dst)
        this_nhost = math.ceil(fr/float(Config.NORM_FLOW_RATE))
        # create host one by one
        for i in range(int(this_nhost)):
            self.switchobjs[src].n_hosts += 1
            self.switchobjs[dst].n_hosts += 1
            src_ip = self.switchobjs[src].base_ip + self.switchobjs[src].n_hosts
            dst_ip = self.switchobjs[dst].base_ip + self.switchobjs[dst].n_hosts
            self.create_certain_host(tc_name, src, dst, src_ip, dst_ip, False, 1, rolling, \
                            Config.NORM_FLOW_RATE, 'NORMAL')

    def create_hosts_crossfire(self, tc_name, src, dst, fr, rolling):
        # setup host ip
        self.initIPAddr(src, dst)
        this_nhost = math.ceil(fr/float(Config.CROSSFIRE_RATE*Config.CROSSFIRE_FLOW_PER_HOST))
        # create host one by one
        for i in range(int(this_nhost)):
            self.switchobjs[src].n_hosts += 1
            self.switchobjs[dst].n_hosts += 1
            src_ip = self.switchobjs[src].base_ip + self.switchobjs[src].n_hosts
            dst_ip = self.switchobjs[dst].base_ip + self.switchobjs[dst].n_hosts
            self.create_certain_host(tc_name, src, dst, src_ip, dst_ip, True, Config.CROSSFIRE_FLOW_PER_HOST, \
                                    rolling, Config.CROSSFIRE_RATE, 'CROSSFIRE')

    def create_hosts(self):
        """Create hosts, bind hosts to edge switches, and assign IPs.
        """
        print('='*80)
        print("Creating hosts according the attack configuration")

        # read path from json
        with open(Config.ATTACK) as f:
            json_dict = json.load(f)

        links = json_dict['target_link'] # target links
        for link in sorted(links.keys()):
            name        = str(link)
            src         = links[link]['src']
            dst         = links[link]['dst']
            self.targetlinks[name] = (src, dst)

        print('Target links are ')
        print(self.targetlinks)

        classes = json_dict['traffic_class']
        for tc in sorted(classes.keys()):
            name        = str(tc)
            src         = classes[tc]['src']
            dst         = classes[tc]['dst']
            mal         = classes[tc]['malicious']
            fr          = classes[tc]['flow_rate']
            rolling     = classes[tc]['rolling']
            path        = classes[tc]['hops']

            # create tc object
            params = {'name':name, 'rolling':rolling, 'src':src, 'dst':dst, 'flow_rate':fr, 'path':path, \
                        'is_mal':mal}
            self.tcobjs[name] = SimTrafficClass(**params)

            # create normal flow
            if bool(mal) == False:
                self.create_hosts_nomral(name, src, dst, fr, rolling)
            elif bool(mal) == True:
                if Config.ATTACK_TYPE == 'CROSSFIRE':
                    self.create_hosts_crossfire(name, src, dst, fr, rolling)
            else:
                print('Wrong malicious type in json')
                exit(1)
        print("Finish creating hosts according the attack configuration")

    def get_flows_host(self, hostip):
        """
        get all flows of a certain host
        """
        flowobjs = []
        for fl in self.flows:
            if self.flows[fl].src_ip == hostip:
                flowobjs.append(self.flows[fl])
        return flowobjs

    def get_flows_by_tc(self, tc_name):
        """
        get all flows of a certain tc
        """
        flowobjs = []
        for fl in self.flows:
            if self.flows[fl].tc == tc_name:
                flowobjs.append(self.flows[fl])
        return flowobjs

    def get_host_rate(self, hostip):
        """
        get sending rate of a certain host
        """
        rate_sum = 0
        for fl in self.flows:
            if self.flows[fl].src_ip == hostip:
                rate_sum += self.flows[fl].curr_rate
        return rate_sum

    def get_all_send_host(self):
        """
        get all sender host

        Returns:
            A list of sender hostobj
        """
        send_host = []
        for ht in self.hostobjs:
            hostobj = self.hostobjs[ht]
            if hostobj.host_type == 'send':
                send_host.append(hostobj)
        return send_host


    def get_active_flows_ip(self):
        ret_active_flows = []
        for fl in self.flows:
            flowobj = self.flows[fl]
            if str(flowobj.src_ip) not in ret_active_flows and flowobj.status == 'active':
                ret_active_flows.append(str(flowobj.src_ip))
        return ret_active_flows


    def get_sampled_sip(self):
        if self.has_sampled:
            return
        sample_pool = self.get_active_flows_ip()
        SimLogger.INFO('we have '+str(len(sample_pool))+' IPs')
        for ip in sample_pool:
            if random.random() > Config.CLASS_SAMPLE_RATE:
                continue
            if ip not in self.sampled_sip:
                self.sampled_sip.append(ip)
        self.has_sampled = True
        SimLogger.INFO('we sampled '+str(len(self.sampled_sip))+' IPs')

    def gen_new_flow_with_src_dst(self, ev_queue, start_time, end_time, src_ip, dst_ip, frate, is_mal, tc_name, attack_type):
        """
        """
        # Generate flow size and rate.
        fsize = float('inf')
        # To prevent tuple collision
        src_port = self.src_port % 65536
        dst_port = self.dst_port % 65536
        self.src_port += 1
        self.dst_port += 1

        event = EvFlowArrival(ev_time=start_time, src_ip=src_ip, dst_ip=dst_ip, src_port=src_port, \
                              dst_port=dst_port, flow_size=fsize, flow_rate=frate, is_mal=is_mal, \
                              tc=tc_name, attack_type=attack_type)
        heappush(ev_queue, (start_time, event))

        event = EvFlowEnd(ev_time=end_time, src_ip=src_ip, dst_ip=dst_ip, \
                          src_port=src_port, dst_port=dst_port)
        heappush(ev_queue, (end_time, event))


    def gen_init_flows(self, ev_queue):
        print('='*80)
        print('Initializing flows...')

        n_mal = 0
        n_norm = 0
        for key in self.hostobjs:
            host = self.hostobjs[key]
            if host.host_type != 'send':
                continue
            if host.is_mal == True:
                n_mal += host.n_flows
            else:
                n_norm += host.n_flows

            for _ in range(host.n_flows):
                # normal flow, added directly
                if host.is_mal == False:
                    start_time = 0.0
                    end_time   = Config.SIM_TIME
                    self.gen_new_flow_with_src_dst(ev_queue, start_time, end_time, host.flow_srcip, \
                                                   host.flow_dstip, host.flow_rate, False, host.tc, host.attack_type)
                elif host.is_mal == True:
                    assert (host.rolling == 1 or host.rolling == 2)
                    for i in range(Config.ROLLING_ROUNDS):
                            start_time =  Config.ATTACK_START + 2*i * (Config.ATTACK_PERIOD + Config.ROLLING_GAP) \
                                          if host.rolling == 1 \
                                          else Config.ATTACK_START + (2*i+1) * (Config.ATTACK_PERIOD + Config.ROLLING_GAP)
                            end_time = start_time + Config.ATTACK_PERIOD
                            self.gen_new_flow_with_src_dst(ev_queue, start_time, end_time, host.flow_srcip, \
                                                           host.flow_dstip, host.flow_rate, True, host.tc, host.attack_type)
                else:
                    print('Wong host state')
                    exit(1)

        print('Finish initializing flows')
        print(n_norm, n_mal)

    def main_course(self):
        """The main course of simulation execution.

        Args:
            None

        Returns:

        """
        self.exec_st_time = time() # start time

        # Step 1: Generate initial set of flows and queue them as FlowArrival events
        self.gen_init_flows(self.ev_queue)

        # Step 2: Initialize EvPrintLinkUtil
        if (Config.PRINT_LINK_UTIL > 0):
            heappush(self.ev_queue, (Config.PERIOD_PRINTING, EvPrintLinkUtil(ev_time=Config.PERIOD_PRINTING)))

        if (Config.LOG_LINK_UTIL > 0):
            heappush(self.ev_queue, (Config.PERIOD_LOGGING, EvLogLinkUtil(ev_time=Config.PERIOD_LOGGING)))

        # Periodically update flow rate
        heappush(self.ev_queue, (Config.PERIOD_UPDATE_FLOWRATE, EvUpdateFlowRate(ev_time=Config.PERIOD_UPDATE_FLOWRATE)))

        # Periodically detect LFA
        if Config.NO_DEFENSE == 0:
            heappush(self.ev_queue, (Config.PERIOD_DETECT, EvDetectAttack(ev_time=Config.PERIOD_DETECT)))


        # Step 3: Main loop of simulation
        print('='*80)
        print("Start simulation. Experiment name: %s" %(Config.EXP_NAME))

        next_prog_time = 0.0
        while True:
            if (self.timer > self.sim_time or len(self.ev_queue) == 0):
                break

            # Show progress
            if(Config.SHOW_PROGRESS > 0):
                if (self.timer > next_prog_time):
                    percentage = self.timer * 100.0 / Config.SIM_TIME
                    sys.stdout.write("Sim Time: %-3.2fs (%-3.2f%%)    " %(self.timer, percentage)   + \
                                     "Exec Time: %-5.3f seconds    "    %(time()-self.exec_st_time) + \
                                     "#Flows:%-4d\r\n"                  %(len(self.flows))
                                    )
                    sys.stdout.flush()
                    next_prog_time = ceil(percentage) * Config.SIM_TIME / 100.0


            self.timer = self.ev_queue[0][0]    # Set timer to next event's ev_time

            event_tuple     = heappop(self.ev_queue)
            ev_time         = event_tuple[0]
            event           = event_tuple[1]
            ev_type         = event.ev_type

            # ---- Handle Events ----
            # Handle EvFlowArrival
            if   (ev_type == 'EvFlowArrival'):
                self.handle_EvFlowArrival(ev_time, event)
                self.n_flow_event += 1

            # Handle EvFlowEnd
            elif (ev_type == 'EvFlowEnd'):
                self.handle_EvFlowEnd(ev_time, event)

            # Handle EvUpdateFlowRate
            elif (ev_type == 'EvUpdateFlowRate'):
                self.handle_EvUpdateFlowRate(ev_time, event)

            # Handle EvDetectAttack
            elif (ev_type == 'EvDetectAttack'):
                self.handle_EvDetectAttack(ev_time, event)

            # Handle EvClassification
            elif (ev_type == 'EvClassification'):
                self.handle_EvClassification(ev_time, event)

            # Handle EvSyncLinkset
            elif (ev_type == 'EvSyncLinkset'):
                self.handle_EvSyncLinkset(ev_time, event)

            # Handle EvSyncSuspflows
            elif (ev_type == 'EvSyncSuspflows'):
                self.handle_EvSyncSuspflows(ev_time, event)

            # Handle EvMitigation
            elif (ev_type == 'EvMitigation'):
                self.handle_EvMitigation(ev_time, event)

            # Handle EvPrintLinkUtil
            elif (ev_type == 'EvPrintLinkUtil'):
                self.handle_EvPrintLinkUtil(ev_time, event)

            # Handle EvLogLinkUtil
            elif (ev_type == 'EvLogLinkUtil'):
                self.handle_EvLogLinkUtil(ev_time, event)

            self.event_log_recs.append({'event_time': round(ev_time, 3), 'event_type': event.ev_type})

        # Finalize
        # self.update_all_flows(self.sim_time)
        self.exec_ed_time = time()

        # Step 4: Dump list of records to csv files
        if (cfg.LOG_LINK_UTIL > 0):
            self.dump_link_util()
            self.dump_link_util_trg()
            self.dump_link_flows()
            self.dump_host_rate()
            self.dump_flow_rate()
            self.dump_norm_rate()
            self.dump_event_log()

        print("End simulation. Experiment name: %s" %(Config.EXP_NAME))

        if (cfg.SHOW_SUMMARY > 0):
            self.show_summary()
