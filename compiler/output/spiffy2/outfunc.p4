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

control filter_rerouteip_isempty_classification1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> rerouteip_isempty) {

    apply{
        if (meta.classification_filter2 == 1){
            bit<32> empty_val = 0;
            rerouteip_isempty.read(empty_val, 0);

            if (empty_val == 0){
                meta.classification_filter2 = 1;
            } else {
                meta.classification_filter2 = 0;
            }
        }
    }
}


control reduce_pktlen_to_flowsz1_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> reduce_pktlen_to_flowsz1_cur_wind_val;
        reduce_pktlen_to_flowsz1_cur_wind.read(reduce_pktlen_to_flowsz1_cur_wind_val, 0);
        bit<32> reduce_pktlen_to_flowsz1_cur_wind_pass_val;
        reduce_pktlen_to_flowsz1_cur_wind_pass.read(reduce_pktlen_to_flowsz1_cur_wind_pass_val, 0);

        if (meta.reduce_pktlen_to_flowsz1_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.reduce_pktlen_to_flowsz1_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            reduce_pktlen_to_flowsz1_cur_wind_pass.write(0, reduce_pktlen_to_flowsz1_cur_wind_pass_val + 1);
            reduce_pktlen_to_flowsz1_clean_offset.write(0, 0);
            if (reduce_pktlen_to_flowsz1_cur_wind_val == 0){
                reduce_pktlen_to_flowsz1_cur_wind.write(0, 1);
                reduce_pktlen_to_flowsz1_full_wind.write(0, 0);
                reduce_pktlen_to_flowsz1_clean_wind.write(0, 2);
                reduce_pktlen_to_flowsz1_cur_wind_val = 1;
            } else if (reduce_pktlen_to_flowsz1_cur_wind_val == 1){
                reduce_pktlen_to_flowsz1_cur_wind.write(0, 2);
                reduce_pktlen_to_flowsz1_full_wind.write(0, 1);
                reduce_pktlen_to_flowsz1_clean_wind.write(0, 0);
                reduce_pktlen_to_flowsz1_cur_wind_val = 2;
            } else {
                reduce_pktlen_to_flowsz1_cur_wind.write(0, 0);
                reduce_pktlen_to_flowsz1_full_wind.write(0, 2);
                reduce_pktlen_to_flowsz1_clean_wind.write(0, 1);
                reduce_pktlen_to_flowsz1_cur_wind_val = 0;
            }
        }
    }
}

control reduce_pktlen_to_flowsz1_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz1_cur_wind_val;
        reduce_pktlen_to_flowsz1_cur_wind.read(reduce_pktlen_to_flowsz1_cur_wind_val, 0);


        bit<32> reduce_pktlen_to_flowsz1_idx0;
        bit<32> reduce_pktlen_to_flowsz1_idx1;
        bit<32> reduce_pktlen_to_flowsz1_idx2;

        hash(reduce_pktlen_to_flowsz1_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(reduce_pktlen_to_flowsz1_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(reduce_pktlen_to_flowsz1_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);


        bit<32> reduce_pktlen_to_flowsz1_val0;
        bit<32> reduce_pktlen_to_flowsz1_val1;
        bit<32> reduce_pktlen_to_flowsz1_val2;
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_val0, reduce_pktlen_to_flowsz1_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_val1, reduce_pktlen_to_flowsz1_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_val2, reduce_pktlen_to_flowsz1_idx2)


        bit<32> reduce_pktlen_to_flowsz1_cur = (reduce_pktlen_to_flowsz1_val0 < reduce_pktlen_to_flowsz1_val1) ? reduce_pktlen_to_flowsz1_val0 : reduce_pktlen_to_flowsz1_val1;
        reduce_pktlen_to_flowsz1_cur = (reduce_pktlen_to_flowsz1_cur < reduce_pktlen_to_flowsz1_val2) ? reduce_pktlen_to_flowsz1_cur : reduce_pktlen_to_flowsz1_val2;


        //update the reduce value to sketches
        reduce_pktlen_to_flowsz1_cur = reduce_pktlen_to_flowsz1_cur + standard_metadata.packet_length;

        REG_WIND_WRITE(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_idx0, reduce_pktlen_to_flowsz1_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_idx1, reduce_pktlen_to_flowsz1_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_cur_wind_val, reduce_pktlen_to_flowsz1_idx2, reduce_pktlen_to_flowsz1_cur)
    }
}

