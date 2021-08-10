/* -*- P4_16 -*- */
#include <pronet1.p4>
#include "../macro.p4"
#define DROP(); mark_to_drop();

const bit<16> TYPE_IPV4 = 33;
const bit<8> TCP_PROTOCOL = 6;
const bit<8> ICMP_PROTOCOL = 1;
const bit<8> PROBE_PROTOCOL = 254;
const bit<8> SYNC_PROTOCOL = 252;
const bit<32> NUM_RAND1 = 51646229;
const bit<32> NUM_RAND2 = 122420729;
const bit<32> TAU = 524288;
const bit<32> THRESH_UTIL_RESET = 512000;
const bit<32> REDUCE_PKTLEN_TO_FLOWSZ_SIZE = 65535;
const bit<32> MAL_COREMELT_SIZE = 65535;
const bit<32> REDUCE_PKTLEN_TO_FLOWSZ_C_SIZE = 65535;
const bit<32> DISTINCT_SIP_DIP_SPORT_DPORT_SIZE = 65535;
const bit<32> REDUCE_ID_TO_CNT_SIZE = 65535;
const bit<32> MAL_CROSSFIRE_SIZE = 65535;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ppp_t {
    bit<16> pppType;
}

header ipv4_t {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4> dataOffset;
    bit<3> res;
    bit<3> ecn;
    bit<6> ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header probe_t {
    bit<32> seqNo;
    bit<32> util;
    bit<32> dstSWID;
}

header sync_t {
    bit<32> srcSWUID;
    bit<32> seqNo;
    bit<32> offset;
    HDR_FILED_128(victimLks)
    HDR_FILED_64(mal_coremelt)
    HDR_FILED_64(mal_crossfire)
}


struct headers {
    ppp_t 	ppp;
    ipv4_t 	ipv4;
    tcp_t 	tcp;
    probe_t 	probe;
    sync_t 	sync;
}

struct metadata {
    bit<32> sip;
    bit<32> dip;
    bit<16> sport;
    bit<16> dport;
    bit<32> filter;
    bit<32> high_load;
    bit<32> swid;
    bit<32> link;
    bit<32> pktlen;
    bit<32> reroute;
    bit<48> this_ts_val;
    bit<48> d_wind_last_ts_val;
    bit<48> d_wind_interval;
    bit<32> probe_update;
    bit<32> detection_filter1;
    bit<32> classification_filter1_p1;
    bit<32> classification_filter1_p2;
    bit<32> mitigation_filter1;
    bit<32> ip_to_swid;
    bit<48> c_wind_last_ts_p1_val;
    bit<48> c_wind_last_ts_p2_val;
    bit<48> c_wind_interval_p1;
    bit<48> c_wind_interval_p2;
    bit<32> ld;
    bit<32> victimLks_size;
    bit<32> classification1_filter1;
    bit<32> reduce_pktlen_to_flowsz_wind_updated;
    bit<32> reduce_pktlen_to_flowsz_full;
    bit<32> classification2_filter1;
    bit<32> reduce_pktlen_to_flowsz_c_wind_updated;
    bit<32> reduce_pktlen_to_flowsz_c_full;
    bit<32> distinct_sip_dip_sport_dport_wind_updated;
    bit<32> distinct_sip_dip_sport_dport_full;
    bit<32> id;
    bit<32> reduce_id_to_cnt_wind_updated;
    bit<32> reduce_id_to_cnt_full;
    bit<32> mitigation_filter2;
    bit<32> mitigation_filter3;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ppp;
    }

    state parse_ppp {
        packet.extract(hdr.ppp);
        transition select(hdr.ppp.pppType) {
            TYPE_IPV4 : parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TCP_PROTOCOL : parse_tcp;
            SYNC_PROTOCOL : parse_sync;
            PROBE_PROTOCOL : parse_probe;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }

    state parse_probe {
        packet.extract(hdr.probe);
        transition accept;
    }

    state parse_sync {
        packet.extract(hdr.sync);
        transition accept;
    }

}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

#include "./outfunc.p4"
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    register <bit<32>>(1) d_swid;
    register <bit<32>>(65536) link_thresh;
    register <bit<32>>(65536) d_link_util;
    register <bit<48>>(65536) d_link_last_ts;
    register <bit<48>>(1) d_wind_last_ts;
    register <bit<32>>(1024) probe_seqNo;
    register <bit<32>>(1024) best_util;
    register <bit<32>>(1024) best_path;
    register <bit<32>>(1) reroute;
    register <bit<48>>(1) c_wind_last_ts_p1;
    register <bit<48>>(1) c_wind_last_ts_p2;
    register <bit<32>>(512) victimLks;
    register <bit<32>>(1) victimLks_size;
    register <bit<32>>(65536) mal_coremelt;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s0_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s0_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s0_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s1_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s1_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s1_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s2_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s2_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_s2_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_clean_offset;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_cur_wind_pass;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_cur_wind;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_full_wind;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_clean_wind;
    register <bit<32>>(65536) mal_crossfire;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s0_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s0_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s0_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s1_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s1_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s1_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s2_w0;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s2_w1;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_s2_w2;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_clean_offset;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_cur_wind_pass;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_cur_wind;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_full_wind;
    register <bit<32>>(65536) reduce_pktlen_to_flowsz_c_clean_wind;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_w0;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_w1;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_w2;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_clean_offset;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_cur_wind_pass;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_cur_wind;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_full_wind;
    register <bit<32>>(65536) distinct_sip_dip_sport_dport_clean_wind;
    register <bit<32>>(65536) reduce_id_to_cnt_s0_w0;
    register <bit<32>>(65536) reduce_id_to_cnt_s0_w1;
    register <bit<32>>(65536) reduce_id_to_cnt_s0_w2;
    register <bit<32>>(65536) reduce_id_to_cnt_s1_w0;
    register <bit<32>>(65536) reduce_id_to_cnt_s1_w1;
    register <bit<32>>(65536) reduce_id_to_cnt_s1_w2;
    register <bit<32>>(65536) reduce_id_to_cnt_s2_w0;
    register <bit<32>>(65536) reduce_id_to_cnt_s2_w1;
    register <bit<32>>(65536) reduce_id_to_cnt_s2_w2;
    register <bit<32>>(65536) reduce_id_to_cnt_clean_offset;
    register <bit<32>>(65536) reduce_id_to_cnt_cur_wind_pass;
    register <bit<32>>(65536) reduce_id_to_cnt_cur_wind;
    register <bit<32>>(65536) reduce_id_to_cnt_full_wind;
    register <bit<32>>(65536) reduce_id_to_cnt_clean_wind;
    register <bit<32>>(65536) flow_nhop;


/*************************************************************************
****************           set next hop                *******************
*************************************************************************/

    action pkt_drop() {
        DROP();
    }

    action noAction() { }

    action set_nhop(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table set_nhop_tab {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            set_nhop;
            pkt_drop;
        }
        size = 1024;
        default_action = pkt_drop();
    }
	// sync to all ports!
    action set_sync_mcast(bit<16> mcast_id) {
      standard_metadata.mcast_grp = mcast_id;
    }

    table tab_sync_mcast {
        key = {
            hdr.sync.srcSWUID: exact;
        }
        actions = {
          set_sync_mcast;
          pkt_drop;
        }
        default_action = pkt_drop();
    }

    // send to root switch
    action set_sync_nhop(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table tab_sync_nhop {
        key = {
            hdr.sync.srcSWUID: exact;
        }
        actions = {
          set_sync_nhop;
          pkt_drop;
        }
        default_action = pkt_drop();
    }
    // mcast probes to all ports!
    action set_probe_mcast(bit<16> mcast_id) {
      standard_metadata.mcast_grp = mcast_id;
    }

    table tab_probe_mcast {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
          set_probe_mcast;
          pkt_drop;
        }
        default_action = pkt_drop();
    }
    // translate dstIP to the switch number
    action dstIPtoSWID(bit<32> SWID) {
      meta.ip_to_swid = SWID;
    }

    action noAction2() { }

    table tab_dstIPtoSWID {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
          dstIPtoSWID;
          noAction2;
        }
        default_action = noAction2();
    }

    apply {

        if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 0){
            meta.filter = 1;
            meta.detection_filter1 = 1;
            meta.classification_filter1_p1 = 1;
            meta.classification_filter1_p2 = 1;
            meta.mitigation_filter1 = 1;
            meta.classification1_filter1 = 1;
            meta.classification2_filter1 = 1;
            meta.mitigation_filter2 = 1;
            meta.mitigation_filter3 = 1;
        } else {
            meta.filter = 0;
            meta.detection_filter1 = 0;
            meta.classification_filter1_p1 = 0;
            meta.classification_filter1_p2 = 0;
            meta.mitigation_filter1 = 0;
            meta.classification1_filter1 = 0;
            meta.classification2_filter1 = 0;
            meta.mitigation_filter2 = 0;
            meta.mitigation_filter3 = 0;
        }

        if (meta.filter == 1){
            meta.high_load = 1;
            meta.sip = hdr.ipv4.srcAddr;
            meta.dip = hdr.ipv4.dstAddr;
            meta.sport = hdr.tcp.srcPort;
            meta.dport = hdr.tcp.dstPort;
            meta.pktlen = standard_metadata.packet_length;
            meta.this_ts_val = standard_metadata.ingress_global_timestamp;

            d_swid.read(meta.swid, 0);
            reroute.read(meta.reroute, 0);
            set_nhop_tab.apply();
            meta.link = (meta.swid << 3) + (bit<32>)standard_metadata.egress_spec;
            tab_dstIPtoSWID.apply();

            d_wind_last_ts.read(meta.d_wind_last_ts_val, 0);
            if (meta.d_wind_last_ts_val == 0){
                d_wind_last_ts.write(0, standard_metadata.ingress_global_timestamp);
                meta.d_wind_last_ts_val = standard_metadata.ingress_global_timestamp;
            }
            meta.d_wind_interval = meta.this_ts_val - meta.d_wind_last_ts_val;

            c_wind_last_ts_p1.read(meta.c_wind_last_ts_p1_val, 0);
            if (meta.c_wind_last_ts_p1_val == 0){
                c_wind_last_ts_p1.write(0, standard_metadata.ingress_global_timestamp);
                meta.c_wind_last_ts_p1_val = standard_metadata.ingress_global_timestamp;
            }
            meta.c_wind_interval_p1 = meta.this_ts_val - meta.c_wind_last_ts_p1_val;
            c_wind_last_ts_p2.read(meta.c_wind_last_ts_p2_val, 0);
            if (meta.c_wind_last_ts_p2_val == 0){
                c_wind_last_ts_p2.write(0, standard_metadata.ingress_global_timestamp);
                meta.c_wind_last_ts_p2_val = standard_metadata.ingress_global_timestamp;
            }
            meta.c_wind_interval_p2 = meta.this_ts_val - meta.c_wind_last_ts_p2_val;
        }
