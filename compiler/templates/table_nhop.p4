

/*************************************************************************
****************           set next hop                *******************
*************************************************************************/

    action pkt_drop() {
        DROP();
    }

    action noAction() { }

    action set_nhop(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table set_nhop_tab {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            set_nhop;
            pkt_drop;
        }
        size = 1024;
        default_action = pkt_drop();
    }