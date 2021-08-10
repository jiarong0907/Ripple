control filter_FILTER_NAME_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> REG_NAME,
                  in register<bit<32>> REG_NAME_size) {

    apply{

        if (meta.STAGE_filterPANO_NUM == 1) {

            bit<32> prev_status;
            REG_NAME.read(prev_status, meta.link);
            REG_NAME_size.read(meta.REG_NAME_size, 0);

            if (prev_status == 0){
                REG_NAME.write(meta.link, 1);
                meta.REG_NAME_size = meta.REG_NAME_size + 1;
                REG_NAME_size.write(0, meta.REG_NAME_size);
            }
        }
    }
}