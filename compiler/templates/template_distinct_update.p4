
control register_name_prefix_update(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> register_name_prefix_cur_wind,
                  in register<bit<32>> register_name_prefix_bf_w0,
                  in register<bit<32>> register_name_prefix_bf_w1,
                  in register<bit<32>> register_name_prefix_bf_w2) {

    apply{
        bit<32> register_name_prefix_cur_wind_val;
        register_name_prefix_cur_wind.read(register_name_prefix_cur_wind_val, 0);


        bit<32> register_name_prefix_idx0;
        bit<32> register_name_prefix_idx1;
        bit<32> register_name_prefix_idx2;

        hash(register_name_prefix_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, key, NUM_RAND2}, (bit<16>)reg_size);
        hash(register_name_prefix_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, key}, (bit<16>)reg_size);
        hash(register_name_prefix_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {key, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);


        bit<32> register_name_prefix_val0;
        bit<32> register_name_prefix_val1;
        bit<32> register_name_prefix_val2;

        REG_WIND_READ(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_val0, register_name_prefix_idx0)
        REG_WIND_READ(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_val1, register_name_prefix_idx1)
        REG_WIND_READ(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_val2, register_name_prefix_idx2)

        if ((register_name_prefix_val0 == 0) || (register_name_prefix_val1 == 0) || (register_name_prefix_val2 == 0)) {
            //this is distinct, update the BF to record this
            REG_WIND_WRITE(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_idx0, 1)
            REG_WIND_WRITE(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_idx1, 1)
            REG_WIND_WRITE(register_name_prefix_bf, register_name_prefix_cur_wind_val, register_name_prefix_idx2, 1)
        } else {
            //we already have this in the BF, set the packet to be irrelevant
            meta.STAGE_filterPANO_NUM = 0;
        }
    }
}
