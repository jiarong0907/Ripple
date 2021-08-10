
control func_name(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata,
                  in register<bit<32>> flow_nhop,
                  in register<bit<32>> best_path) {

    apply{
        bit<32> rerouted_link = 0;
        bit<32> flow_nhop_idx;
        hash(flow_nhop_idx, HashAlgorithm.crc16, (bit<16>)0,
        // Attention: must use meta.sip, meta.dip, consistent with malflows hash
        {NUM_RAND1, key, NUM_RAND2}, (bit<16>)65535);
        flow_nhop.read(rerouted_link, flow_nhop_idx);


        if (rerouted_link != 0) {
            // rerouted previously, follow the same port
            standard_metadata.egress_spec = (bit<9>)rerouted_link;
        } else {
            //have not rerouted, follow least utilize path

            bit<32> best_nhop; //get best next hop
            best_path.read(best_nhop, (bit<32>)meta.ip_to_swid);
            standard_metadata.egress_spec = (bit<9>)best_nhop; //reroute to the best path
            flow_nhop.write(flow_nhop_idx, best_nhop); //record the choice
        }
    }
}
