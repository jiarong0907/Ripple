control compute_load(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<48>> d_link_last_ts,
                  in register<bit<32>> d_link_util) {

    apply{
        bit<48> last_ts = 0;
        bit<32> time_intvl = 0;
        bit<32> tmp_util1 = 0;
        bit<32> tmp_util2 = 0;

        bit<32> link_idx = (meta.swid << 3) + (bit<32>)standard_metadata.egress_spec;

        d_link_last_ts.read(last_ts, link_idx);
        d_link_util.read(tmp_util1, link_idx);
        time_intvl = (bit<32>)(standard_metadata.ingress_global_timestamp - last_ts);
        tmp_util2 = tmp_util1 * time_intvl;
        tmp_util1 = standard_metadata.packet_length + tmp_util1 - (tmp_util2 / TAU);

        if (time_intvl > THRESH_UTIL_RESET) {
            tmp_util1 = 0;
        }

        d_link_util.write(link_idx, tmp_util1);
        d_link_last_ts.write(link_idx, standard_metadata.ingress_global_timestamp);
    }
}