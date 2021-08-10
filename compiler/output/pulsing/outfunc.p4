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
control read_load(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> d_link_util) {

    apply{
        bit<32> link = (meta.swid << 3) + (bit<32>)standard_metadata.egress_spec;
        d_link_util.read(meta.ld, link);
    }
}

control filter_ld_detection1_2(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> link_thresh) {

    apply{
        bit<32> thresh = 0;
        link_thresh.read(thresh, (bit<32>)standard_metadata.egress_spec);
        bit<32> real_link_load = meta.ld >> 16;

        if (real_link_load >= thresh) {
            meta.detection_filter1 = 1;
        } else {
            meta.detection_filter1 = 0; //no high load, clean this flag
        }
    }
}

control filter_ld_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> victimLks,
                  in register<bit<32>> victimLks_size) {

    apply{

        if (meta.detection_filter1 == 1) {

            bit<32> prev_status;
            victimLks.read(prev_status, meta.link);
            victimLks_size.read(meta.victimLks_size, 0);

            if (prev_status == 0){
                victimLks.write(meta.link, 1);
                meta.victimLks_size = meta.victimLks_size + 1;
                victimLks_size.write(0, meta.victimLks_size);
            }
        }
    }
}


control reduce_pktlen_to_flowsz_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> reduce_pktlen_to_flowsz_cur_wind_val;
        reduce_pktlen_to_flowsz_cur_wind.read(reduce_pktlen_to_flowsz_cur_wind_val, 0);
        bit<32> reduce_pktlen_to_flowsz_cur_wind_pass_val;
        reduce_pktlen_to_flowsz_cur_wind_pass.read(reduce_pktlen_to_flowsz_cur_wind_pass_val, 0);

        if (meta.reduce_pktlen_to_flowsz_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.reduce_pktlen_to_flowsz_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            reduce_pktlen_to_flowsz_cur_wind_pass.write(0, reduce_pktlen_to_flowsz_cur_wind_pass_val + 1);
            reduce_pktlen_to_flowsz_clean_offset.write(0, 0);
            if (reduce_pktlen_to_flowsz_cur_wind_val == 0){
                reduce_pktlen_to_flowsz_cur_wind.write(0, 1);
                reduce_pktlen_to_flowsz_full_wind.write(0, 0);
                reduce_pktlen_to_flowsz_clean_wind.write(0, 2);
                reduce_pktlen_to_flowsz_cur_wind_val = 1;
            } else if (reduce_pktlen_to_flowsz_cur_wind_val == 1){
                reduce_pktlen_to_flowsz_cur_wind.write(0, 2);
                reduce_pktlen_to_flowsz_full_wind.write(0, 1);
                reduce_pktlen_to_flowsz_clean_wind.write(0, 3);
                reduce_pktlen_to_flowsz_cur_wind_val = 2;
            } else if (reduce_pktlen_to_flowsz_cur_wind_val == 2){
                reduce_pktlen_to_flowsz_cur_wind.write(0, 3);
                reduce_pktlen_to_flowsz_full_wind.write(0, 2);
                reduce_pktlen_to_flowsz_clean_wind.write(0, 0);
                reduce_pktlen_to_flowsz_cur_wind_val = 3;
            } else {
                reduce_pktlen_to_flowsz_cur_wind.write(0, 0);
                reduce_pktlen_to_flowsz_full_wind.write(0, 3);
                reduce_pktlen_to_flowsz_clean_wind.write(0, 1);
                reduce_pktlen_to_flowsz_cur_wind_val = 0;
            }
        }
    }
}

