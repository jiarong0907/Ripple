control FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> REG) {

    apply{
        if (meta.STAGE_filterPANO_NUM == 1){
            bit<32> empty_val = 0;
            REG.read(empty_val, 0);

            if (empty_val == 0){
                meta.STAGE_filterPANO_NUM = 1;
            } else {
                meta.STAGE_filterPANO_NUM = 0;
            }
        }
    }
}