control reduce_pktlen_to_flowsz1_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_clean_offset,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz1_cur_wind_pass_val;
        reduce_pktlen_to_flowsz1_cur_wind_pass.read(reduce_pktlen_to_flowsz1_cur_wind_pass_val, 0);

        if (reduce_pktlen_to_flowsz1_cur_wind_pass_val >= 2){
            bit<32> reduce_pktlen_to_flowsz1_clean_offset_val;
            reduce_pktlen_to_flowsz1_clean_offset.read(reduce_pktlen_to_flowsz1_clean_offset_val, 0);
            bit<32> reduce_pktlen_to_flowsz1_clean_wind_val;
            reduce_pktlen_to_flowsz1_clean_wind.read(reduce_pktlen_to_flowsz1_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)

                if (reduce_pktlen_to_flowsz1_clean_offset_val + 512 > REDUCE_PKTLEN_TO_FLOWSZ1_SIZE){
                    reduce_pktlen_to_flowsz1_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz1_clean_offset_val = reduce_pktlen_to_flowsz1_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_clean_wind_val, reduce_pktlen_to_flowsz1_clean_offset_val)

                if (reduce_pktlen_to_flowsz1_clean_offset_val + 128 > REDUCE_PKTLEN_TO_FLOWSZ1_SIZE){
                    reduce_pktlen_to_flowsz1_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz1_clean_offset_val = reduce_pktlen_to_flowsz1_clean_offset_val + 128;
                }
            #endif

            reduce_pktlen_to_flowsz1_clean_offset.write(0, reduce_pktlen_to_flowsz1_clean_offset_val);
        }
    }
}

control reduce_pktlen_to_flowsz1_read(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz1_full_wind_val;
        reduce_pktlen_to_flowsz1_full_wind.read(reduce_pktlen_to_flowsz1_full_wind_val, 0);

        bit<32> reduce_pktlen_to_flowsz1_idx0;
        bit<32> reduce_pktlen_to_flowsz1_idx1;
        bit<32> reduce_pktlen_to_flowsz1_idx2;

        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(reduce_pktlen_to_flowsz1_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(reduce_pktlen_to_flowsz1_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(reduce_pktlen_to_flowsz1_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);


        bit<32> reduce_pktlen_to_flowsz1_val0;
        bit<32> reduce_pktlen_to_flowsz1_val1;
        bit<32> reduce_pktlen_to_flowsz1_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_full_wind_val, reduce_pktlen_to_flowsz1_val0, reduce_pktlen_to_flowsz1_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_full_wind_val, reduce_pktlen_to_flowsz1_val1, reduce_pktlen_to_flowsz1_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_full_wind_val, reduce_pktlen_to_flowsz1_val2, reduce_pktlen_to_flowsz1_idx2)

        meta.reduce_pktlen_to_flowsz1_full = (reduce_pktlen_to_flowsz1_val0 < reduce_pktlen_to_flowsz1_val1) ? reduce_pktlen_to_flowsz1_val0 : reduce_pktlen_to_flowsz1_val1;
        meta.reduce_pktlen_to_flowsz1_full = (meta.reduce_pktlen_to_flowsz1_full < reduce_pktlen_to_flowsz1_val2) ? meta.reduce_pktlen_to_flowsz1_full : reduce_pktlen_to_flowsz1_val2;
    }
}
control filter_rerouteip_isempty_classification3(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> rerouteip_isempty) {

    apply{
        if (meta.classification_filter4 == 1){
            bit<32> empty_val = 0;
            rerouteip_isempty.read(empty_val, 0);

            if (empty_val == 0){
                meta.classification_filter4 = 1;
            } else {
                meta.classification_filter4 = 0;
            }
        }
    }
}


