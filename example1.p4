/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

// ethernetヘッダ
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

// メタデータ
// 出力ポート決定などはメタデータを使うことになるので、以下を読んでおく。(そのへんはstandard_metadataに入ってくる)
// https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md
struct metadata {
}

// ヘッダスタック
struct headers {
    ethernet_t   ethernet;
    arp_t        arp;
    ipv4_t       ipv4;
}

// parser
parser parse(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    // parser=状態遷移機械
    // extractで抽出しながらselectでマッチングを行い、状態遷移していく
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        transition accept;
    }
}

// 割愛
control verifyChecksum(inout headers hdr, inout metadata meta) { 
    apply {  }
}

// ingress match/action
control ingress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    // 全部broadcast
    action broadcast() {
        standard_metadata.mcast_grp = 1;
    }

    // エントリは固定にする
    table bcast {
        default_action = broadcast;
    }
    
    apply {
        if (hdr.ethernet.isValid()) {
            bcast.apply();
        }
    }
}

control egress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

control computeChecksum(inout headers  hdr, inout metadata meta) {
    apply {  }
}

control deparse(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
    }
}

V1Switch(
parse(),
verifyChecksum(),
ingress(),
egress(),
computeChecksum(),
deparse()
) main;
