#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimCoreLogging.py: Class SimCoreLogging, containing logging-related codes for SimCore.
Inherited by SimCore.
"""

# Built-in modules
import os
import csv
from math import ceil
# Third-party modules
#import numpy as np
import pprint as pp
# User-defined modules
import SimConfig as Config
from .SimLogger import *


class SimCoreLogging:
    """
    """

    def __init__(self):
        """Constructor of SimCoreLogging class.
        This constructor includes initialization codes for bookeeping and logging parts
        of SimCore.

        Args:
            None

        """
        # Lists for keeping records (link util., table util., and flow stats)
        self.link_util_recs     = []
        self.link_util_trg_recs = []
        self.link_flows_recs    = []
        self.host_rate_recs     = []
        self.flow_rate_recs     = []
        self.norm_rate_recs     = []
        self.event_log_recs     = []

        # File paths and names for csv log files
        if ( not os.path.exists(Config.LOG_DIR) ):
            os.makedirs(Config.LOG_DIR)

        self.fn_link_util       =   os.path.join(Config.LOG_DIR, 'link_util.csv')
        self.fn_link_util_trg   =   os.path.join(Config.LOG_DIR, 'link_util_target.csv')
        self.fn_link_flows      =   os.path.join(Config.LOG_DIR, 'link_flows.csv')
        self.fn_host_rate       =   os.path.join(Config.LOG_DIR, 'host_rate.csv')
        self.fn_flow_rate       =   os.path.join(Config.LOG_DIR, 'flow_rate.csv')
        self.fn_norm_rate       =   os.path.join(Config.LOG_DIR, 'norm_rate.csv')
        self.fn_event_log       =   os.path.join(Config.LOG_DIR, 'event_log.csv')
        # self.fn_summary     =   os.path.join(Config.LOG_DIR, 'summary.csv')

        # Column names for csv log files
        self.col_link_util      =   ['time'] + [str(lk) for lk in self.links]
        self.col_link_util_trg  =   ['time'] + [str(lk) for lk in self.targetlinks]
        self.col_link_flows     =   ['time'] + [str(lk) for lk in self.links]
        self.col_host_rate      =   ['time', 'name', 'is_mal', 'rolling', 'n_flows', 'flow_rate', 'srcip', 'dstip', \
                                 'srcsw', 'dstsw', 'host_rate']
        self.col_flow_rate      =   ['time', 'src_ip', 'dst_ip', 'src_port', 'dst_port', 'src_node', 'dst_node', 'curr_rate']
        self.col_norm_rate      =   ['time', 'curr_rate1', 'curr_rate2']
        self.col_event_log      =   ['event_time', 'event_type']

        # Record column vectors
        self.col_vec_link_util      = {k: [] for k in self.col_link_util}
        self.col_vec_link_util_trg  = {k: [] for k in self.col_link_util_trg}
        self.col_vec_link_flows     = {k: [] for k in self.col_link_flows}
        self.col_vec_host_rate  = {k: [] for k in self.col_host_rate}
        self.col_vec_flow_rate  = {k: [] for k in self.col_flow_rate}
        self.col_vec_norm_rate  = {k: [] for k in self.col_norm_rate}
        self.col_vec_event_log  = {k: [] for k in self.col_event_log}

        # Parameters & counters for summary
        self.summary_message = ''   # A string that stores the whole summary message
        self.n_EvFlowArrival = 0
        self.n_EvFlowEnd = 0
        self.n_active_flows = 0
        self.n_ended_flows = 0
        self.exec_st_time = self.exec_ed_time = self.exec_time = 0.0

        # Register CSV dialect
        csv.register_dialect('flowsim', delimiter=',', quoting=csv.QUOTE_NONNUMERIC)


    def log_link_util(self, ev_time):
        """
        """
        ret_util        = {'time': round(ev_time, 3)}
        ret_util_trg    = {'time': round(ev_time, 3)}
        ret_flows       = {'time': round(ev_time, 3)}

        # Get link_util and link_flows info
        for lk in self.links:
            linkobj = self.linkobjs[lk]
            ret_util[str(lk)]   = 1 - linkobj.unasgn_bw/float(linkobj.cap)
            ret_flows[str(lk)]  =   self.linkobjs[lk].get_n_active_flows()

        # Get target link_util info
        for lk in self.targetlinks:
            linkobj = self.linkobjs[self.targetlinks[lk]]
            ret_util_trg[str(lk)]   = 1 - linkobj.unasgn_bw/float(linkobj.cap)

        # Append to column vectors
        for k in ret_util:      self.col_vec_link_util[k].append(ret_util[k])
        for k in ret_util_trg:  self.col_vec_link_util_trg[k].append(ret_util_trg[k])
        for k in ret_flows:     self.col_vec_link_flows[k].append(ret_flows[k])

        return ret_util, ret_util_trg, ret_flows


    def log_norm_rate(self, ev_time):
        """
        """
        ret_rate    = {'time': round(ev_time, 3)}
        linkobj = self.linkobjs[Config.LOG_LINK1]
        SimLogger.DEBUG('Logging link is '+str(Config.LOG_LINK1))
        rate = 0.0
        for fl in self.flows:
            flowobj = self.flows[fl]
            if flowobj.is_mal == False and Config.LOG_LINK1 in flowobj.links_original:
                rate += flowobj.curr_rate

        ret_rate['curr_rate1'] = rate

        linkobj = self.linkobjs[Config.LOG_LINK2]
        SimLogger.DEBUG('Logging link is '+str(Config.LOG_LINK2))
        rate = 0.0
        for fl in self.flows:
            flowobj = self.flows[fl]
            if flowobj.is_mal == False and Config.LOG_LINK2 in flowobj.links_original:
                rate += flowobj.curr_rate

        ret_rate['curr_rate2'] = rate

        return ret_rate

    def log_host_rate(self, ev_time):
        """
        """
        ret_host_rate = []

        for hostobj in self.get_all_send_host():
            this_host_rate              = {'time': round(ev_time, 3)}
            this_host_rate['name']      = hostobj.name
            this_host_rate['is_mal']    = hostobj.is_mal
            this_host_rate['rolling']   = hostobj.rolling
            this_host_rate['n_flows']   = hostobj.n_flows
            this_host_rate['flow_rate']      = hostobj.flow_rate
            this_host_rate['srcip']     = hostobj.flow_srcip
            this_host_rate['dstip']     = hostobj.flow_dstip
            this_host_rate['srcsw']     = hostobj.flow_srcsw
            this_host_rate['dstsw']     = hostobj.flow_dstsw
            this_host_rate['host_rate']     = self.get_host_rate(hostobj.ip)
            ret_host_rate.append(this_host_rate)

        return ret_host_rate

    def log_flow_rate(self, ev_time):
        """
        """
        ret_flow_rate = []

        for fl in self.flows:
            flowobj = self.flows[fl]
            this_flow_rate                  = {'time': round(ev_time, 3)}
            this_flow_rate['src_ip']        = flowobj.src_ip
            this_flow_rate['dst_ip']        = flowobj.dst_ip
            this_flow_rate['src_port']      = flowobj.src_port
            this_flow_rate['dst_port']      = flowobj.dst_port
            this_flow_rate['src_node']      = flowobj.src_node.flow_srcsw
            this_flow_rate['dst_node']      = flowobj.dst_node.flow_dstsw
            this_flow_rate['curr_rate']     = flowobj.curr_rate

            ret_flow_rate.append(this_flow_rate)

        return ret_flow_rate

    def dump_link_util(self):
        """
        """
        recs        = self.link_util_recs
        col_vecs    = self.col_vec_link_util
        wt          = csv.DictWriter(open(self.fn_link_util, 'wb'), \
                                     fieldnames=self.col_link_util, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_link_util_trg(self):
        """
        """
        recs        = self.link_util_trg_recs
        col_vecs    = self.col_vec_link_util_trg
        wt          = csv.DictWriter(open(self.fn_link_util_trg, 'wb'), \
                                     fieldnames=self.col_link_util_trg, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_norm_rate(self):
        """
        """
        recs        = self.norm_rate_recs
        col_vecs    = self.col_vec_norm_rate
        wt          = csv.DictWriter(open(self.fn_norm_rate, 'wb'), \
                                     fieldnames=self.col_norm_rate, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_link_flows(self):
        """
        """
        recs        = self.link_flows_recs
        col_vecs    = self.col_vec_link_flows
        wt          = csv.DictWriter(open(self.fn_link_flows, 'wb'), \
                                     fieldnames=self.col_link_flows, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_host_rate(self):
        """
        """
        recs        = self.host_rate_recs
        col_vecs    = self.col_vec_host_rate
        wt          = csv.DictWriter(open(self.fn_host_rate, 'wb'), \
                                     fieldnames=self.col_host_rate, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_flow_rate(self):
        """
        """
        recs        = self.flow_rate_recs
        col_vecs    = self.col_vec_flow_rate
        wt          = csv.DictWriter(open(self.fn_flow_rate, 'wb'), \
                                     fieldnames=self.col_flow_rate, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_event_log(self):
        """
        """
        recs        = self.event_log_recs
        col_vecs    = self.col_vec_event_log
        wt          = csv.DictWriter(open(self.fn_event_log, 'wb'), \
                                     fieldnames=self.col_event_log, \
                                     dialect='flowsim')

        # Write records to CSV writer line by line
        wt.writeheader()
        wt.writerows(recs)

    def dump_summary(self):
        """
        """
        summary_file = open(self.fn_summary, 'w')

        self.summary_message += ('PATHDB_MODE,%s\n'         %(Config.PATHDB_MODE))
        if (Config.ROUTING_MODE == 'kpath_yen'):
            self.summary_message += ('    K_PATH,%s\n'          %(Config.K_PATH))
            #self.summary_message += ('    K_PATH_METHOD,%s\n'   %(Config.K_PATH_METHOD))
        self.summary_message += ('ROUTING_MODE,%s\n'        %(Config.ROUTING_MODE))
        self.summary_message += ('DO_REROUTE,%s\n'          %(Config.DO_REROUTE))
        self.summary_message += ('n_EvFlowArrival,%d\n'     %(self.n_EvFlowArrival))
        self.summary_message += ('n_EvPacketIn,%d\n'        %(self.n_EvPacketIn))
        self.summary_message += ('n_Reject,%d\n'            %(self.n_Reject))
        self.summary_message += ('n_EvFlowEnd,%d\n'         %(self.n_EvFlowEnd))
        self.summary_message += ('n_EvIdleTimeout,%d\n'     %(self.n_EvIdleTimeout))
        self.summary_message += ('n_rerouted_flows,%d\n'    %(self.n_rerouted_flows))
        self.summary_message += ('avg_throughput,%e\n'      %(self.avg_throughput))
        self.summary_message += ('avg_link_util,%.6f\n'     %(self.avg_link_util))
        self.summary_message += ('std_link_util,%.6f\n'     %(self.std_link_util))
        self.summary_message += ('avg_table_util,%.6f\n'    %(self.avg_table_util))
        self.summary_message += ('std_table_util,%.6f\n'    %(self.std_table_util))
        self.summary_message += ('exec_time,%.6f\n'         %(self.exec_ed_time - self.exec_st_time))

        summary_file.write(self.summary_message)


    def show_summary(self):
        """
        """
        print()
        print('-'*40)
        print('Summary:')
        print('-'*40)

        summary_message=''
        summary_message += ('n_EvFlowArrival,%d\n'     %(self.n_EvFlowArrival))
        summary_message += ('n_EvFlowEnd,%d\n'         %(self.n_EvFlowEnd))
        summary_message += ('exec_time,%.6f\n'         %(self.exec_ed_time - self.exec_st_time))

        for line in summary_message.split('\n'):
            words = line.split(',')
            if words[0] == '':
                continue
            else:
                print(' = '.join(words))
        print()

