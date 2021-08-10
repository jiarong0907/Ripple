
control ctrl_sync(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  parameters
                  in register<bit<32>> d_swid) {

    apply{
        bit<32> offset = hdr.sync.offset;

        DEF_VAR_64(linkset_val)
        READ_REG_64(victimLks, linkset_val)
        DEF_VAR_64(malflows_val)
        READ_REG_64(malflows, malflows_val)

        DEF_VAR_64(input1_val)
        DEF_VAR_64(input2_val)
        DEF_VAR_64(input3_val)

        d_swid.read(meta.swid, 0);
        bit<32> input_ingress_wind;
        input_ingress_full_wind.read(input_ingress_wind, 0);

        if (meta.swid == 3){ // the root must read from the merged register arrays
            READ_REG_64(input_s0, input1_val)
            READ_REG_64(input_s1, input2_val)
            READ_REG_64(input_s2, input3_val)
        } else {
            READ_REG_64_WIND(input_ingress_s0, input_ingress_wind, input1_val)
            READ_REG_64_WIND(input_ingress_s1, input_ingress_wind, input2_val)
            READ_REG_64_WIND(input_ingress_s2, input_ingress_wind, input3_val)
        }


        if (meta.swid == 3) { // The root
            if (hdr.sync.srcSWUID == 3) { // downstream packets
                SET_HDR_64_OR(hdr.sync.victimLks, linkset_val)
                SET_HDR_64_REPALCE(hdr.sync.input1, input1_val)
                SET_HDR_64_REPALCE(hdr.sync.input2, input2_val)
                SET_HDR_64_REPALCE(hdr.sync.input3, input3_val)
                SET_HDR_64_OR(hdr.sync.malflows, malflows_val)
            }
            // upstream packets
            else {
                bit<32> linkset_cnt_val;
                victimLks_size.read(linkset_cnt_val, 0);

                UPDATE_LINKSET_CNT_64(linkset_cnt_val, linkset_val, hdr.sync.victimLks);
                victimLks_size.write(0, linkset_cnt_val);
                UPDATE_REG_BF_64(victimLks, linkset_val, hdr.sync.victimLks)
                REPLACE_REG_SK_64(input_s0, hdr.sync.input1)
                REPLACE_REG_SK_64(input_s1, hdr.sync.input2)
                REPLACE_REG_SK_64(input_s2, hdr.sync.input3)
                UPDATE_REG_BF_64(malflows, malflows_val, hdr.sync.malflows)
            }
        }
        // not root
        else {
            if (hdr.sync.srcSWUID == 3) { // from root
                bit<32> linkset_cnt_val;
                victimLks_size.read(linkset_cnt_val, 0);
                UPDATE_LINKSET_CNT_64(linkset_cnt_val, linkset_val, hdr.sync.victimLks);
                victimLks_size.write(0, linkset_cnt_val);

                UPDATE_REG_BF_64(victimLks, linkset_val, hdr.sync.victimLks)
                UPDATE_REG_BF_64(malflows, malflows_val, hdr.sync.malflows)

                REPLACE_REG_SK_64(input_s0, hdr.sync.input1)
                REPLACE_REG_SK_64(input_s1, hdr.sync.input2)
                REPLACE_REG_SK_64(input_s2, hdr.sync.input3)
            }
            // go to root
            else {
                SET_HDR_64_OR(hdr.sync.victimLks, linkset_val)
                SET_HDR_64_OR(hdr.sync.malflows, malflows_val)

                SET_HDR_64_REPALCE(hdr.sync.input1, input1_val)
                SET_HDR_64_REPALCE(hdr.sync.input2, input2_val)
                SET_HDR_64_REPALCE(hdr.sync.input3, input3_val)
            }
        }
    }
}
