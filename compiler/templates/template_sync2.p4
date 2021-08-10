
control ctrl_sync(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  parameters
                  in register<bit<32>> d_swid) {

    apply{
        bit<32> offset = hdr.sync.offset;

        DEF_VAR_128(victimLks_val)
        READ_REG_128(victimLks, victimLks_val)
        DEF_VAR_64(malflows1_val)
        READ_REG_64(malflows1, malflows1_val)
        DEF_VAR_64(malflows2_val)
        READ_REG_64(malflows2, malflows2_val)

        d_swid.read(meta.swid, 0);
        if (meta.swid == 3) { // The root
            if (hdr.sync.srcSWUID == 3) { // downstream packets
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_64_OR(hdr.sync.malflows1, malflows1_val)
                SET_HDR_64_OR(hdr.sync.malflows2, malflows2_val)
            }
            // upstream packets
            else {
                bit<32> victimLks_cnt_val;
                victimLks_size.read(victimLks_cnt_val, 0);

                UPDATE_LINKSET_CNT_128(victimLks_cnt_val, victimLks_val, hdr.sync.victimLks);
                victimLks_size.write(0, victimLks_cnt_val);
                UPDATE_REG_BF_128(victimLks, victimLks_val, hdr.sync.victimLks)
                UPDATE_REG_BF_64(malflows1, malflows1_val, hdr.sync.malflows1)
                UPDATE_REG_BF_64(malflows2, malflows2_val, hdr.sync.malflows2)
            }
        }
        // not root
        else {
            // go to the root, set header
            if (hdr.sync.srcSWUID == 3) { // from root
                bit<32> victimLks_cnt_val;
                victimLks_size.read(victimLks_cnt_val, 0);

                UPDATE_LINKSET_CNT_128(victimLks_cnt_val, victimLks_val, hdr.sync.victimLks);
                victimLks_size.write(0, victimLks_cnt_val);

                UPDATE_REG_BF_128(victimLks, victimLks_val, hdr.sync.victimLks)
                UPDATE_REG_BF_64(malflows1, malflows1_val, hdr.sync.malflows1)
                UPDATE_REG_BF_64(malflows2, malflows2_val, hdr.sync.malflows2)
            }
            // sent out from the root, update local states
            else {
                SET_HDR_128_OR(hdr.sync.victimLks, victimLks_val)
                SET_HDR_64_OR(hdr.sync.malflows1, malflows1_val)
                SET_HDR_64_OR(hdr.sync.malflows2, malflows2_val)
            }
        }
    }
}