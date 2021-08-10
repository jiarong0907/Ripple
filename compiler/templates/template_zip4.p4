control zip_input_input2(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> input_name_full_wind,
                  in register<bit<32>> input_name_s0_w0,
                  in register<bit<32>> input_name_s1_w0,
                  in register<bit<32>> input_name_s2_w0,
                  in register<bit<32>> input_name_s0_w1,
                  in register<bit<32>> input_name_s1_w1,
                  in register<bit<32>> input_name_s2_w1,
                  in register<bit<32>> input_name_s0_w2,
                  in register<bit<32>> input_name_s1_w2,
                  in register<bit<32>> input_name_s2_w2,
                  in register<bit<32>> input_name_s0_w3,
                  in register<bit<32>> input_name_s1_w3,
                  in register<bit<32>> input_name_s2_w3) {

    apply{
        // read flow rate before rerouting
        bit<32> input_name_full_wind_val2;
        input_name_full_wind.read(input_name_full_wind_val2, 0);

        bit<32> flowsz2_idx0;
        bit<32> flowsz2_idx1;
        bit<32> flowsz2_idx2;

        hash(flowsz2_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, reg_key, NUM_RAND2}, (bit<16>)reg_size);
        hash(flowsz2_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, reg_key}, (bit<16>)reg_size);
        hash(flowsz2_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {reg_key, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);

        bit<32> flowsz2_val0;
        bit<32> flowsz2_val1;
        bit<32> flowsz2_val2;

        REG_WIND_READ(input_name_s0, input_name_full_wind_val2, flowsz2_val0, flowsz2_idx0)
        REG_WIND_READ(input_name_s1, input_name_full_wind_val2, flowsz2_val1, flowsz2_idx1)
        REG_WIND_READ(input_name_s2, input_name_full_wind_val2, flowsz2_val2, flowsz2_idx2)

        meta.flowsz2_val = (flowsz2_val0 < flowsz2_val1) ? flowsz2_val0 : flowsz2_val1;
        meta.flowsz2_val = (meta.flowsz2_val < flowsz2_val2) ? meta.flowsz2_val : flowsz2_val2;

        // read flow rate after rerouting
        bit<32> input_name_full_wind_val1;
        if (input_name_full_wind_val2>=1){
            input_name_full_wind_val1 = input_name_full_wind_val2-1;
        } else {
            input_name_full_wind_val1 = 3;
        }
        input_name_full_wind.read(input_name_full_wind_val1, 0);

        bit<32> flowsz1_idx0;
        bit<32> flowsz1_idx1;
        bit<32> flowsz1_idx2;

        hash(flowsz1_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, reg_key, NUM_RAND2}, (bit<16>)reg_size);
        hash(flowsz1_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, reg_key}, (bit<16>)reg_size);
        hash(flowsz1_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {reg_key, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);

        bit<32> flowsz1_val0;
        bit<32> flowsz1_val1;
        bit<32> flowsz1_val2;

        REG_WIND_READ(input_name_s0, input_name_full_wind_val1, flowsz1_val0, flowsz1_idx0)
        REG_WIND_READ(input_name_s1, input_name_full_wind_val1, flowsz1_val1, flowsz1_idx1)
        REG_WIND_READ(input_name_s2, input_name_full_wind_val1, flowsz1_val2, flowsz1_idx2)

        meta.flowsz1_val = (flowsz1_val0 < flowsz1_val1) ? flowsz1_val0 : flowsz1_val1;
        meta.flowsz1_val = (meta.flowsz1_val < flowsz1_val2) ? meta.flowsz1_val : flowsz1_val2;
    }
}