control reduce_pktlen_to_flowsz2_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> reduce_pktlen_to_flowsz2_cur_wind_val;
        reduce_pktlen_to_flowsz2_cur_wind.read(reduce_pktlen_to_flowsz2_cur_wind_val, 0);
        bit<32> reduce_pktlen_to_flowsz2_cur_wind_pass_val;
        reduce_pktlen_to_flowsz2_cur_wind_pass.read(reduce_pktlen_to_flowsz2_cur_wind_pass_val, 0);

        if (meta.reduce_pktlen_to_flowsz2_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.reduce_pktlen_to_flowsz2_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            reduce_pktlen_to_flowsz2_cur_wind_pass.write(0, reduce_pktlen_to_flowsz2_cur_wind_pass_val + 1);
            reduce_pktlen_to_flowsz2_clean_offset.write(0, 0);
            if (reduce_pktlen_to_flowsz2_cur_wind_val == 0){
                reduce_pktlen_to_flowsz2_cur_wind.write(0, 1);
                reduce_pktlen_to_flowsz2_full_wind.write(0, 0);
                reduce_pktlen_to_flowsz2_clean_wind.write(0, 2);
                reduce_pktlen_to_flowsz2_cur_wind_val = 1;
            } else if (reduce_pktlen_to_flowsz2_cur_wind_val == 1){
                reduce_pktlen_to_flowsz2_cur_wind.write(0, 2);
                reduce_pktlen_to_flowsz2_full_wind.write(0, 1);
                reduce_pktlen_to_flowsz2_clean_wind.write(0, 0);
                reduce_pktlen_to_flowsz2_cur_wind_val = 2;
            } else {
                reduce_pktlen_to_flowsz2_cur_wind.write(0, 0);
                reduce_pktlen_to_flowsz2_full_wind.write(0, 2);
                reduce_pktlen_to_flowsz2_clean_wind.write(0, 1);
                reduce_pktlen_to_flowsz2_cur_wind_val = 0;
            }
        }
    }
}

control reduce_pktlen_to_flowsz2_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz2_cur_wind_val;
        reduce_pktlen_to_flowsz2_cur_wind.read(reduce_pktlen_to_flowsz2_cur_wind_val, 0);


        bit<32> reduce_pktlen_to_flowsz2_idx0;
        bit<32> reduce_pktlen_to_flowsz2_idx1;
        bit<32> reduce_pktlen_to_flowsz2_idx2;

        hash(reduce_pktlen_to_flowsz2_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);
        hash(reduce_pktlen_to_flowsz2_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);
        hash(reduce_pktlen_to_flowsz2_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);


        bit<32> reduce_pktlen_to_flowsz2_val0;
        bit<32> reduce_pktlen_to_flowsz2_val1;
        bit<32> reduce_pktlen_to_flowsz2_val2;
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_val0, reduce_pktlen_to_flowsz2_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_val1, reduce_pktlen_to_flowsz2_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_val2, reduce_pktlen_to_flowsz2_idx2)


        bit<32> reduce_pktlen_to_flowsz2_cur = (reduce_pktlen_to_flowsz2_val0 < reduce_pktlen_to_flowsz2_val1) ? reduce_pktlen_to_flowsz2_val0 : reduce_pktlen_to_flowsz2_val1;
        reduce_pktlen_to_flowsz2_cur = (reduce_pktlen_to_flowsz2_cur < reduce_pktlen_to_flowsz2_val2) ? reduce_pktlen_to_flowsz2_cur : reduce_pktlen_to_flowsz2_val2;


        //update the reduce value to sketches
        reduce_pktlen_to_flowsz2_cur = reduce_pktlen_to_flowsz2_cur + standard_metadata.packet_length;

        REG_WIND_WRITE(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_idx0, reduce_pktlen_to_flowsz2_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_idx1, reduce_pktlen_to_flowsz2_cur)
        REG_WIND_WRITE(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_cur_wind_val, reduce_pktlen_to_flowsz2_idx2, reduce_pktlen_to_flowsz2_cur)
    }
}

