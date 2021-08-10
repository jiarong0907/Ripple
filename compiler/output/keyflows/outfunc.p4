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

control filter_link_classification1_1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.link == 0) {
            meta.classification_filter1 = 1;
        } else {
            meta.classification_filter1 = 0; //no high load, clean this flag
        }
    }
}


control reduce_pktlen_to_inflowsz_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> reduce_pktlen_to_inflowsz_cur_wind_val;
        reduce_pktlen_to_inflowsz_cur_wind.read(reduce_pktlen_to_inflowsz_cur_wind_val, 0);
        bit<32> reduce_pktlen_to_inflowsz_cur_wind_pass_val;
        reduce_pktlen_to_inflowsz_cur_wind_pass.read(reduce_pktlen_to_inflowsz_cur_wind_pass_val, 0);

        if (meta.reduce_pktlen_to_inflowsz_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.reduce_pktlen_to_inflowsz_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            reduce_pktlen_to_inflowsz_cur_wind_pass.write(0, reduce_pktlen_to_inflowsz_cur_wind_pass_val + 1);
            reduce_pktlen_to_inflowsz_clean_offset.write(0, 0);
            if (reduce_pktlen_to_inflowsz_cur_wind_val == 0){
                reduce_pktlen_to_inflowsz_cur_wind.write(0, 1);
                reduce_pktlen_to_inflowsz_full_wind.write(0, 0);
                reduce_pktlen_to_inflowsz_clean_wind.write(0, 2);
                reduce_pktlen_to_inflowsz_cur_wind_val = 1;
            } else if (reduce_pktlen_to_inflowsz_cur_wind_val == 1){
                reduce_pktlen_to_inflowsz_cur_wind.write(0, 2);
                reduce_pktlen_to_inflowsz_full_wind.write(0, 1);
                reduce_pktlen_to_inflowsz_clean_wind.write(0, 0);
                reduce_pktlen_to_inflowsz_cur_wind_val = 2;
            } else {
                reduce_pktlen_to_inflowsz_cur_wind.write(0, 0);
                reduce_pktlen_to_inflowsz_full_wind.write(0, 2);
                reduce_pktlen_to_inflowsz_clean_wind.write(0, 1);
                reduce_pktlen_to_inflowsz_cur_wind_val = 0;
            }
        }
    }
}

