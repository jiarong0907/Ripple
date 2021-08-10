
control ctrl_probe(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> d_link_util,
                  in register<bit<32>> link_thresh,
                  in register<bit<32>> probe_seqNo,
                  in register<bit<32>> best_util,
                  in register<bit<32>> best_path) {

    apply{
        // Update Util
        bit<32> tmp_util = 0;
        bit<32> probe_in_port = (bit<32>) standard_metadata.ingress_port;
        bit<32> d_ingress_link = (meta.swid << 3) + (bit<32>)standard_metadata.ingress_port;
        d_link_util.read(tmp_util, d_ingress_link);

        hdr.probe.util = hdr.probe.util > tmp_util ? hdr.probe.util : tmp_util;

        bit<32> probe_util = hdr.probe.util;
        bit<32> current_remaining_best;
        bit<32> current_dstSWID;

        bit<32> thresh = 0;
        link_thresh.read(thresh, (bit<32>)standard_metadata.ingress_port);
        bit<32> real_link_load = probe_util >> 16;
        bit<32> probe_remaining = (real_link_load < thresh) ? (thresh - real_link_load) : 0;


        probe_seqNo.read(current_dstSWID, hdr.probe.dstSWID);
        best_util.read(current_remaining_best, hdr.probe.dstSWID);

        // Update choices table
        bool eq_seq = (hdr.probe.seqNo == current_dstSWID);
        bool gt_seq = (hdr.probe.seqNo > current_dstSWID);
        // To prevent frequent path changing
        // Attention: need to tune parameter
        // bool better_remaining = ((probe_remaining > current_remaining_best) && (probe_remaining - current_remaining_best > 5));
        bool better_remaining = ((probe_remaining > current_remaining_best) && (probe_remaining - current_remaining_best > 50));
        if ((eq_seq && better_remaining) || gt_seq) {
            best_path.write(hdr.probe.dstSWID, probe_in_port);
            best_util.write(hdr.probe.dstSWID, probe_remaining);
            probe_seqNo.write(hdr.probe.dstSWID, hdr.probe.seqNo);
            meta.probe_update = 1;
        }
    }
}
