#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimCoreEventHandling.py: Class SimCoreEventHandling, containing event handling codes for SimCore.
Inherited by SimCore.
"""

# Built-in modules
from heapq import heappush, heappop
# Third-party modules
# User-defined modules
import SimConfig as Config
from .SimFlow import *
from .SimEvent import *
from .SimClassification import *
from .SimMitigation import *
from .SimLogger import *


class SimCoreEventHandling:
    """Event handling-related codes for SimCore class.
    """

    def handle_EvFlowArrival(self, ev_time, event):
        """Handle an EvFlowArrival event.
        1. Enqueue an EvPacketIn event after SW_CTRL_DELAY
        2. Add a SimFlow instance to self.flows, and mark the flow's status as 'requesting'

        Args:
            ev_time (float64): Event time
            event (Instance inherited from .SimEvent): FlowArrival event

        Return:
            None. Will schedule events to self.ev_queue if necessary.

        """
        SimLogger.INFO('='*80)
        SimLogger.INFO('Handling flow arrival event...')

        self.n_EvFlowArrival += 1      # Increment the counter

        # Create SimFlow instance
        flow_obj    = SimFlow(  src_ip=event.src_ip, dst_ip=event.dst_ip, \
                                src_port=event.src_port, dst_port=event.dst_port, \
                                src_node=self.hostobjs[event.src_ip], \
                                dst_node=self.hostobjs[event.dst_ip], \
                                flow_size=event.flow_size, flow_rate=event.flow_rate, \
                                bytes_left=event.flow_size, \
                                arrive_time=ev_time, update_time=ev_time, \
                                status='requesting', resend=0, is_mal=event.is_mal, \
                                tc=event.tc, attack_type=event.attack_type)

        # Add to self.flows
        self.flows[(event.src_ip, event.dst_ip, event.src_port, event.dst_port)] = flow_obj

        # find the routing path
        src_node=self.hostobjs[event.src_ip]
        path = self.tcobjs[event.tc].path

        # Register entries at SimSwitch & SimLink instances
        list_links = self.get_links_on_path(path)
        self.install_flow_to_path(path, list_links, event.src_ip, event.dst_ip, event.src_port, event.dst_port)

        # Update the installed flow's states to 'active'
        fl = (event.src_ip, event.dst_ip, event.src_port, event.dst_port)
        flowobj = self.flows[fl]
        flowobj.install_flow(ev_time, path, list_links)
        flowobj.set_original_links(list_links)

        # Decrement/increment active flow counters at sim core and links
        for lk in list_links:
            self.linkobjs[lk].n_active_flows += 1
        self.n_active_flows += 1

        # Set the mark to enable recomputing
        self.need_update = True
        SimLogger.INFO("Finish handling flow arrival event...")


    def handle_EvFlowEnd(self, ev_time, event):
        """Handle an EvFlowEnd event.
        1. Schedule an EvIdleTimeout event, after IDLE_TIMEOUT.
        2. Mark the flow's status as 'idle'.
        3. Update the SimCore's flow statistics.
        4. Log flow stats if required.
        5. Generate new flows if required.

        Args:
            ev_time (float64): Event time
            event (Instance inherited from .SimEvent): FlowArrival event

        Return:
            None. Will schedule events to self.ev_queue if necessary.

        """
        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling flow end event...")

        # Update the ending flow's states to 'finished'
        fl      = (event.src_ip, event.dst_ip, event.src_port, event.dst_port)
        flowobj = self.flows[fl]
        flowobj.terminate_flow(ev_time)

        # Decrement/increment active flow counters at sim core and links
        for lk in flowobj.links:
            self.linkobjs[lk].n_active_flows -= 1
        self.n_active_flows     -= 1
        self.n_EvFlowEnd        += 1

        # Remove flow entry from switches along path
        for nd in flowobj.path:
            self.switchobjs[nd].remove_flow(event.src_ip, event.dst_ip, event.src_port, event.dst_port)

        # Remove flow entry from links along path
        for lk in flowobj.links:
            self.linkobjs[lk].remove_flow(event.src_ip, event.dst_ip, event.src_port, event.dst_port)

        # Finally, remove the flow entry from self.flows
        del self.flows[fl]

        # Increment flowend counter
        self.n_ended_flows += 1

        # Set the mark to enable recomputing
        self.need_update = True

        SimLogger.INFO("Finish handling flow end event...")


    def handle_EvPrintLinkUtil(self, ev_time, event):
        """
        """
        if (Config.LOG_LINK_UTIL > 0):
            # First update all link utilization
            self.update_link_util()
            # Log link utilization data
            print()
            print('-'*80)
            print('Link utilization---time: '+str(ev_time)+'s')
            print('-'*80)
            message = '|'
            new_line = False
            tmp = 0
            for key in self.linkobjs:
                if new_line == True:
                    message += '\n'
                    message += '| '
                    new_line = False
                linkobj = self.linkobjs[key]
                message += '('+linkobj.node1+', '+linkobj.node2+'): '+str(100 - linkobj.unasgn_bw/float(linkobj.cap)*100)+'% | '
                tmp += 1
                if tmp > 5:
                    tmp = 0
                    new_line = True
            print(message)

            # Log flow rate data
            print('-'*80)
            print('Flow rate---time: '+str(ev_time)+'s')
            print('-'*80)
            message = '|'
            new_line = False
            tmp = 0
            # printed_rate = []

            count_dict = {}
            for key in self.flows:
                if str(self.flows[key].curr_rate) not in count_dict:
                    count_dict[str(self.flows[key].curr_rate)] = 1
                else:
                    count_dict[str(self.flows[key].curr_rate)] += 1

            for key in count_dict.keys():
                print(key, ': ', count_dict[key])

            # Schedule next EvPrintLinkUtil event
            new_ev_time = ev_time + Config.PERIOD_LOGGING
            heappush(self.ev_queue, (new_ev_time, EvPrintLinkUtil(ev_time=new_ev_time)))


    def handle_EvUpdateFlowRate(self, ev_time, event):
        """
        """
        # First update all flow's states
        self.calc_flow_rates_min_max(ev_time)

        # Schedule next EvUpdateFlowRate event
        new_ev_time = ev_time + Config.PERIOD_UPDATE_FLOWRATE
        heappush(self.ev_queue, (new_ev_time, EvUpdateFlowRate(ev_time=new_ev_time)))


    def clean_state(self):
        self.is_attacked                = False
        self.congested_links            = []
        self.suspflows_crossfire        = []
        self.has_sampled                = False
        self.sampled_sip                = []
        self.has_rerouted               = False
        self.has_dropped                = False
        self.has_classified_crossfire   = False
        self.rerouted_norm_flow         = []


    def handle_EvSyncLinkset(self, ev_time, event):
        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event SyncLinkset ..., time is "+str(ev_time))

        if event.add and event.key not in self.congested_links:
            self.congested_links.append(event.key)

        elif (not event.add) and event.key in self.congested_links:
            self.congested_links.remove(event.key)

        # detect LFA here
        if len(self.congested_links) >= Config.CONGEST_LINK_THRESH:
            self.is_attacked = True
            self.get_sampled_sip()
            SimLogger.INFO('The sampled IPs are ')
            SimLogger.INFO(self.sampled_sip)
        else:
            self.clean_state()
        SimLogger.INFO('The current system state is '+str(self.is_attacked))

        if self.is_attacked == True:
            if Config.HAS_CLASSIFICATION == 1:
                # Compute sync time
                if Config.SYSTEM_TYPE == 'RIPPLE':
                    new_ev_time = ev_time + self.sync_delay
                elif Config.SYSTEM_TYPE == 'SDN':
                    new_ev_time = ev_time + Config.SDN_SOFTWARE_TIME + self.sync_delay
                else:
                    SimLogger.ERROR('ERROR: Cannot identify the system type:'+str(Config.SYSTEM_TYPE)+'. Exiting...')
                    exit(1)

                heappush(self.ev_queue, (new_ev_time, EvClassification(ev_time=new_ev_time)))
            elif Config.HAS_CLASSIFICATION == 0:
                # no classification, direction entering mitigation
                assert Config.ATTACK_TYPE == 'CROSSFIRE'
                # Compute sync time
                if Config.SYSTEM_TYPE == 'RIPPLE':
                    new_ev_time = ev_time + self.sync_delay
                elif Config.SYSTEM_TYPE == 'SDN':
                    new_ev_time = ev_time + Config.SOL_TIME_NOCLASS + self.sync_delay + Config.RULE_INSTALL_TIME
                else:
                    SimLogger.ERROR('ERROR: Cannot identify the system type:'+str(Config.SYSTEM_TYPE)+'. Exiting...')
                    exit(1)

                suspflows = [hostobj.flow_srcip for hostobj in self.get_all_send_host()]
                # Schedule next EvMitigation event
                heappush(self.ev_queue, (new_ev_time, EvMitigation(ev_time=new_ev_time, suspflows=suspflows, susp_type='CROSSFIRE')))
        SimLogger.INFO("Finish handling event SyncLinkset")

    def handle_EvSyncSuspflows(self, ev_time, event):
        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event SyncSuspflows ..., time is "+str(ev_time))

        assert Config.HAS_CLASSIFICATION == 1

        if self.is_attacked == False:
            return

        if event.susp_type == 'CROSSFIRE':
            for item in event.suspflows:
                if item not in self.suspflows_crossfire:
                    self.suspflows_crossfire.append(item)
        else:
            print('Unidentified sync event attack type')
            exit(1)

        if Config.SYSTEM_TYPE == 'RIPPLE':
            mitigation_time = ev_time + self.sync_delay
            if Config.ATTACK_TYPE == 'CROSSFIRE':
                # Schedule next EvMitigation event
                SimLogger.INFO('Schedule a crossfire mitigation event at '+str(mitigation_time))
                heappush(self.ev_queue, (mitigation_time, EvMitigation(ev_time=mitigation_time, susp_type='CROSSFIRE')))
            else:
                print('handle_EvSyncSuspflows: Unidentified attack type')
                exit(1)
        elif Config.SYSTEM_TYPE == 'SDN':
            if Config.ATTACK_TYPE == 'CROSSFIRE':
                # Schedule next EvMitigation event
                if Config.SAMPLED_CLASSIFICATION == 1:
                    mitigation_time = ev_time + Config.SOL_TIME_SAMCLASS + self.sync_delay + Config.RULE_INSTALL_TIME
                else:
                    mitigation_time = ev_time + Config.SOL_TIME_DPCLASS + self.sync_delay + Config.RULE_INSTALL_TIME
                heappush(self.ev_queue, (mitigation_time, EvMitigation(ev_time=mitigation_time, susp_type='CROSSFIRE')))
            else:
                print('handle_EvSyncSuspflows: Unidentified attack type')
                exit(1)
        else:
            SimLogger.ERROR('ERROR: Cannot identify the system type:'+str(Config.SYSTEM_TYPE)+'. Exiting...')
            exit(1)
        SimLogger.INFO("Finish handling event SyncSuspflows")


    def handle_EvDetectAttack(self, ev_time, event):
        """
        """
        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event detection ..., time is "+str(ev_time))

        # Detect congested link on each link
        for key in self.linkobjs:
            linkobj = self.linkobjs[key]
            util = 1 - linkobj.unasgn_bw/float(linkobj.cap)
            sync_ev_time = ev_time + Config.SYNC_PERIOD/2.0 + self.sync_delay
            if Config.SYSTEM_TYPE == 'SDN':
                sync_ev_time += Config.SDN_SOFTWARE_TIME
            if util >= Config.CONGEST_THRESH and (key not in self.congested_links):
                SimLogger.DEBUG('link ('+linkobj.node1+", "+linkobj.node2+") is congested")
                # Schedule a linkset synchronization add event
                heappush(self.ev_queue, (sync_ev_time, EvSyncLinkset(ev_time=sync_ev_time,\
                                                                     key=key, add=True)))
            elif util < Config.CONGEST_THRESH and (key in self.congested_links):
                # Schedule a linkset synchronization remove event
                heappush(self.ev_queue, (sync_ev_time, EvSyncLinkset(ev_time=sync_ev_time,\
                                                                    key=key, add=False)))

        # Schedule next EvDetectAttack event
        new_ev_time = ev_time + Config.PERIOD_DETECT
        heappush(self.ev_queue, (new_ev_time, EvDetectAttack(ev_time=new_ev_time)))
        SimLogger.INFO("Finished handling event detection ..., time is "+str(ev_time))


    def handle_EvClassification(self, ev_time, event):
        """
        """
        if not self.is_attacked:
            return

        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event classificaiton ..., time is "+str(ev_time))

        if Config.ATTACK_TYPE == 'CROSSFIRE':
            self.classify_crossfire(ev_time)
        else:
            print('handle_EvClassification: Unidentified attack type')
            exit(1)

        # Schedule next EvClassification event
        SimLogger.INFO("Finish handling event classificaiton ...")

    def handle_EvMitigation(self, ev_time, event):
        """
        """
        if not self.is_attacked:
            return

        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event mitigation ...")

        if event.susp_type == 'CROSSFIRE':
            if Config.SYSTEM_TYPE == 'RIPPLE':
                # self.ripple_crossfire_reroute(ev_time)
                self.ripple_crossfire_reroute_sol(ev_time)
            elif Config.SYSTEM_TYPE == 'SDN':
                # self.sdn_crossfire_reroute_native(ev_time)
                self.sdn_crossfire_reroute_sol(ev_time)
            else:
                SimLogger.ERROR('ERROR: Cannot identify the system type:'+str(Config.SYSTEM_TYPE)+'. Exiting...')
                exit(1)
        else:
            print('handle_EvMitigation: Unidentified attack type')
            exit(1)

        SimLogger.INFO("Finish handling event mitigation ...")

    def handle_EvLogLinkUtil(self, ev_time, event):
        """
        """
        SimLogger.INFO('='*80)
        SimLogger.INFO("Handling event LogLinkUtil ...")

        # First update all flow's states
        self.calc_flow_rates_min_max(ev_time)

        if (cfg.LOG_LINK_UTIL > 0):
            # Create link util and link flows records, and append them to lists
            rec_link_util, rec_link_util_trg, rec_link_flows = self.log_link_util(ev_time)
            self.link_util_recs.append(rec_link_util)
            self.link_util_trg_recs.append(rec_link_util_trg)
            self.link_flows_recs.append(rec_link_flows)

            rec_norm_rate = self.log_norm_rate(ev_time)
            self.norm_rate_recs.append(rec_norm_rate)

            # Schedule next EvLogLinkUtil event
            new_ev_time = ev_time + cfg.PERIOD_LOGGING
            heappush(self.ev_queue, (new_ev_time, EvLogLinkUtil(ev_time=new_ev_time)))

        SimLogger.INFO("Finish handling event LogLinkUtil")

