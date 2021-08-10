control filter_FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> REG_NAME) {

    apply{
        REG_NAME.read(meta.REG_NAME, 0);
        if (CONDITION) {
            meta.STAGE_filterPANO_NUM = 1;
        } else {
            meta.STAGE_filterPANO_NUM = 0; //no high load, clean this flag
        }
    }
}