control reduce_pktlen_to_inflowsz_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_inflowsz_cur_wind_val;
        reduce_pktlen_to_inflowsz_cur_wind.read(reduce_pktlen_to_inflowsz_cur_wind_val, 0);


        bit<32> reduce_pktlen_to_inflowsz_idx0;
        bit<32> reduce_pktlen_to_inflowsz_idx1;
        bit<32> reduce_pktlen_to_inflowsz_idx2;

        hash(reduce_pktlen_to_inflowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(reduce_pktlen_to_inflowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(reduce_pktlen_to_inflowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_inflowsz_val0;
        bit<32> reduce_pktlen_to_inflowsz_val1;
        bit<32> reduce_pktlen_to_inflowsz_val2;
        REG_WIND_READ(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_val0, reduce_pktlen_to_inflowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_val1, reduce_pktlen_to_inflowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_val2, reduce_pktlen_to_inflowsz_idx2)


        bit<32> reduce_pktlen_to_inflowsz_cur = (reduce_pktlen_to_inflowsz_val0 < reduce_pktlen_to_inflowsz_val1) ? reduce_pktlen_to_inflowsz_val0 : reduce_pktlen_to_inflowsz_val1;
        reduce_pktlen_to_inflowsz_cur = (reduce_pktlen_to_inflowsz_cur < reduce_pktlen_to_inflowsz_val2) ? reduce_pktlen_to_inflowsz_cur : reduce_pktlen_to_inflowsz_val2;


        //update the reduce value to sketches
        reduce_pktlen_to_inflowsz_cur = reduce_pktlen_to_inflowsz_cur + standard_metadata.packet_length;

        REG_WIND_WRITE(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_idx0, reduce_pktlen_to_inflowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_idx1, reduce_pktlen_to_inflowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_cur_wind_val, reduce_pktlen_to_inflowsz_idx2, reduce_pktlen_to_inflowsz_cur)
    }
}

control reduce_pktlen_to_inflowsz_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_clean_offset,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_inflowsz_cur_wind_pass_val;
        reduce_pktlen_to_inflowsz_cur_wind_pass.read(reduce_pktlen_to_inflowsz_cur_wind_pass_val, 0);

        if (reduce_pktlen_to_inflowsz_cur_wind_pass_val >= 2){
            bit<32> reduce_pktlen_to_inflowsz_clean_offset_val;
            reduce_pktlen_to_inflowsz_clean_offset.read(reduce_pktlen_to_inflowsz_clean_offset_val, 0);
            bit<32> reduce_pktlen_to_inflowsz_clean_wind_val;
            reduce_pktlen_to_inflowsz_clean_wind.read(reduce_pktlen_to_inflowsz_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)

                if (reduce_pktlen_to_inflowsz_clean_offset_val + 512 > REDUCE_PKTLEN_TO_INFLOWSZ_SIZE){
                    reduce_pktlen_to_inflowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_inflowsz_clean_offset_val = reduce_pktlen_to_inflowsz_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_clean_wind_val, reduce_pktlen_to_inflowsz_clean_offset_val)

                if (reduce_pktlen_to_inflowsz_clean_offset_val + 128 > REDUCE_PKTLEN_TO_INFLOWSZ_SIZE){
                    reduce_pktlen_to_inflowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_inflowsz_clean_offset_val = reduce_pktlen_to_inflowsz_clean_offset_val + 128;
                }
            #endif

            reduce_pktlen_to_inflowsz_clean_offset.write(0, reduce_pktlen_to_inflowsz_clean_offset_val);
        }
    }
}

control reduce_pktlen_to_inflowsz_read(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_inflowsz_full_wind_val;
        reduce_pktlen_to_inflowsz_full_wind.read(reduce_pktlen_to_inflowsz_full_wind_val, 0);

        bit<32> reduce_pktlen_to_inflowsz_idx0;
        bit<32> reduce_pktlen_to_inflowsz_idx1;
        bit<32> reduce_pktlen_to_inflowsz_idx2;

        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(reduce_pktlen_to_inflowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(reduce_pktlen_to_inflowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(reduce_pktlen_to_inflowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_inflowsz_val0;
        bit<32> reduce_pktlen_to_inflowsz_val1;
        bit<32> reduce_pktlen_to_inflowsz_val2;

        REG_WIND_READ(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_full_wind_val, reduce_pktlen_to_inflowsz_val0, reduce_pktlen_to_inflowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_full_wind_val, reduce_pktlen_to_inflowsz_val1, reduce_pktlen_to_inflowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_full_wind_val, reduce_pktlen_to_inflowsz_val2, reduce_pktlen_to_inflowsz_idx2)

        meta.reduce_pktlen_to_inflowsz_full = (reduce_pktlen_to_inflowsz_val0 < reduce_pktlen_to_inflowsz_val1) ? reduce_pktlen_to_inflowsz_val0 : reduce_pktlen_to_inflowsz_val1;
        meta.reduce_pktlen_to_inflowsz_full = (meta.reduce_pktlen_to_inflowsz_full < reduce_pktlen_to_inflowsz_val2) ? meta.reduce_pktlen_to_inflowsz_full : reduce_pktlen_to_inflowsz_val2;
    }
}
control filter_link_classification2_4(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.link == 2) {
            meta.classification_filter2 = 1;
        } else {
            meta.classification_filter2 = 0; //no high load, clean this flag
        }
    }
}