control reduce_pktlen_to_flowsz2_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_clean_offset,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz2_cur_wind_pass_val;
        reduce_pktlen_to_flowsz2_cur_wind_pass.read(reduce_pktlen_to_flowsz2_cur_wind_pass_val, 0);

        if (reduce_pktlen_to_flowsz2_cur_wind_pass_val >= 2){
            bit<32> reduce_pktlen_to_flowsz2_clean_offset_val;
            reduce_pktlen_to_flowsz2_clean_offset.read(reduce_pktlen_to_flowsz2_clean_offset_val, 0);
            bit<32> reduce_pktlen_to_flowsz2_clean_wind_val;
            reduce_pktlen_to_flowsz2_clean_wind.read(reduce_pktlen_to_flowsz2_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)

                if (reduce_pktlen_to_flowsz2_clean_offset_val + 512 > REDUCE_PKTLEN_TO_FLOWSZ2_SIZE){
                    reduce_pktlen_to_flowsz2_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz2_clean_offset_val = reduce_pktlen_to_flowsz2_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_clean_wind_val, reduce_pktlen_to_flowsz2_clean_offset_val)

                if (reduce_pktlen_to_flowsz2_clean_offset_val + 128 > REDUCE_PKTLEN_TO_FLOWSZ2_SIZE){
                    reduce_pktlen_to_flowsz2_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_flowsz2_clean_offset_val = reduce_pktlen_to_flowsz2_clean_offset_val + 128;
                }
            #endif

            reduce_pktlen_to_flowsz2_clean_offset.write(0, reduce_pktlen_to_flowsz2_clean_offset_val);
        }
    }
}

control reduce_pktlen_to_flowsz2_read(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_flowsz2_full_wind_val;
        reduce_pktlen_to_flowsz2_full_wind.read(reduce_pktlen_to_flowsz2_full_wind_val, 0);

        bit<32> reduce_pktlen_to_flowsz2_idx0;
        bit<32> reduce_pktlen_to_flowsz2_idx1;
        bit<32> reduce_pktlen_to_flowsz2_idx2;

        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(reduce_pktlen_to_flowsz2_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);
        hash(reduce_pktlen_to_flowsz2_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);
        hash(reduce_pktlen_to_flowsz2_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ2_SIZE);


        bit<32> reduce_pktlen_to_flowsz2_val0;
        bit<32> reduce_pktlen_to_flowsz2_val1;
        bit<32> reduce_pktlen_to_flowsz2_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_full_wind_val, reduce_pktlen_to_flowsz2_val0, reduce_pktlen_to_flowsz2_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_full_wind_val, reduce_pktlen_to_flowsz2_val1, reduce_pktlen_to_flowsz2_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_full_wind_val, reduce_pktlen_to_flowsz2_val2, reduce_pktlen_to_flowsz2_idx2)

        meta.reduce_pktlen_to_flowsz2_full = (reduce_pktlen_to_flowsz2_val0 < reduce_pktlen_to_flowsz2_val1) ? reduce_pktlen_to_flowsz2_val0 : reduce_pktlen_to_flowsz2_val1;
        meta.reduce_pktlen_to_flowsz2_full = (meta.reduce_pktlen_to_flowsz2_full < reduce_pktlen_to_flowsz2_val2) ? meta.reduce_pktlen_to_flowsz2_full : reduce_pktlen_to_flowsz2_val2;
    }
}

control func_standard_metadata_egress_spec_reroute_classification(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> flow_nhop,
                  in register<bit<32>> best_path) {

    apply{
        bit<32> rerouted_link = 0;
        bit<32> flow_nhop_idx;
        hash(flow_nhop_idx, HashAlgorithm.crc16, (bit<16>)0,
        // Attention: must use meta.sip, meta.dip, consistent with malflows hash
        {NUM_RAND1, standard_metadata.egress_spec, NUM_RAND2}, (bit<16>)65535);
        flow_nhop.read(rerouted_link, flow_nhop_idx);


        if (rerouted_link != 0) {
            // rerouted previously, follow the same port
            standard_metadata.egress_spec = (bit<9>)rerouted_link;
        } else {
            //have not rerouted, follow least utilize path

            bit<32> best_nhop; //get best next hop
            best_path.read(best_nhop, (bit<32>)meta.ip_to_swid);
            standard_metadata.egress_spec = (bit<9>)best_nhop; //reroute to the best path
            flow_nhop.write(flow_nhop_idx, best_nhop); //record the choice
        }
    }
}
control filter_victimLks_size_classification5_7(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> victimLks_size) {

    apply{
        victimLks_size.read(meta.victimLks_size, 0);
        if (meta.victimLks_size > 3) {
            meta.classification_filter6 = 1;
        } else {
            meta.classification_filter6 = 0; //no high load, clean this flag
        }
    }
}