/*************************************************************************
********************        Detection here       *************************
*************************************************************************/

		if (meta.detection_filter1 == 1) {
            compute_load.apply(hdr, meta, standard_metadata, \
                            d_link_last_ts, \
                            d_link_util);

            read_load.apply(hdr, meta, standard_metadata, \
                            d_link_util);

            if (meta.d_wind_interval > 100 * 1000){
                d_wind_last_ts.write(0, meta.this_ts_val);

                filter_ld_detection1_2.apply(hdr, meta, standard_metadata, \
                            link_thresh);

                if (meta.detection_filter1 == 1){
                    filter_ld_return.apply(hdr, meta, standard_metadata, \
                                victimLks, \
                                victimLks_size);
                }
            }
	 	}


/*************************************************************************
********************     Classification1 here     *************************
*************************************************************************/

		if (meta.classification1_filter1 == 1) {
                filter_victimLks_size_classification11_1.apply(hdr, meta, standard_metadata, \
                            victimLks_size);

	 	}
		if (meta.classification1_filter1 == 1) {
                filter_link_in_victimLks_classification11.apply(hdr, meta, standard_metadata, \
                            victimLks);

	 	}
		if (meta.classification1_filter1 == 1) {

            reduce_pktlen_to_flowsz_window.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_cur_wind,  \
                                reduce_pktlen_to_flowsz_cur_wind_pass,  \
                                reduce_pktlen_to_flowsz_full_wind,  \
                                reduce_pktlen_to_flowsz_clean_wind,  \
                                reduce_pktlen_to_flowsz_clean_offset,  \
                                c_wind_last_ts_p1);

            reduce_pktlen_to_flowsz_update.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_cur_wind,  \
                                reduce_pktlen_to_flowsz_s0_w0, reduce_pktlen_to_flowsz_s1_w0, reduce_pktlen_to_flowsz_s2_w0, \
                                reduce_pktlen_to_flowsz_s0_w1, reduce_pktlen_to_flowsz_s1_w1, reduce_pktlen_to_flowsz_s2_w1, \
                                reduce_pktlen_to_flowsz_s0_w2, reduce_pktlen_to_flowsz_s1_w2, reduce_pktlen_to_flowsz_s2_w2);

            reduce_pktlen_to_flowsz_clean.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_cur_wind_pass, \
                                reduce_pktlen_to_flowsz_clean_wind, \
                                reduce_pktlen_to_flowsz_clean_offset, \
                                reduce_pktlen_to_flowsz_s0_w0, reduce_pktlen_to_flowsz_s1_w0, reduce_pktlen_to_flowsz_s2_w0, \
                                reduce_pktlen_to_flowsz_s0_w1, reduce_pktlen_to_flowsz_s1_w1, reduce_pktlen_to_flowsz_s2_w1, \
                                reduce_pktlen_to_flowsz_s0_w2, reduce_pktlen_to_flowsz_s1_w2, reduce_pktlen_to_flowsz_s2_w2);

            reduce_pktlen_to_flowsz_read.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_full_wind,  \
                                reduce_pktlen_to_flowsz_s0_w0, reduce_pktlen_to_flowsz_s1_w0, reduce_pktlen_to_flowsz_s2_w0, \
                                reduce_pktlen_to_flowsz_s0_w1, reduce_pktlen_to_flowsz_s1_w1, reduce_pktlen_to_flowsz_s2_w1, \
                                reduce_pktlen_to_flowsz_s0_w2, reduce_pktlen_to_flowsz_s1_w2, reduce_pktlen_to_flowsz_s2_w2);

	 	}
		if (meta.classification1_filter1 == 1) {
                filter_flowsz_classification11_4.apply(hdr, meta, standard_metadata, \
                            reduce_pktlen_to_flowsz_cur_wind_pass);

                if (meta.classification1_filter1 == 1){
                    filter_flowsz_return.apply(hdr, meta, standard_metadata, \
                                mal_coremelt);
                }
	 	}


