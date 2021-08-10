control filter_FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> REG_NAME1_cur_wind_pass,
                  in register<bit<32>> REG_NAME2_cur_wind_pass) {

    apply{
        // classify when at least one window is full
        bit<32> REG_NAME1_cur_wind_pass_val;
        REG_NAME1_cur_wind_pass.read(REG_NAME1_cur_wind_pass_val, 0);
        bit<32> REG_NAME2_cur_wind_pass_val;
        REG_NAME2_cur_wind_pass.read(REG_NAME2_cur_wind_pass_val, 0);

        if (CONDITION && REG_NAME1_cur_wind_pass_val >= 1 && REG_NAME2_cur_wind_pass_val >= 1) {
            meta.STAGE_filterPANO_NUM = 1;
        } else {
            meta.STAGE_filterPANO_NUM = 0; //no high load, clean this flag
        }
    }
}