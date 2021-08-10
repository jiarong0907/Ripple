control FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> RHS) {

    apply{
        if (meta.STAGE_filterPANO_NUM == 1){
            bit<32> linkset_val = 0;
            RHS.read(linkset_val, meta.link);

            if (linkset_val == 0){
                meta.STAGE_filterPANO_NUM = 0;
            }
        }
    }
}