/*************************************************************************
********************     Classification2 here     *************************
*************************************************************************/

		if (meta.classification2_filter1 == 1) {
                filter_victimLks_size_classification21_1.apply(hdr, meta, standard_metadata, \
                            victimLks_size);

	 	}
		if (meta.classification2_filter1 == 1) {
                filter_link_in_victimLks_classification21.apply(hdr, meta, standard_metadata, \
                            victimLks);

	 	}
		if (meta.classification2_filter1 == 1) {

            reduce_pktlen_to_flowsz_c_window.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_c_cur_wind,  \
                                reduce_pktlen_to_flowsz_c_cur_wind_pass,  \
                                reduce_pktlen_to_flowsz_c_full_wind,  \
                                reduce_pktlen_to_flowsz_c_clean_wind,  \
                                reduce_pktlen_to_flowsz_c_clean_offset,  \
                                c_wind_last_ts_p2);

            reduce_pktlen_to_flowsz_c_update.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_c_cur_wind,  \
                                reduce_pktlen_to_flowsz_c_s0_w0, reduce_pktlen_to_flowsz_c_s1_w0, reduce_pktlen_to_flowsz_c_s2_w0, \
                                reduce_pktlen_to_flowsz_c_s0_w1, reduce_pktlen_to_flowsz_c_s1_w1, reduce_pktlen_to_flowsz_c_s2_w1, \
                                reduce_pktlen_to_flowsz_c_s0_w2, reduce_pktlen_to_flowsz_c_s1_w2, reduce_pktlen_to_flowsz_c_s2_w2);

            reduce_pktlen_to_flowsz_c_clean.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_c_cur_wind_pass, \
                                reduce_pktlen_to_flowsz_c_clean_wind, \
                                reduce_pktlen_to_flowsz_c_clean_offset, \
                                reduce_pktlen_to_flowsz_c_s0_w0, reduce_pktlen_to_flowsz_c_s1_w0, reduce_pktlen_to_flowsz_c_s2_w0, \
                                reduce_pktlen_to_flowsz_c_s0_w1, reduce_pktlen_to_flowsz_c_s1_w1, reduce_pktlen_to_flowsz_c_s2_w1, \
                                reduce_pktlen_to_flowsz_c_s0_w2, reduce_pktlen_to_flowsz_c_s1_w2, reduce_pktlen_to_flowsz_c_s2_w2);

            reduce_pktlen_to_flowsz_c_read.apply(hdr, meta, standard_metadata, \
                                reduce_pktlen_to_flowsz_c_full_wind,  \
                                reduce_pktlen_to_flowsz_c_s0_w0, reduce_pktlen_to_flowsz_c_s1_w0, reduce_pktlen_to_flowsz_c_s2_w0, \
                                reduce_pktlen_to_flowsz_c_s0_w1, reduce_pktlen_to_flowsz_c_s1_w1, reduce_pktlen_to_flowsz_c_s2_w1, \
                                reduce_pktlen_to_flowsz_c_s0_w2, reduce_pktlen_to_flowsz_c_s1_w2, reduce_pktlen_to_flowsz_c_s2_w2);

	 	}
		if (meta.classification2_filter1 == 1) {
                filter_flowsz_c_classification21_4.apply(hdr, meta, standard_metadata, \
                            reduce_pktlen_to_flowsz_c_cur_wind_pass);

	 	}
		if (meta.classification2_filter1 == 1) {

            distinct_sip_dip_sport_dport_window.apply(hdr, meta, standard_metadata, \
                                distinct_sip_dip_sport_dport_cur_wind,  \
                                distinct_sip_dip_sport_dport_cur_wind_pass,  \
                                distinct_sip_dip_sport_dport_full_wind,  \
                                distinct_sip_dip_sport_dport_clean_wind,  \
                                distinct_sip_dip_sport_dport_clean_offset,  \
                                c_wind_last_ts_p2);

            distinct_sip_dip_sport_dport_update.apply(hdr, meta, standard_metadata, \
                                distinct_sip_dip_sport_dport_cur_wind,  \
                                distinct_sip_dip_sport_dport_w0, \
                                distinct_sip_dip_sport_dport_w1, \
                                distinct_sip_dip_sport_dport_w2);

            distinct_sip_dip_sport_dport_clean.apply(hdr, meta, standard_metadata, \
                                distinct_sip_dip_sport_dport_cur_wind_pass, \
                                distinct_sip_dip_sport_dport_clean_wind, \
                                distinct_sip_dip_sport_dport_clean_offset, \
                                distinct_sip_dip_sport_dport_w0, \
                                distinct_sip_dip_sport_dport_w1, \
                                distinct_sip_dip_sport_dport_w2);

	 	}
		if (meta.classification2_filter1 == 1) {
            meta.id = 1;
	 	}
		if (meta.classification2_filter1 == 1) {

            reduce_id_to_cnt_window.apply(hdr, meta, standard_metadata, \
                                reduce_id_to_cnt_cur_wind,  \
                                reduce_id_to_cnt_cur_wind_pass,  \
                                reduce_id_to_cnt_full_wind,  \
                                reduce_id_to_cnt_clean_wind,  \
                                reduce_id_to_cnt_clean_offset,  \
                                c_wind_last_ts_p2);

            reduce_id_to_cnt_update.apply(hdr, meta, standard_metadata, \
                                reduce_id_to_cnt_cur_wind,  \
                                reduce_id_to_cnt_s0_w0, reduce_id_to_cnt_s1_w0, reduce_id_to_cnt_s2_w0, \
                                reduce_id_to_cnt_s0_w1, reduce_id_to_cnt_s1_w1, reduce_id_to_cnt_s2_w1, \
                                reduce_id_to_cnt_s0_w2, reduce_id_to_cnt_s1_w2, reduce_id_to_cnt_s2_w2);

            reduce_id_to_cnt_clean.apply(hdr, meta, standard_metadata, \
                                reduce_id_to_cnt_cur_wind_pass, \
                                reduce_id_to_cnt_clean_wind, \
                                reduce_id_to_cnt_clean_offset, \
                                reduce_id_to_cnt_s0_w0, reduce_id_to_cnt_s1_w0, reduce_id_to_cnt_s2_w0, \
                                reduce_id_to_cnt_s0_w1, reduce_id_to_cnt_s1_w1, reduce_id_to_cnt_s2_w1, \
                                reduce_id_to_cnt_s0_w2, reduce_id_to_cnt_s1_w2, reduce_id_to_cnt_s2_w2);

            reduce_id_to_cnt_read.apply(hdr, meta, standard_metadata, \
                                reduce_id_to_cnt_full_wind,  \
                                reduce_id_to_cnt_s0_w0, reduce_id_to_cnt_s1_w0, reduce_id_to_cnt_s2_w0, \
                                reduce_id_to_cnt_s0_w1, reduce_id_to_cnt_s1_w1, reduce_id_to_cnt_s2_w1, \
                                reduce_id_to_cnt_s0_w2, reduce_id_to_cnt_s1_w2, reduce_id_to_cnt_s2_w2);

	 	}
		if (meta.classification2_filter1 == 1) {
                filter_cnt_classification21_8.apply(hdr, meta, standard_metadata, \
                            reduce_id_to_cnt_cur_wind_pass);

                if (meta.classification2_filter1 == 1){
                    filter_cnt_return.apply(hdr, meta, standard_metadata, \
                                mal_crossfire);
                }
	 	}


