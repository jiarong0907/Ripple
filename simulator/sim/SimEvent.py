#!/usr/bin/python
# -*- coding: utf-8 -*-

"""sim/SimEvent.py: Define various event classes that are used for discrete event-based simulation.
"""

# Built-in modules
import inspect
# Third-party modules
import netaddr as na
# User-defined modules
import SimConfig as cfg


class SimEvent:
    """Base class of events, which is going to be queued in event queue under SimCore.

    Attributes:
        ev_type (str): Explicitly illustrates the event's type
                  (FlowArrival, FlowEnd, CollectStats, etc.)
        ev_time (float64): Time of event occurence

    Extra Notes:
        1. Event types:
           FlowArrival, PacketIn, FlowInstall, FlowEnd,
           IdleTimeout, HardTimeout, CollectStats, DoReroute

    """

    def __init__(self, **kwargs):
        """Constructor of Event class. Will be overriden by child classes.
        """
        self.ev_type = kwargs.get('ev_type', 'notype')
        self.ev_time = kwargs.get('ev_time', 0.0)

    def __str__(self):
        ret = 'Event type: %s\n' %(self.ev_type)     # Header line shows event type
        ret += '    Event time: %.6f\n' %(self.ev_time)

        attrs = ([attr for attr in dir(self)
                  if not attr.startswith('__') and not attr=='ev_type'
                  and not attr=='ev_time'])
                                                    # Print attribute name and value line by line
        for attr in attrs:
            ret += '    %s: %s\n' %(attr, getattr(self, attr))
        return ret

    def __repr__(self):
        return str(self)


class EvFlowArrival(SimEvent):
    """Event that signals arrival of a flow, and will trigger a PacketIn event.

    Attributes:
        ev_type (str): 'EvFlowArrival'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP
        flow_size (float64): Number of bytes to be transmitted in this flow.
        flow_rate (float64): The maximum data rate (bytes per sec) this flow can transmit.
                             Currently not supported.
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvFlowArrival', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip         = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip         = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port       = kwargs.get('src_port', 0)
        self.dst_port       = kwargs.get('dst_port', 0)
        self.flow_size      = kwargs.get('flow_size', 0.0)
        self.flow_rate      = kwargs.get('flow_rate', 0.0)
        self.is_mal         = kwargs.get('is_mal', False)
        self.tc             = kwargs.get('tc', 'none')
        self.attack_type    = kwargs.get('attack_type', 'none')


class EvPacketIn(SimEvent):
    """Event that signals an OpenFlow packet-in request's arrival at the controller.

    Attributes:
        ev_type (str): 'EvPacketIn'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP
        src_node (string): Source SW
        dst_node (string): Dest SW
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvPacketIn', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip     = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip     = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port   = kwargs.get('src_port', 0)
        self.dst_port   = kwargs.get('dst_port', 0)
        self.src_node   = kwargs.get('src_node', 'unknown')
        self.dst_node   = kwargs.get('dst_node', 'unknown')


class EvFlowInstall(SimEvent):
    """Event that signals installation of a flow at switches along selected path.

    Attributes:
        ev_type (str): 'EvFlowInstall'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP
        src_node (string): Source SW
        dst_node (string): Dest SW
        path (list of str): An ordered list of switch names along the path.
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvFlowInstall', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip     = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip     = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port   = kwargs.get('src_port', 0)
        self.dst_port   = kwargs.get('dst_port', 0)
        self.src_node   = kwargs.get('src_node', 'unknown')
        self.dst_node   = kwargs.get('dst_node', 'unknown')
        self.path       = kwargs.get('path', [])


class EvFlowEnd(SimEvent):
    """Event that signals end of a flow, and will trigger a IdleTimeout event.

    Attributes:
        ev_type (str): 'EvFlowEnd'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvFlowEnd', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip     = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip     = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port   = kwargs.get('src_port', 0)
        self.dst_port   = kwargs.get('dst_port', 0)


class EvIdleTimeout(SimEvent):
    """Event that signals idle timeout of a flow and consequent removal of its entries.

    Attributes:
        ev_type (str): 'EvIdleTimeout'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvIdleTimeout', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip     = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip     = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port   = kwargs.get('src_port', 0)
        self.dst_port   = kwargs.get('dst_port', 0)


class EvHardTimeout(SimEvent):
    """Event that signals hard timeout of a flow and consequent re-request of its entries.

    Attributes:
        ev_type (str): 'EvHardTimeout'
        src_ip (netaddr.ip.IPAddress): Source IP
        dst_ip (netaddr.ip.IPAddress): Destination IP

    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvHardTimeout', ev_time=kwargs.get('ev_time', 0.0))
        self.src_ip     = kwargs.get('src_ip', na.IPAddress(0))
        self.dst_ip     = kwargs.get('dst_ip', na.IPAddress(0))
        self.src_port   = kwargs.get('src_port', 0)
        self.dst_port   = kwargs.get('dst_port', 0)


class EvPullStats(SimEvent):
    """Event that signals controller's pulling flow-level statistics.

    Attributes:
        ev_type (str): 'EvPullStats'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvPullStats', ev_time=kwargs.get('ev_time', 0.0))


class EvLogLinkUtil(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvLogLinkUtil'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvLogLinkUtil', ev_time=kwargs.get('ev_time', 0.0))

class EvPrintLinkUtil(SimEvent):
    """Event that signals the simulation core to print link utilizations.

    Attributes:
        ev_type (str): 'EvPrintLinkUtil'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvPrintLinkUtil', ev_time=kwargs.get('ev_time', 0.0))


class EvLogTableUtil(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvLogLinkUtil'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvLogTableUtil', ev_time=kwargs.get('ev_time', 0.0))


class EvCollectCnt(SimEvent):
    """Event that signals the controller to collect counters from simulation core.

    Attributes:
        ev_type (str): 'EvCollectCnt'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvCollectCnt', ev_time=kwargs.get('ev_time', 0.0))


class EvReroute(SimEvent):
    """Event that signals the simulated controllers to reroute elephant flows.

    Attributes:
        ev_type (str): 'EvReroute'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvReroute', ev_time=kwargs.get('ev_time', 0.0))

class EvUpdateFlowRate(SimEvent):
    """Event that signals the simulator to update flow rate.

    Attributes:
        ev_type (str): 'EvUpdateFlowRate'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvUpdateFlowRate', ev_time=kwargs.get('ev_time', 0.0))

class EvDetectAttack(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvDetectAttack'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvDetectAttack', ev_time=kwargs.get('ev_time', 0.0))

class EvSyncLinkset(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvSyncLinkset'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvSyncLinkset', ev_time=kwargs.get('ev_time', 0.0))
        self.key    = kwargs.get('key', 'none')
        self.add    = kwargs.get('add', True) # add the link or remove the link

class EvSyncSuspflows(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvSyncSuspflows'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvSyncSuspflows', ev_time=kwargs.get('ev_time', 0.0))
        self.suspflows    = kwargs.get('suspflows', [])
        self.susp_type    = kwargs.get('susp_type', 'none')


class EvClassification(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvClassification'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvClassification', ev_time=kwargs.get('ev_time', 0.0))


class EvMitigation(SimEvent):
    """Event that signals the simulation core to log link utilizations.

    Attributes:
        ev_type (str): 'EvMitigation'
    """

    def __init__(self, **kwargs):
        SimEvent.__init__(self, ev_type='EvMitigation', ev_time=kwargs.get('ev_time', 0.0))
        self.susp_type    = kwargs.get('susp_type', 'none')