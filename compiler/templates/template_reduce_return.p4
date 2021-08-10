
control filter_prefix_return(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> reg_name) {

    apply{

        bit<32> reg_name_idx0;
        bit<32> reg_name_idx1;
        bit<32> reg_name_idx2;

        hash(reg_name_idx0, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, KEY, NUM_RAND2}, (bit<16>)reg_size);
        hash(reg_name_idx1, HashAlgorithm.crc16, (bit<32>)0,
        {NUM_RAND1, NUM_RAND2, KEY}, (bit<16>)reg_size);
        hash(reg_name_idx2, HashAlgorithm.crc16, (bit<32>)0,
        {KEY, NUM_RAND1, NUM_RAND2}, (bit<16>)reg_size);

        if (hdr.ipv4.protocol == TCP_PROTOCOL){
            reg_name.write(reg_name_idx0, 1);
            reg_name.write(reg_name_idx1, 1);
            reg_name.write(reg_name_idx2, 1);
        }
    }
}