control reduce_pktlen_to_flowsz_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w3) {

    apply{
        bit<32> reduce_pktlen_to_flowsz_cur_wind_val;
        reduce_pktlen_to_flowsz_cur_wind.read(reduce_pktlen_to_flowsz_cur_wind_val, 0);


        bit<32> reduce_pktlen_to_flowsz_idx0;
        bit<32> reduce_pktlen_to_flowsz_idx1;
        bit<32> reduce_pktlen_to_flowsz_idx2;

        hash(reduce_pktlen_to_flowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(reduce_pktlen_to_flowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(reduce_pktlen_to_flowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_flowsz_val0;
        bit<32> reduce_pktlen_to_flowsz_val1;
        bit<32> reduce_pktlen_to_flowsz_val2;
        REG_WIND_READ(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_val0, reduce_pktlen_to_flowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_val1, reduce_pktlen_to_flowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_val2, reduce_pktlen_to_flowsz_idx2)


        bit<32> reduce_pktlen_to_flowsz_cur = (reduce_pktlen_to_flowsz_val0 < reduce_pktlen_to_flowsz_val1) ? reduce_pktlen_to_flowsz_val0 : reduce_pktlen_to_flowsz_val1;
        reduce_pktlen_to_flowsz_cur = (reduce_pktlen_to_flowsz_cur < reduce_pktlen_to_flowsz_val2) ? reduce_pktlen_to_flowsz_cur : reduce_pktlen_to_flowsz_val2;


        //update the reduce value to sketches
        reduce_pktlen_to_flowsz_cur = reduce_pktlen_to_flowsz_cur + standard_metadata.packet_length;

        REG_WIND_WRITE(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_idx0, reduce_pktlen_to_flowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_idx1, reduce_pktlen_to_flowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_cur_wind_val, reduce_pktlen_to_flowsz_idx2, reduce_pktlen_to_flowsz_cur)
    }
}

control reduce_pktlen_to_flowsz_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_clean_offset,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w3) {

    apply{
        bit<32> reduce_pktlen_to_flowsz_cur_wind_pass_val;
        reduce_pktlen_to_flowsz_cur_wind_pass.read(reduce_pktlen_to_flowsz_cur_wind_pass_val, 0);

        if (reduce_pktlen_to_flowsz_cur_wind_pass_val >= 2){
            bit<32> reduce_pktlen_to_flowsz_clean_offset_val;
            reduce_pktlen_to_flowsz_clean_offset.read(reduce_pktlen_to_flowsz_clean_offset_val, 0);
            bit<32> reduce_pktlen_to_flowsz_clean_wind_val;
            reduce_pktlen_to_flowsz_clean_wind.read(reduce_pktlen_to_flowsz_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)

                if (reduce_pktlen_to_flowsz_clean_offset_val + 512 > REDUCE_PKTLEN_TO_FLOWSZ_SIZE){
                    reduce_pktlen_to_flowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz_clean_offset_val = reduce_pktlen_to_flowsz_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_clean_wind_val, reduce_pktlen_to_flowsz_clean_offset_val)

                if (reduce_pktlen_to_flowsz_clean_offset_val + 128 > REDUCE_PKTLEN_TO_FLOWSZ_SIZE){
                    reduce_pktlen_to_flowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz_clean_offset_val = reduce_pktlen_to_flowsz_clean_offset_val + 128;
                }
            #endif

            reduce_pktlen_to_flowsz_clean_offset.write(0, reduce_pktlen_to_flowsz_clean_offset_val);
        }
    }
}

control reduce_pktlen_to_flowsz_read(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w3) {

    apply{
        bit<32> reduce_pktlen_to_flowsz_full_wind_val;
        reduce_pktlen_to_flowsz_full_wind.read(reduce_pktlen_to_flowsz_full_wind_val, 0);

        bit<32> reduce_pktlen_to_flowsz_idx0;
        bit<32> reduce_pktlen_to_flowsz_idx1;
        bit<32> reduce_pktlen_to_flowsz_idx2;

        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(reduce_pktlen_to_flowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(reduce_pktlen_to_flowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(reduce_pktlen_to_flowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_flowsz_val0;
        bit<32> reduce_pktlen_to_flowsz_val1;
        bit<32> reduce_pktlen_to_flowsz_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_full_wind_val, reduce_pktlen_to_flowsz_val0, reduce_pktlen_to_flowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_full_wind_val, reduce_pktlen_to_flowsz_val1, reduce_pktlen_to_flowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_full_wind_val, reduce_pktlen_to_flowsz_val2, reduce_pktlen_to_flowsz_idx2)

        meta.reduce_pktlen_to_flowsz_full = (reduce_pktlen_to_flowsz_val0 < reduce_pktlen_to_flowsz_val1) ? reduce_pktlen_to_flowsz_val0 : reduce_pktlen_to_flowsz_val1;
        meta.reduce_pktlen_to_flowsz_full = (meta.reduce_pktlen_to_flowsz_full < reduce_pktlen_to_flowsz_val2) ? meta.reduce_pktlen_to_flowsz_full : reduce_pktlen_to_flowsz_val2;
    }
}
control zip_flowsz_flowsz(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s0_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s1_w3,
                  in register<bit<32>> reduce_pktlen_to_flowsz_s2_w3) {

    apply{
        // read flow rate before rerouting
        bit<32> reduce_pktlen_to_flowsz_full_wind_val2;
        reduce_pktlen_to_flowsz_full_wind.read(reduce_pktlen_to_flowsz_full_wind_val2, 0);

        bit<32> flowsz2_idx0;
        bit<32> flowsz2_idx1;
        bit<32> flowsz2_idx2;

        hash(flowsz2_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(flowsz2_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(flowsz2_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);

        bit<32> flowsz2_val0;
        bit<32> flowsz2_val1;
        bit<32> flowsz2_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_full_wind_val2, flowsz2_val0, flowsz2_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_full_wind_val2, flowsz2_val1, flowsz2_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_full_wind_val2, flowsz2_val2, flowsz2_idx2)

        meta.flowsz2_val = (flowsz2_val0 < flowsz2_val1) ? flowsz2_val0 : flowsz2_val1;
        meta.flowsz2_val = (meta.flowsz2_val < flowsz2_val2) ? meta.flowsz2_val : flowsz2_val2;

        // read flow rate after rerouting
        bit<32> reduce_pktlen_to_flowsz_full_wind_val1;
        if (reduce_pktlen_to_flowsz_full_wind_val2>=1){
            reduce_pktlen_to_flowsz_full_wind_val1 = reduce_pktlen_to_flowsz_full_wind_val2-1;
        } else {
            reduce_pktlen_to_flowsz_full_wind_val1 = 3;
        }
        reduce_pktlen_to_flowsz_full_wind.read(reduce_pktlen_to_flowsz_full_wind_val1, 0);

        bit<32> flowsz1_idx0;
        bit<32> flowsz1_idx1;
        bit<32> flowsz1_idx2;

        hash(flowsz1_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(flowsz1_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);
        hash(flowsz1_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ_SIZE);

        bit<32> flowsz1_val0;
        bit<32> flowsz1_val1;
        bit<32> flowsz1_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz_s0, reduce_pktlen_to_flowsz_full_wind_val1, flowsz1_val0, flowsz1_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s1, reduce_pktlen_to_flowsz_full_wind_val1, flowsz1_val1, flowsz1_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz_s2, reduce_pktlen_to_flowsz_full_wind_val1, flowsz1_val2, flowsz1_idx2)

        meta.flowsz1_val = (flowsz1_val0 < flowsz1_val1) ? flowsz1_val0 : flowsz1_val1;
        meta.flowsz1_val = (meta.flowsz1_val < flowsz1_val2) ? meta.flowsz1_val : flowsz1_val2;
    }
}
control filter_flowsz1_flowsz2_classification1_3(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz_cur_wind_pass) {

    apply{
        // classify when at least one window is full
        bit<32> reduce_pktlen_to_flowsz_cur_wind_pass_val;
        reduce_pktlen_to_flowsz_cur_wind_pass.read(reduce_pktlen_to_flowsz_cur_wind_pass_val, 0);

        if (meta.flowsz1_val - meta.flowsz2_val > 500 && meta.flowsz1_val > meta.flowsz2_val && reduce_pktlen_to_flowsz_cur_wind_pass_val >= 1) {
            meta.classification_filter1 = 1;
        } else {
            meta.classification_filter1 = 0; //no high load, clean this flag
        }
    }
}


control filter_flowsz1_flowsz2_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> pulsewaves) {

    apply{

        bit<32> pulsewaves_idx0;
        bit<32> pulsewaves_idx1;
        bit<32> pulsewaves_idx2;

        hash(pulsewaves_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)PULSEWAVES_SIZE);
        hash(pulsewaves_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)PULSEWAVES_SIZE);
        hash(pulsewaves_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)PULSEWAVES_SIZE);

        if (hdr.ipv4.protocol == TCP_PROTOCOL){
            pulsewaves.write(pulsewaves_idx0, 1);
            pulsewaves.write(pulsewaves_idx1, 1);
            pulsewaves.write(pulsewaves_idx2, 1);
        }
    }
}
control filter_victimLks_size_mitigation1_1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> victimLks_size) {

    apply{
        victimLks_size.read(meta.victimLks_size, 0);
        if (meta.victimLks_size > 1) {
            meta.mitigation_filter1 = 1;
        } else {
            meta.mitigation_filter1 = 0; //no high load, clean this flag
        }
    }
}