control reduce_pktlen_to_egflowsz_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_clean_offset,
                  in register<bit<48>> c_wind_last_ts) {

    apply{
        bit<32> reduce_pktlen_to_egflowsz_cur_wind_val;
        reduce_pktlen_to_egflowsz_cur_wind.read(reduce_pktlen_to_egflowsz_cur_wind_val, 0);
        bit<32> reduce_pktlen_to_egflowsz_cur_wind_pass_val;
        reduce_pktlen_to_egflowsz_cur_wind_pass.read(reduce_pktlen_to_egflowsz_cur_wind_pass_val, 0);

        if (meta.reduce_pktlen_to_egflowsz_wind_updated == 0 && meta.c_wind_interval > 100 * 1000){
            meta.reduce_pktlen_to_egflowsz_wind_updated = 1;
            c_wind_last_ts.write(0, meta.this_ts_val);
            reduce_pktlen_to_egflowsz_cur_wind_pass.write(0, reduce_pktlen_to_egflowsz_cur_wind_pass_val + 1);
            reduce_pktlen_to_egflowsz_clean_offset.write(0, 0);
            if (reduce_pktlen_to_egflowsz_cur_wind_val == 0){
                reduce_pktlen_to_egflowsz_cur_wind.write(0, 1);
                reduce_pktlen_to_egflowsz_full_wind.write(0, 0);
                reduce_pktlen_to_egflowsz_clean_wind.write(0, 2);
                reduce_pktlen_to_egflowsz_cur_wind_val = 1;
            } else if (reduce_pktlen_to_egflowsz_cur_wind_val == 1){
                reduce_pktlen_to_egflowsz_cur_wind.write(0, 2);
                reduce_pktlen_to_egflowsz_full_wind.write(0, 1);
                reduce_pktlen_to_egflowsz_clean_wind.write(0, 0);
                reduce_pktlen_to_egflowsz_cur_wind_val = 2;
            } else {
                reduce_pktlen_to_egflowsz_cur_wind.write(0, 0);
                reduce_pktlen_to_egflowsz_full_wind.write(0, 2);
                reduce_pktlen_to_egflowsz_clean_wind.write(0, 1);
                reduce_pktlen_to_egflowsz_cur_wind_val = 0;
            }
        }
    }
}

control reduce_pktlen_to_egflowsz_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_cur_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_egflowsz_cur_wind_val;
        reduce_pktlen_to_egflowsz_cur_wind.read(reduce_pktlen_to_egflowsz_cur_wind_val, 0);


        bit<32> reduce_pktlen_to_egflowsz_idx0;
        bit<32> reduce_pktlen_to_egflowsz_idx1;
        bit<32> reduce_pktlen_to_egflowsz_idx2;

        hash(reduce_pktlen_to_egflowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);
        hash(reduce_pktlen_to_egflowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);
        hash(reduce_pktlen_to_egflowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_egflowsz_val0;
        bit<32> reduce_pktlen_to_egflowsz_val1;
        bit<32> reduce_pktlen_to_egflowsz_val2;
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_val0, reduce_pktlen_to_egflowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_val1, reduce_pktlen_to_egflowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_val2, reduce_pktlen_to_egflowsz_idx2)


        bit<32> reduce_pktlen_to_egflowsz_cur = (reduce_pktlen_to_egflowsz_val0 < reduce_pktlen_to_egflowsz_val1) ? reduce_pktlen_to_egflowsz_val0 : reduce_pktlen_to_egflowsz_val1;
        reduce_pktlen_to_egflowsz_cur = (reduce_pktlen_to_egflowsz_cur < reduce_pktlen_to_egflowsz_val2) ? reduce_pktlen_to_egflowsz_cur : reduce_pktlen_to_egflowsz_val2;


        //update the reduce value to sketches
        reduce_pktlen_to_egflowsz_cur = reduce_pktlen_to_egflowsz_cur + standard_metadata.packet_length;

        REG_WIND_WRITE(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_idx0, reduce_pktlen_to_egflowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_idx1, reduce_pktlen_to_egflowsz_cur)
        REG_WIND_WRITE(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_cur_wind_val, reduce_pktlen_to_egflowsz_idx2, reduce_pktlen_to_egflowsz_cur)
    }
}