control distinct_sip_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> distinct_sip_cur_wind,
                  in register<bit<32>> distinct_sip_cur_wind_pass,
                  in register<bit<32>> distinct_sip_full_wind,
                  in register<bit<32>> distinct_sip_clean_wind,
                  in register<bit<32>> distinct_sip_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> distinct_sip_cur_wind_val;
        distinct_sip_cur_wind.read(distinct_sip_cur_wind_val, 0);
        bit<32> distinct_sip_cur_wind_pass_val;
        distinct_sip_cur_wind_pass.read(distinct_sip_cur_wind_pass_val, 0);

        if (meta.distinct_sip_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.distinct_sip_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            distinct_sip_cur_wind_pass.write(0, distinct_sip_cur_wind_pass_val + 1);
            distinct_sip_clean_offset.write(0, 0);
            if (distinct_sip_cur_wind_val == 0){
                distinct_sip_cur_wind.write(0, 1);
                distinct_sip_full_wind.write(0, 0);
                distinct_sip_clean_wind.write(0, 2);
                distinct_sip_cur_wind_val = 1;
            } else if (distinct_sip_cur_wind_val == 1){
                distinct_sip_cur_wind.write(0, 2);
                distinct_sip_full_wind.write(0, 1);
                distinct_sip_clean_wind.write(0, 0);
                distinct_sip_cur_wind_val = 2;
            } else {
                distinct_sip_cur_wind.write(0, 0);
                distinct_sip_full_wind.write(0, 2);
                distinct_sip_clean_wind.write(0, 1);
                distinct_sip_cur_wind_val = 0;
            }
        }
    }
}

control distinct_sip_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> distinct_sip_cur_wind,
                  in register<bit<32>> distinct_sip_bf_w0,
                  in register<bit<32>> distinct_sip_bf_w1,
                  in register<bit<32>> distinct_sip_bf_w2) {

    apply{
        bit<32> distinct_sip_cur_wind_val;
        distinct_sip_cur_wind.read(distinct_sip_cur_wind_val, 0);


        bit<32> distinct_sip_idx0;
        bit<32> distinct_sip_idx1;
        bit<32> distinct_sip_idx2;

        hash(distinct_sip_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)DISTINCT_SIP_SIZE);
        hash(distinct_sip_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)DISTINCT_SIP_SIZE);
        hash(distinct_sip_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)DISTINCT_SIP_SIZE);


        bit<32> distinct_sip_val0;
        bit<32> distinct_sip_val1;
        bit<32> distinct_sip_val2;

        REG_WIND_READ(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_val0, distinct_sip_idx0)
        REG_WIND_READ(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_val1, distinct_sip_idx1)
        REG_WIND_READ(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_val2, distinct_sip_idx2)

        if ((distinct_sip_val0 == 0) || (distinct_sip_val1 == 0) || (distinct_sip_val2 == 0)) {
            //this is distinct, update the BF to record this
            REG_WIND_WRITE(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_idx0, 1)
            REG_WIND_WRITE(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_idx1, 1)
            REG_WIND_WRITE(distinct_sip_bf, distinct_sip_cur_wind_val, distinct_sip_idx2, 1)
        } else {
            //we already have this in the BF, set the packet to be irrelevant
            meta.classification_filter6 = 0;
        }
    }
}