control filter_sip_in_pulsewaves_mitigation1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> pulsewaves) {

    apply{
        bit<32> pulsewaves_idx0;
        bit<32> pulsewaves_idx1;
        bit<32> pulsewaves_idx2;

        // TODO: use small number
        hash(pulsewaves_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)PULSEWAVES_SIZE);
        hash(pulsewaves_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)PULSEWAVES_SIZE);
        hash(pulsewaves_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)PULSEWAVES_SIZE);

        bit<32> pulsewaves_val0;
        bit<32> pulsewaves_val1;
        bit<32> pulsewaves_val2;

        pulsewaves.read(pulsewaves_val0, pulsewaves_idx0);
        pulsewaves.read(pulsewaves_val1, pulsewaves_idx1);
        pulsewaves.read(pulsewaves_val2, pulsewaves_idx2);

        if (pulsewaves_val0 == 1 && pulsewaves_val1 == 1 && pulsewaves_val2 == 1) {
            meta.mitigation_filter1 = 1;
        } else {
            meta.mitigation_filter1 = 0;
        }
    }
}

control ctrl_sync(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                                    in register<bit<32>> victimLks, 
                  in register<bit<32>> victimLks_size, 
                  in register<bit<32>> pulsewaves, 

                  in register<bit<32>> d_swid) {

    apply{
        bit<32> offset = hdr.sync.offset;

        DEF_VAR_128(victimLks_val)
        READ_REG_128(victimLks, victimLks_val)
        DEF_VAR_128(pulsewaves_val)
        READ_REG_128(pulsewaves, pulsewaves_val)

        d_swid.read(meta.swid, 0);
        if (meta.swid == 3) { // The root
            if (hdr.sync.srcSWUID == 3) { // downstream packets
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_128_OR(hdr.sync.pulsewaves, pulsewaves_val)
            }
            // upstream packets
            else {
                bit<32> victimLks_cnt_val;
                victimLks_size.read(victimLks_cnt_val, 0);

                UPDATE_LINKSET_CNT_128(victimLks_cnt_val, victimLks_val, hdr.sync.victimLks);
                victimLks_size.write(0, victimLks_cnt_val);
                UPDATE_REG_BF_128(victimLks, victimLks_val, hdr.sync.victimLks)
                UPDATE_REG_BF_128(pulsewaves, pulsewaves_val, hdr.sync.pulsewaves)
            }
        }
        // not root
        else {
            // go to the root, set header
            if (hdr.sync.srcSWUID == 3) { // from root
                bit<32> victimLks_cnt_val;
                victimLks_size.read(victimLks_cnt_val, 0);

                UPDATE_LINKSET_CNT_128(victimLks_cnt_val, victimLks_val, hdr.sync.victimLks);
                victimLks_size.write(0, victimLks_cnt_val);

                UPDATE_REG_BF_128(victimLks, victimLks_val, hdr.sync.victimLks)
                UPDATE_REG_BF_128(pulsewaves, pulsewaves_val, hdr.sync.pulsewaves)
            }
            // sent out from the root, update local states
            else {
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_128_OR(hdr.sync.pulsewaves, pulsewaves_val)
            }
        }
    }
}