control reduce_pktlen_to_egflowsz_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_clean_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_clean_offset,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_egflowsz_cur_wind_pass_val;
        reduce_pktlen_to_egflowsz_cur_wind_pass.read(reduce_pktlen_to_egflowsz_cur_wind_pass_val, 0);

        if (reduce_pktlen_to_egflowsz_cur_wind_pass_val >= 2){
            bit<32> reduce_pktlen_to_egflowsz_clean_offset_val;
            reduce_pktlen_to_egflowsz_clean_offset.read(reduce_pktlen_to_egflowsz_clean_offset_val, 0);
            bit<32> reduce_pktlen_to_egflowsz_clean_wind_val;
            reduce_pktlen_to_egflowsz_clean_wind.read(reduce_pktlen_to_egflowsz_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)
                REG_WIND_CLEAN_512(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)

                if (reduce_pktlen_to_egflowsz_clean_offset_val + 512 > REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE){
                    reduce_pktlen_to_egflowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_egflowsz_clean_offset_val = reduce_pktlen_to_egflowsz_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)
                REG_WIND_CLEAN(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_clean_wind_val, reduce_pktlen_to_egflowsz_clean_offset_val)

                if (reduce_pktlen_to_egflowsz_clean_offset_val + 128 > REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE){
                    reduce_pktlen_to_egflowsz_clean_offset_val = 0;
                } else {
                    reduce_pktlen_to_egflowsz_clean_offset_val = reduce_pktlen_to_egflowsz_clean_offset_val + 128;
                }
            #endif

            reduce_pktlen_to_egflowsz_clean_offset.write(0, reduce_pktlen_to_egflowsz_clean_offset_val);
        }
    }
}

control reduce_pktlen_to_egflowsz_read(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w2) {

    apply{
        bit<32> reduce_pktlen_to_egflowsz_full_wind_val;
        reduce_pktlen_to_egflowsz_full_wind.read(reduce_pktlen_to_egflowsz_full_wind_val, 0);

        bit<32> reduce_pktlen_to_egflowsz_idx0;
        bit<32> reduce_pktlen_to_egflowsz_idx1;
        bit<32> reduce_pktlen_to_egflowsz_idx2;

        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(reduce_pktlen_to_egflowsz_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);
        hash(reduce_pktlen_to_egflowsz_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);
        hash(reduce_pktlen_to_egflowsz_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_EGFLOWSZ_SIZE);


        bit<32> reduce_pktlen_to_egflowsz_val0;
        bit<32> reduce_pktlen_to_egflowsz_val1;
        bit<32> reduce_pktlen_to_egflowsz_val2;

        REG_WIND_READ(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_full_wind_val, reduce_pktlen_to_egflowsz_val0, reduce_pktlen_to_egflowsz_idx0)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_full_wind_val, reduce_pktlen_to_egflowsz_val1, reduce_pktlen_to_egflowsz_idx1)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_full_wind_val, reduce_pktlen_to_egflowsz_val2, reduce_pktlen_to_egflowsz_idx2)

        meta.reduce_pktlen_to_egflowsz_full = (reduce_pktlen_to_egflowsz_val0 < reduce_pktlen_to_egflowsz_val1) ? reduce_pktlen_to_egflowsz_val0 : reduce_pktlen_to_egflowsz_val1;
        meta.reduce_pktlen_to_egflowsz_full = (meta.reduce_pktlen_to_egflowsz_full < reduce_pktlen_to_egflowsz_val2) ? meta.reduce_pktlen_to_egflowsz_full : reduce_pktlen_to_egflowsz_val2;
    }
}
control filter_link_classification3_7(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.link == 2) {
            meta.classification_filter3 = 1;
        } else {
            meta.classification_filter3 = 0; //no high load, clean this flag
        }
    }
}


