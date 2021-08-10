
control filter_prefix(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reg_name) {

    apply{
        bit<32> reg_name_idx0;
        bit<32> reg_name_idx1;
        bit<32> reg_name_idx2;

        // TODO: use small number
        hash(reg_name_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, KEY, NUM_RAND2}, (bit<16>)reg_size);
        hash(reg_name_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, KEY}, (bit<16>)reg_size);
        hash(reg_name_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {KEY, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);

        bit<32> reg_name_val0;
        bit<32> reg_name_val1;
        bit<32> reg_name_val2;

        reg_name.read(reg_name_val0, reg_name_idx0);
        reg_name.read(reg_name_val1, reg_name_idx1);
        reg_name.read(reg_name_val2, reg_name_idx2);

        if (reg_name_val0 == 1 && reg_name_val1 == 1 && reg_name_val2 == 1) {
            meta.filter_name = 1;
        } else {
            meta.filter_name = 0;
        }
    }
}
