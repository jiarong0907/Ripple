
control register_name_prefix_window(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> register_name_prefix_cur_wind,
                  in register<bit<32>> register_name_prefix_cur_wind_pass,
                  in register<bit<32>> register_name_prefix_full_wind,
                  in register<bit<32>> register_name_prefix_clean_wind,
                  in register<bit<32>> register_name_prefix_clean_offset,
                  in register<bit<48>> last_ts) {

    apply{
        bit<32> register_name_prefix_cur_wind_val;
        register_name_prefix_cur_wind.read(register_name_prefix_cur_wind_val, 0);
        bit<32> register_name_prefix_cur_wind_pass_val;
        register_name_prefix_cur_wind_pass.read(register_name_prefix_cur_wind_pass_val, 0);

        if (meta.register_name_prefix_wind_updated == 0 && meta.c_wind_interval > window_size * 1000){
            meta.register_name_prefix_wind_updated = 1;
            last_ts.write(0, meta.this_ts_val);
            register_name_prefix_cur_wind_pass.write(0, register_name_prefix_cur_wind_pass_val + 1);
            register_name_prefix_clean_offset.write(0, 0);
            if (register_name_prefix_cur_wind_val == 0){
                register_name_prefix_cur_wind.write(0, 1);
                register_name_prefix_full_wind.write(0, 0);
                register_name_prefix_clean_wind.write(0, 2);
                register_name_prefix_cur_wind_val = 1;
            } else if (register_name_prefix_cur_wind_val == 1){
                register_name_prefix_cur_wind.write(0, 2);
                register_name_prefix_full_wind.write(0, 1);
                register_name_prefix_clean_wind.write(0, 0);
                register_name_prefix_cur_wind_val = 2;
            } else {
                register_name_prefix_cur_wind.write(0, 0);
                register_name_prefix_full_wind.write(0, 2);
                register_name_prefix_clean_wind.write(0, 1);
                register_name_prefix_cur_wind_val = 0;
            }
        }
    }
}