/*************************************************************************
***********************     Mitigation here     ******************************
*******************************************************************************/

		if (meta.mitigation_filter1 == 1) {
                filter_victimLks_size_mitigation1_1.apply(hdr, meta, standard_metadata, \
                            victimLks_size);

	 	}
		if (meta.mitigation_filter1 == 1) {
                filter_sip_dip_sport_dport_in_mal_coremelt_mitigation1.apply(hdr, meta, standard_metadata, \
                            mal_coremelt);

            if(meta.mitigation_filter1 == 1) {
                DROP()
            }
	 	}
		if (meta.mitigation_filter2 == 1) {
                filter_sip_dip_in_mal_crossfire_mitigation2.apply(hdr, meta, standard_metadata, \
                            mal_crossfire);

            if(meta.mitigation_filter2 == 1) {
                func_sip_dip_reroute_mitigation.apply(hdr, meta, standard_metadata, \
                                flow_nhop, \
                                best_path);
            }
	 	}
/*************************************************************************
**********************    Handle probes here     *************************
*************************************************************************/


        if (hdr.ipv4.protocol == PROBE_PROTOCOL){

            ctrl_probe.apply(hdr, meta, standard_metadata, \
                                d_link_util, \
                                link_thresh, \
                                probe_seqNo, \
                                best_util, \
                                best_path);

            //Multicast the probe
            if (meta.probe_update == 1) {
                tab_probe_mcast.apply();
            } else {
                DROP();
            }
        }
