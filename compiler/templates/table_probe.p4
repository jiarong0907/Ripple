    // mcast probes to all ports!
    action set_probe_mcast(bit<16> mcast_id) {
      standard_metadata.mcast_grp = mcast_id;
    }

    table tab_probe_mcast {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
          set_probe_mcast;
          pkt_drop;
        }
        default_action = pkt_drop();
    }