control zip_inflowsz_egflowsz(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_full_wind,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_full_wind,
                  in register<bit<32>> inflowsz_s0,
                  in register<bit<32>> inflowsz_s1,
                  in register<bit<32>> inflowsz_s2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w0,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w1,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s0_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s1_w2,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_s2_w2) {

    apply{
        //hash the zip key
        bit<32> zip_idx0;
        bit<32> zip_idx1;
        bit<32> zip_idx2;
        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(zip_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(zip_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);
        hash(zip_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)REDUCE_PKTLEN_TO_INFLOWSZ_SIZE);

        //read the first stream using zip key
        bit<32> inflowsz_val0;
        bit<32> inflowsz_val1;
        bit<32> inflowsz_val2;
        // inflow counters synced by probes are always stored here
        inflowsz_s0.read(inflowsz_val0, zip_idx0);
        inflowsz_s1.read(inflowsz_val1, zip_idx1);
        inflowsz_s2.read(inflowsz_val2, zip_idx2);

        meta.inflowsz_val = (inflowsz_val0 < inflowsz_val1) ? inflowsz_val0 : inflowsz_val1;
        meta.inflowsz_val = (meta.inflowsz_val < inflowsz_val2) ? meta.inflowsz_val : inflowsz_val2;

        //read the second stream using zip key
        bit<32> reduce_pktlen_to_egflowsz_full_wind_val;
        reduce_pktlen_to_egflowsz_full_wind.read(reduce_pktlen_to_egflowsz_full_wind_val, 0);

        bit<32> egflowsz_val0;
        bit<32> egflowsz_val1;
        bit<32> egflowsz_val2;

        REG_WIND_READ(reduce_pktlen_to_egflowsz_s0, reduce_pktlen_to_egflowsz_full_wind_val, egflowsz_val0, zip_idx0)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s1, reduce_pktlen_to_egflowsz_full_wind_val, egflowsz_val1, zip_idx1)
        REG_WIND_READ(reduce_pktlen_to_egflowsz_s2, reduce_pktlen_to_egflowsz_full_wind_val, egflowsz_val2, zip_idx2)
        // egflowsz_s0.read(egflowsz_val0, zip_idx0);
        // egflowsz_s1.read(egflowsz_val1, zip_idx1);
        // egflowsz_s2.read(egflowsz_val2, zip_idx2);

        meta.egflowsz_val = (egflowsz_val0 < egflowsz_val1) ? egflowsz_val0 : egflowsz_val1;
        meta.egflowsz_val = (meta.egflowsz_val < egflowsz_val2) ? meta.egflowsz_val : egflowsz_val2;
    }
}
control filter_inflowsz_egflowsz_classification3_9(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reduce_pktlen_to_inflowsz_cur_wind_pass,
                  in register<bit<32>> reduce_pktlen_to_egflowsz_cur_wind_pass) {

    apply{
        // classify when at least one window is full
        bit<32> reduce_pktlen_to_inflowsz_cur_wind_pass_val;
        reduce_pktlen_to_inflowsz_cur_wind_pass.read(reduce_pktlen_to_inflowsz_cur_wind_pass_val, 0);
        bit<32> reduce_pktlen_to_egflowsz_cur_wind_pass_val;
        reduce_pktlen_to_egflowsz_cur_wind_pass.read(reduce_pktlen_to_egflowsz_cur_wind_pass_val, 0);

        if (meta.inflowsz_val - meta.egflowsz_val > 500 && meta.inflowsz_val > meta.egflowsz_val && reduce_pktlen_to_inflowsz_cur_wind_pass_val >= 1 && reduce_pktlen_to_egflowsz_cur_wind_pass_val >= 1) {
            meta.classification_filter3 = 1;
        } else {
            meta.classification_filter3 = 0; //no high load, clean this flag
        }
    }
}

