	// sync to all ports!
    action set_sync_mcast(bit<16> mcast_id) {
      standard_metadata.mcast_grp = mcast_id;
    }

    table tab_sync_mcast {
        key = {
            hdr.sync.srcSWUID: exact;
        }
        actions = {
          set_sync_mcast;
          pkt_drop;
        }
        default_action = pkt_drop();
    }

    // send to root switch
    action set_sync_nhop(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table tab_sync_nhop {
        key = {
            hdr.sync.srcSWUID: exact;
        }
        actions = {
          set_sync_nhop;
          pkt_drop;
        }
        default_action = pkt_drop();
    }