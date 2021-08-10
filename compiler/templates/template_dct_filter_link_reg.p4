control filter_FILTER_NAME(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> link_thresh) {

    apply{
        bit<32> thresh = 0;
        link_thresh.read(thresh, (bit<32>)standard_metadata.egress_spec);
        bit<32> real_link_load = meta.LHS >> 16;

        if (real_link_load >= thresh) {
            meta.STAGE_filterPANO_NUM = 1;
        } else {
            meta.STAGE_filterPANO_NUM = 0; //no high load, clean this flag
        }
    }
}