control distinct_sip_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> distinct_sip_cur_wind_pass,
                  in register<bit<32>> distinct_sip_clean_wind,
                  in register<bit<32>> distinct_sip_clean_offset,
                  in register<bit<32>> distinct_sip_bf_w0,
                  in register<bit<32>> distinct_sip_bf_w1,
                  in register<bit<32>> distinct_sip_bf_w2) {

    apply{
        bit<32> distinct_sip_cur_wind_pass_val;
        distinct_sip_cur_wind_pass.read(distinct_sip_cur_wind_pass_val, 0);

        // clean the other one
        if (distinct_sip_cur_wind_pass_val >= 2){
            bit<32> distinct_sip_clean_offset_val;
            distinct_sip_clean_offset.read(distinct_sip_clean_offset_val, 0);
            bit<32> distinct_sip_clean_wind_val;
            distinct_sip_clean_wind.read(distinct_sip_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(distinct_sip_bf, distinct_sip_clean_wind_val, distinct_sip_clean_offset_val)

                if (distinct_sip_clean_offset_val + 512 > DISTINCT_SIP_SIZE){
                    distinct_sip_clean_offset_val = 0;
                } else {
                    distinct_sip_clean_offset_val = distinct_sip_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(distinct_sip_bf, distinct_sip_clean_wind_val, distinct_sip_clean_offset_val)

                if (distinct_sip_clean_offset_val + 128 > DISTINCT_SIP_SIZE){
                    distinct_sip_clean_offset_val = 0;
                } else {
                    distinct_sip_clean_offset_val = distinct_sip_clean_offset_val + 128;
                }
            #endif

            distinct_sip_clean_offset.write(0, distinct_sip_clean_offset_val);
        }
    }
}

control filter_sip_in_rerouteip_classification7(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> rerouteip) {

    apply{
        bit<32> rerouteip_idx0;
        bit<32> rerouteip_idx1;
        bit<32> rerouteip_idx2;

        // TODO: use small number
        hash(rerouteip_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REROUTEIP_SIZE);
        hash(rerouteip_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REROUTEIP_SIZE);
        hash(rerouteip_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REROUTEIP_SIZE);

        bit<32> rerouteip_val0;
        bit<32> rerouteip_val1;
        bit<32> rerouteip_val2;

        rerouteip.read(rerouteip_val0, rerouteip_idx0);
        rerouteip.read(rerouteip_val1, rerouteip_idx1);
        rerouteip.read(rerouteip_val2, rerouteip_idx2);

        if (rerouteip_val0 == 1 && rerouteip_val1 == 1 && rerouteip_val2 == 1) {
            meta.classification_filter7 = 1;
        } else {
            meta.classification_filter7 = 0;
        }
    }
}
control zip_flowsz1_flowsz2(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_full_wind,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_s2_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_s2_w2) {

    apply{
        // read flow rate before rerouting
        bit<32> reduce_pktlen_to_flowsz2_full_wind_val;
        reduce_pktlen_to_flowsz2_full_wind.read(reduce_pktlen_to_flowsz2_full_wind_val, 0);

        bit<32> flowsz2_idx0;
        bit<32> flowsz2_idx1;
        bit<32> flowsz2_idx2;

        hash(flowsz2_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(flowsz2_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(flowsz2_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);

        bit<32> flowsz2_val0;
        bit<32> flowsz2_val1;
        bit<32> flowsz2_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz2_s0, reduce_pktlen_to_flowsz2_full_wind_val, flowsz2_val0, flowsz2_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s1, reduce_pktlen_to_flowsz2_full_wind_val, flowsz2_val1, flowsz2_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz2_s2, reduce_pktlen_to_flowsz2_full_wind_val, flowsz2_val2, flowsz2_idx2)

        meta.flowsz2_val = (flowsz2_val0 < flowsz2_val1) ? flowsz2_val0 : flowsz2_val1;
        meta.flowsz2_val = (meta.flowsz2_val < flowsz2_val2) ? meta.flowsz2_val : flowsz2_val2;

        // read flow rate after rerouting
        bit<32> reduce_pktlen_to_flowsz1_full_wind_val;
        reduce_pktlen_to_flowsz1_full_wind.read(reduce_pktlen_to_flowsz1_full_wind_val, 0);

        bit<32> flowsz1_idx0;
        bit<32> flowsz1_idx1;
        bit<32> flowsz1_idx2;

        hash(flowsz1_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(flowsz1_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);
        hash(flowsz1_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_FLOWSZ1_SIZE);

        bit<32> flowsz1_val0;
        bit<32> flowsz1_val1;
        bit<32> flowsz1_val2;

        REG_WIND_READ(reduce_pktlen_to_flowsz1_s0, reduce_pktlen_to_flowsz1_full_wind_val, flowsz1_val0, flowsz1_idx0)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s1, reduce_pktlen_to_flowsz1_full_wind_val, flowsz1_val1, flowsz1_idx1)
        REG_WIND_READ(reduce_pktlen_to_flowsz1_s2, reduce_pktlen_to_flowsz1_full_wind_val, flowsz1_val2, flowsz1_idx2)

        meta.flowsz1_val = (flowsz1_val0 < flowsz1_val1) ? flowsz1_val0 : flowsz1_val1;
        meta.flowsz1_val = (meta.flowsz1_val < flowsz1_val2) ? meta.flowsz1_val : flowsz1_val2;
    }
}
control filter_flowsz2_flowsz1_classification7_12(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_flowsz2_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_flowsz1_cur_wind_pass) {

    apply{
        // classify when at least one window is full
        bit<32> reduce_pktlen_to_flowsz2_cur_wind_pass_val;
        reduce_pktlen_to_flowsz2_cur_wind_pass.read(reduce_pktlen_to_flowsz2_cur_wind_pass_val, 0);
        bit<32> reduce_pktlen_to_flowsz1_cur_wind_pass_val;
        reduce_pktlen_to_flowsz1_cur_wind_pass.read(reduce_pktlen_to_flowsz1_cur_wind_pass_val, 0);

        if (meta.flowsz2_val - meta.flowsz1_val < 100 && meta.flowsz2_val > meta.flowsz1_val && reduce_pktlen_to_flowsz2_cur_wind_pass_val >= 1 && reduce_pktlen_to_flowsz1_cur_wind_pass_val >= 1) {
            meta.classification_filter7 = 1;
        } else {
            meta.classification_filter7 = 0; //no high load, clean this flag
        }
    }
}


control filter_flowsz2_flowsz1_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> suspicious) {

    apply{

        bit<32> suspicious_idx0;
        bit<32> suspicious_idx1;
        bit<32> suspicious_idx2;

        hash(suspicious_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)SUSPICIOUS_SIZE);
        hash(suspicious_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)SUSPICIOUS_SIZE);
        hash(suspicious_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)SUSPICIOUS_SIZE);

        if (hdr.ipv4.protocol == TCP_PROTOCOL){
            suspicious.write(suspicious_idx0, 1);
            suspicious.write(suspicious_idx1, 1);
            suspicious.write(suspicious_idx2, 1);
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


control filter_sip_in_suspicious_mitigation1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> suspicious) {

    apply{
        bit<32> suspicious_idx0;
        bit<32> suspicious_idx1;
        bit<32> suspicious_idx2;

        // TODO: use small number
        hash(suspicious_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)SUSPICIOUS_SIZE);
        hash(suspicious_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)SUSPICIOUS_SIZE);
        hash(suspicious_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)SUSPICIOUS_SIZE);

        bit<32> suspicious_val0;
        bit<32> suspicious_val1;
        bit<32> suspicious_val2;

        suspicious.read(suspicious_val0, suspicious_idx0);
        suspicious.read(suspicious_val1, suspicious_idx1);
        suspicious.read(suspicious_val2, suspicious_idx2);

        if (suspicious_val0 == 1 && suspicious_val1 == 1 && suspicious_val2 == 1) {
            meta.mitigation_filter1 = 1;
        } else {
            meta.mitigation_filter1 = 0;
        }
    }
}

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