/*************************************************************************
**********************    Sync handler here     *************************
*************************************************************************/

		if (hdr.ipv4.protocol == SYNC_PROTOCOL) {
		    ctrl_sync.apply(hdr, meta, standard_metadata, \
								victimLks, \
								victimLks_size, \
								mal_coremelt, \
								mal_crossfire, \
								d_swid);

		    if (meta.swid == 3){ // switch 3 is the root
		        tab_sync_mcast.apply();
		    } else {
		        tab_sync_nhop.apply();
		    }
		}
    }

}


/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
  apply {
    update_checksum(
      hdr.ipv4.isValid(),
      { hdr.ipv4.version,
        hdr.ipv4.ihl,
        hdr.ipv4.diffserv,
        hdr.ipv4.totalLen,
        hdr.ipv4.identification,
        hdr.ipv4.flags,
        hdr.ipv4.fragOffset,
        hdr.ipv4.ttl,
        hdr.ipv4.protocol,
        hdr.ipv4.srcAddr,
        hdr.ipv4.dstAddr },
        hdr.ipv4.hdrChecksum,
        HashAlgorithm.csum16);
  }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
   apply {
		packet.emit(hdr.ppp);
		packet.emit(hdr.ipv4);
		packet.emit(hdr.tcp);
		packet.emit(hdr.probe);
		packet.emit(hdr.sync);
	}
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
