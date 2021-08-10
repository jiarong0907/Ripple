control read_load(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> d_link_util) {

    apply{
        bit<32> FROM = (meta.swid << 3) + (bit<32>)standard_metadata.egress_spec;
        d_link_util.read(meta.TO, FROM);
    }
}
