#!/usr/bin/python
# -*- coding: utf-8 -*-

"""sim/SimFlow.py: Class for flow profile that records attributes and stats of individual flows.
"""

# Built-in modules

# Third-party modules
import netaddr as na
# User-defined modules


class SimFlow:
    """Class for a flow profile. Will be referred by SimCore and Controller.

    Attributes:
        src_ip (netaddr.IPAddress)
        dst_ip (netaddr.IPAddress)
        src_node (str)
        dst_node (str)
        path (list of str)
        flow_size (float64): Total number of bytes to be transmitted
        flow_rate (float64): Maximum data rate for this flow (limited by source & dest) in Bps
        curr_rate (float64): Current data rate for this flow (limited by network) in Bps
        bytes_left (float64): Bytes not yet sent at current time
        bytes_sent (float64): Bytes already sent at current time
        status (str): Status of the flow ('requesting', 'active', 'idle')
        arrive_time (float64): Time when flow arrives at edge switch (before it is requested and installed)
        install_time (float64): Time when flow entries are installed to path switches
        end_time (float64): Time when flow transmission completes
        remove_time (float64): Time when flow entries are removed from path switches
        update_time (float64): Time when flow's status or rate is last updated
        duration (float64): Flow duration
        resend (int): # of resent EvPacketIn events before flow got admitted
        reroute (int): # of times this flow being rerouted

    Extra Notes:
        1. Possible flow status: 'requesting', 'active', 'finished', 'removed'
    """

    def __init__(   self,
                    src_ip          =na.IPAddress(0),
                    dst_ip          =na.IPAddress(0),
                    src_port        =0,
                    dst_port        =0,
                    src_node        ='',
                    dst_node        ='',
                    path            =[],
                    links           =[],
                    flow_size       =0.0,
                    flow_rate       =0.0,
                    curr_rate       =0.0,
                    avg_rate        =0.0,
                    bytes_left      =0.0,
                    bytes_sent      =0.0,
                    status          = 'requesting',
                    arrive_time     = float('inf'),
                    install_time    = float('inf'),
                    end_time        = float('inf'),
                    est_end_time    = float('inf'),
                    remove_time     = float('inf'),
                    update_time     = float('inf'),
                    collect_time    = float('inf'),
                    duration        = float('inf'),
                    resend          = 0,
                    reroute         = 0,
                    cnt             = 0,
                    is_mal          = False,
                    tc              = 'none',
                    attack_type     = 'none'
                ):
        """

        Extra Notes:
            For any time-related attributes, -1.0 means not decided.
        """
        self.src_ip         = src_ip
        self.dst_ip         = dst_ip
        self.src_port       = src_port
        self.dst_port       = dst_port
        self.src_node       = src_node
        self.dst_node       = dst_node
        self.path           = path
        self.links_original = None
        self.links          = links
        self.flow_size      = flow_size
        self.flow_rate      = flow_rate
        self.curr_rate      = curr_rate
        self.avg_rate       = avg_rate
        self.bytes_left     = bytes_left
        self.bytes_sent     = bytes_sent
        self.status         = status
        self.arrive_time    = arrive_time
        self.install_time   = install_time
        self.end_time       = end_time
        self.est_end_time   = est_end_time
        self.remove_time    = remove_time
        self.update_time    = update_time
        self.collect_time   = collect_time
        self.duration       = duration
        self.resend         = resend
        self.reroute        = reroute
        self.cnt            = cnt
        self.is_mal         = is_mal
        self.tc             = tc
        self.attack_type    = attack_type

        # These variables are used in calc_flow_rates
        self.assigned       = False

    def __str__(self):
        # Header is tuple of (src_ip, dst_ip); attribute name and value shown line by line
        ret =   'Flow (%s:%d -> %s:%d)\n'    %(self.src_ip, self.src_port, self.dst_ip, self.dst_port) + \
                '    status: %s\n'          %(self.status) + \
                '    src_node: %s\n'        %(self.src_node) + \
                '    dst_node: %s\n'        %(self.dst_node) + \
                '    path: %s\n'            %(self.path) + \
                '    links_original: %s\n'  %(self.links_original) + \
                '    flow_size: %.6f\n'     %(self.flow_size) + \
                '    flow_rate: %.6f\n'     %(self.flow_rate) + \
                '    curr_rate: %.6f\n'     %(self.curr_rate) + \
                '    avg_rate: %.6f\n'      %(self.avg_rate) + \
                '    bytes_left: %.6f\n'    %(self.bytes_left) + \
                '    bytes_sent: %.6f\n'    %(self.bytes_sent) + \
                '    arrive_time: %.6f\n'   %(self.arrive_time) + \
                '    install_time: %.6f\n'  %(self.install_time) + \
                '    end_time: %.6f\n'      %(self.end_time) + \
                '    remove_time: %.6f\n'   %(self.remove_time) + \
                '    update_time: %.6f\n'   %(self.update_time) + \
                '    duration: %.6f\n'      %(self.duration) + \
                '    resend: %d\n'          %(self.resend) + \
                '    reroute: %d\n'         %(self.reroute) + \
                '    cnt: %.6f\n'           %(self.cnt) + \
                '    is_mal: %s\n'          %(self.is_mal) + \
                '    tc: %s\n'              %(self.tc) + \
                '    attack_type: %s\n'     %(self.attack_type)

        return ret


    def install_flow(self, ev_time, path, links):
        """Change the flow to 'active' status, and update states accordingly.
        """
        self.status                 =   'active'
        self.update_time            =   ev_time
        self.install_time           =   ev_time
        self.path                   =   path
        self.links                  =   links

    def update_path(self, path, links):
        self.path                   =   path
        self.links                  =   links

    def set_original_links(self, links):
        self.links_original         =   links


    def update_flow(self, ev_time):
        """Change the flow's states up to ev_time.
        """
        bytes_recent                =   0.0

        # If the flows's status is 'active', calculate the following states:
        if (self.status == 'active'):
            # bytes_recent: For an active flow, the # of transmitted bytes
            #               since last state update

            print(self.curr_rate)

            bytes_recent            =   self.curr_rate * (ev_time - self.update_time)
            self.bytes_left         -=  bytes_recent
            self.bytes_sent         =   self.flow_size - self.bytes_left
            self.cnt                +=  bytes_recent
            self.avg_rate           =   0 if ev_time - self.arrive_time == 0 \
                                          else self.bytes_sent / (ev_time - self.arrive_time)

        self.update_time            =   ev_time
        return bytes_recent


    def terminate_flow(self, ev_time):
        """Change the flow to 'finished' status, and update states accordingly.
        """
        self.status         = 'finished'
        self.update_time    = ev_time
        self.end_time       = ev_time
        self.est_end_time   = float('inf')
        self.duration       = self.end_time - self.arrive_time
        self.bytes_left     = 0.0       # To avoid tiny error caused by FP calculation
        self.bytes_sent     = self.flow_size
        self.curr_rate      = 0.0


    def timeout_flow(self, ev_time):
        """Change the flow to 'removed' status, and update states accordingly.
        """
        self.status         = 'removed'
        self.update_time    = ev_time
        self.remove_time    = ev_time


    def assign_bw(self, ev_time, asgn_bw):
        """When calculating flow BW, assign BW and change flag of the flow.
        """
        self.curr_rate              = asgn_bw
        if self.curr_rate!= 0:
            self.est_end_time           = ev_time + (self.bytes_left / self.curr_rate)
        self.assigned               = True