control filter_ipset_sip_classification3(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.classification_filter3 == 1){
            if (meta.sip >= 16908288 && meta.sip <= 16973823){
                meta.classification_filter3 = 1;
            } else {
                meta.classification_filter3 = 0;
            }
        }
    }
}


control filter_sip_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> keyflows) {

    apply{

        bit<32> keyflows_idx0;
        bit<32> keyflows_idx1;
        bit<32> keyflows_idx2;

        hash(keyflows_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.sip, NUM_RAND2}, (bit<16>)KEYFLOWS_SIZE);
        hash(keyflows_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.sip}, (bit<16>)KEYFLOWS_SIZE);
        hash(keyflows_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.sip, NUM_RAND1, NUM_RAND2}, (bit<16>)KEYFLOWS_SIZE);

        if (hdr.ipv4.protocol == TCP_PROTOCOL){
            keyflows.write(keyflows_idx0, 1);
            keyflows.write(keyflows_idx1, 1);
            keyflows.write(keyflows_idx2, 1);
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

control filter_link_mitigation1_2(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.link != 2) {
            meta.mitigation_filter1 = 1;
        } else {
            meta.mitigation_filter1 = 0; //no high load, clean this flag
        }
    }
}


control filter_dip_in_keyflows_mitigation1(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> keyflows) {

    apply{
        bit<32> keyflows_idx0;
        bit<32> keyflows_idx1;
        bit<32> keyflows_idx2;

        // TODO: use small number
        hash(keyflows_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, meta.dip, NUM_RAND2}, (bit<16>)KEYFLOWS_SIZE);
        hash(keyflows_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, meta.dip}, (bit<16>)KEYFLOWS_SIZE);
        hash(keyflows_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {meta.dip, NUM_RAND1, NUM_RAND2}, (bit<16>)KEYFLOWS_SIZE);

        bit<32> keyflows_val0;
        bit<32> keyflows_val1;
        bit<32> keyflows_val2;

        keyflows.read(keyflows_val0, keyflows_idx0);
        keyflows.read(keyflows_val1, keyflows_idx1);
        keyflows.read(keyflows_val2, keyflows_idx2);

        if (keyflows_val0 == 1 && keyflows_val1 == 1 && keyflows_val2 == 1) {
            meta.mitigation_filter1 = 1;
        } else {
            meta.mitigation_filter1 = 0;
        }
    }
}

