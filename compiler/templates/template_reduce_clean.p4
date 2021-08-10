
control register_name_prefix_clean(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> register_name_prefix_cur_wind_pass,
                  in register<bit<32>> register_name_prefix_clean_wind,
                  in register<bit<32>> register_name_prefix_clean_offset,
PARAMS) {

    apply{
        bit<32> register_name_prefix_cur_wind_pass_val;
        register_name_prefix_cur_wind_pass.read(register_name_prefix_cur_wind_pass_val, 0);

        if (register_name_prefix_cur_wind_pass_val >= 2){
            bit<32> register_name_prefix_clean_offset_val;
            register_name_prefix_clean_offset.read(register_name_prefix_clean_offset_val, 0);
            bit<32> register_name_prefix_clean_wind_val;
            register_name_prefix_clean_wind.read(register_name_prefix_clean_wind_val, 0);

            #ifdef  CLEAN_LARGE
                REG_WIND_CLEAN_512(register_name_prefix_s0, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)
                REG_WIND_CLEAN_512(register_name_prefix_s1, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)
                REG_WIND_CLEAN_512(register_name_prefix_s2, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)

                if (register_name_prefix_clean_offset_val + 512 > reg_size){
                    register_name_prefix_clean_offset_val = 0;
                } else {
                    register_name_prefix_clean_offset_val = register_name_prefix_clean_offset_val + 512;
                }
            #else
                REG_WIND_CLEAN(register_name_prefix_s0, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)
                REG_WIND_CLEAN(register_name_prefix_s1, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)
                REG_WIND_CLEAN(register_name_prefix_s2, register_name_prefix_clean_wind_val, register_name_prefix_clean_offset_val)

                if (register_name_prefix_clean_offset_val + 128 > reg_size){
                    register_name_prefix_clean_offset_val = 0;
                } else {
                    register_name_prefix_clean_offset_val = register_name_prefix_clean_offset_val + 128;
                }
            #endif

            register_name_prefix_clean_offset.write(0, register_name_prefix_clean_offset_val);
        }
    }
}
