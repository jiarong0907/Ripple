control filter_FILTER_NAME_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> REG_NAME) {

    apply{

        if (meta.STAGE_filterPANO_NUM == 1) {

            REG_NAME.write(meta.link, 1);
        }
    }
}