
control zip_input1_input2(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> input1_name_full_wind,
                  in register<bit<32>> input2_name_full_wind,
                  in register<bit<32>> input1_s0,
                  in register<bit<32>> input1_s1,
                  in register<bit<32>> input1_s2,
                  in register<bit<32>> input2_name_s0_w0,
                  in register<bit<32>> input2_name_s1_w0,
                  in register<bit<32>> input2_name_s2_w0,
                  in register<bit<32>> input2_name_s0_w1,
                  in register<bit<32>> input2_name_s1_w1,
                  in register<bit<32>> input2_name_s2_w1,
                  in register<bit<32>> input2_name_s0_w2,
                  in register<bit<32>> input2_name_s1_w2,
                  in register<bit<32>> input2_name_s2_w2) {

    apply{
        //hash the zip key
        bit<32> zip_idx0;
        bit<32> zip_idx1;
        bit<32> zip_idx2;
        // TODO: use small hash table, otherwise the clean is not fast enough
        hash(zip_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, reg_key, NUM_RAND2}, (bit<16>)reg_size);
        hash(zip_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, reg_key}, (bit<16>)reg_size);
        hash(zip_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {reg_key, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);

        //read the first stream using zip key
        bit<32> input1_val0;
        bit<32> input1_val1;
        bit<32> input1_val2;
        // inflow counters synced by probes are always stored here
        input1_s0.read(input1_val0, zip_idx0);
        input1_s1.read(input1_val1, zip_idx1);
        input1_s2.read(input1_val2, zip_idx2);

        meta.input1_val = (input1_val0 < input1_val1) ? input1_val0 : input1_val1;
        meta.input1_val = (meta.input1_val < input1_val2) ? meta.input1_val : input1_val2;

        //read the second stream using zip key
        bit<32> input2_name_full_wind_val;
        input2_name_full_wind.read(input2_name_full_wind_val, 0);

        bit<32> input2_val0;
        bit<32> input2_val1;
        bit<32> input2_val2;

        REG_WIND_READ(input2_name_s0, input2_name_full_wind_val, input2_val0, zip_idx0)
        REG_WIND_READ(input2_name_s1, input2_name_full_wind_val, input2_val1, zip_idx1)
        REG_WIND_READ(input2_name_s2, input2_name_full_wind_val, input2_val2, zip_idx2)
        // input2_s0.read(input2_val0, zip_idx0);
        // input2_s1.read(input2_val1, zip_idx1);
        // input2_s2.read(input2_val2, zip_idx2);

        meta.input2_val = (input2_val0 < input2_val1) ? input2_val0 : input2_val1;
        meta.input2_val = (meta.input2_val < input2_val2) ? meta.input2_val : input2_val2;
    }
}