control ctrl_sync(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                                    in register<bit<32>> victimLks, 
                  in register<bit<32>> victimLks_size, 
                  in register<bit<32>> suspicious, 

                  in register<bit<32>> d_swid) {

    apply{
        bit<32> offset = hdr.sync.offset;

        DEF_VAR_128(victimLks_val)
        READ_REG_128(victimLks, victimLks_val)
        DEF_VAR_128(suspicious_val)
        READ_REG_128(suspicious, suspicious_val)

        d_swid.read(meta.swid, 0);
        if (meta.swid == 3) { // The root
            if (hdr.sync.srcSWUID == 3) { // downstream packets
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_128_OR(hdr.sync.suspicious, suspicious_val)
            }
            // upstream packets
            else {
                bit<32> victimLks_cnt_val;
                victimLks_size.read(victimLks_cnt_val, 0);

                UPDATE_LINKSET_CNT_128(victimLks_cnt_val, victimLks_val, hdr.sync.victimLks);
                victimLks_size.write(0, victimLks_cnt_val);
                UPDATE_REG_BF_128(victimLks, victimLks_val, hdr.sync.victimLks)
                UPDATE_REG_BF_128(suspicious, suspicious_val, hdr.sync.suspicious)
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
                UPDATE_REG_BF_128(suspicious, suspicious_val, hdr.sync.suspicious)
            }
            // sent out from the root, update local states
            else {
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_128_OR(hdr.sync.suspicious, suspicious_val)
            }
        }
    }
}
