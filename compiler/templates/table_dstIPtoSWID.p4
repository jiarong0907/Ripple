    // translate dstIP to the switch number
    action dstIPtoSWID(bit<32> SWID) {
      meta.ip_to_swid = SWID;
    }

    action noAction2() { }

    table tab_dstIPtoSWID {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
          dstIPtoSWID;
          noAction2;
        }
        default_action = noAction2();
    }