control func_dip_reroute_mitigation(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> flow_nhop,
                  in register<bit<32>> best_path) {

    apply{
        bit<32> rerouted_link = 0;
        bit<32> flow_nhop_idx;
        hash(flow_nhop_idx, HashAlgorithm.crc16, (bit<16>)0,
        // Attention: must use meta.sip, meta.dip, consistent with malflows hash
        {NUM_RAND1, meta.dip, NUM_RAND2}, (bit<16>)65535);
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
                  in register<bit<32>> keyflows, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_full_wind, 
                  in register<bit<32>> inflowsz_s0, 
                  in register<bit<32>> inflowsz_s1, 
                  in register<bit<32>> inflowsz_s2, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w0, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w0, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w0, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w1, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w1, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w1, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s0_w2, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s1_w2, 
                  in register<bit<32>> reduce_pktlen_to_inflowsz_s2_w2, 
                  in register<bit<32>> d_swid) {

    apply{
        bit<32> offset = hdr.sync.offset;

        DEF_VAR_64(linkset_val)
        READ_REG_64(victimLks, linkset_val)
        DEF_VAR_64(keyflows_val)
        READ_REG_64(keyflows, keyflows_val)

        DEF_VAR_64(inflowsz1_val)
        DEF_VAR_64(inflowsz2_val)
        DEF_VAR_64(inflowsz3_val)

        d_swid.read(meta.swid, 0);
        bit<32> reduce_pktlen_to_inflowsz_wind;
        reduce_pktlen_to_inflowsz_full_wind.read(reduce_pktlen_to_inflowsz_wind, 0);

        if (meta.swid == 3){ // the root must read from the merged register arrays
            READ_REG_64(inflowsz_s0, inflowsz1_val)
            READ_REG_64(inflowsz_s1, inflowsz2_val)
            READ_REG_64(inflowsz_s2, inflowsz3_val)
        } else {
            READ_REG_64_WIND(reduce_pktlen_to_inflowsz_s0, reduce_pktlen_to_inflowsz_wind, inflowsz1_val)
            READ_REG_64_WIND(reduce_pktlen_to_inflowsz_s1, reduce_pktlen_to_inflowsz_wind, inflowsz2_val)
            READ_REG_64_WIND(reduce_pktlen_to_inflowsz_s2, reduce_pktlen_to_inflowsz_wind, inflowsz3_val)
        }


        if (meta.swid == 3) { // The root
            if (hdr.sync.srcSWUID == 3) { // downstream packets
                SET_HDR_64_OR(hdr.sync.victimLks, linkset_val)
                SET_HDR_64_REPALCE(hdr.sync.inflowsz1, inflowsz1_val)
                SET_HDR_64_REPALCE(hdr.sync.inflowsz2, inflowsz2_val)
                SET_HDR_64_REPALCE(hdr.sync.inflowsz3, inflowsz3_val)
                SET_HDR_64_OR(hdr.sync.keyflows, keyflows_val)
            }
            // upstream packets
            else {
                bit<32> linkset_cnt_val;
                victimLks_size.read(linkset_cnt_val, 0);

                UPDATE_LINKSET_CNT_64(linkset_cnt_val, linkset_val, hdr.sync.victimLks);
                victimLks_size.write(0, linkset_cnt_val);
                UPDATE_REG_BF_64(victimLks, linkset_val, hdr.sync.victimLks)
                REPLACE_REG_SK_64(inflowsz_s0, hdr.sync.inflowsz1)
                REPLACE_REG_SK_64(inflowsz_s1, hdr.sync.inflowsz2)
                REPLACE_REG_SK_64(inflowsz_s2, hdr.sync.inflowsz3)
                UPDATE_REG_BF_64(keyflows, keyflows_val, hdr.sync.keyflows)
            }
        }
        // not root
        else {
            if (hdr.sync.srcSWUID == 3) { // from root
                bit<32> linkset_cnt_val;
                victimLks_size.read(linkset_cnt_val, 0);
                UPDATE_LINKSET_CNT_64(linkset_cnt_val, linkset_val, hdr.sync.victimLks);
                victimLks_size.write(0, linkset_cnt_val);

                UPDATE_REG_BF_64(victimLks, linkset_val, hdr.sync.victimLks)
                UPDATE_REG_BF_64(keyflows, keyflows_val, hdr.sync.keyflows)

                REPLACE_REG_SK_64(inflowsz_s0, hdr.sync.inflowsz1)
                REPLACE_REG_SK_64(inflowsz_s1, hdr.sync.inflowsz2)
                REPLACE_REG_SK_64(inflowsz_s2, hdr.sync.inflowsz3)
            }
            // go to root
            else {
                SET_HDR_64_OR(hdr.sync.victimLks, linkset_val)
                SET_HDR_64_OR(hdr.sync.keyflows, keyflows_val)

                SET_HDR_64_REPALCE(hdr.sync.inflowsz1, inflowsz1_val)
                SET_HDR_64_REPALCE(hdr.sync.inflowsz2, inflowsz2_val)
                SET_HDR_64_REPALCE(hdr.sync.inflowsz3, inflowsz3_val)
            }
        }
    }
}
