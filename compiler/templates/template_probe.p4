
        if (hdr.ipv4.protocol == PROBE_PROTOCOL){

            ctrl_probe.apply(hdr, meta, standard_metadata, \
                                d_link_util, \
                                link_thresh, \
                                probe_seqNo, \
                                best_util, \
                                best_path);

            //Multicast the probe
            if (meta.probe_update == 1) {
                tab_probe_mcast.apply();
            } else {
                DROP();
            }
        }
