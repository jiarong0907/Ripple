control FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    apply{
        if (meta.STAGE_filterPANO_NUM == 1){
            if (meta.KEY >= LOW && meta.KEY <= HIGH){
                meta.STAGE_filterPANO_NUM = 1;
            } else {
                meta.STAGE_filterPANO_NUM = 0;
            }
        }
    }
}
