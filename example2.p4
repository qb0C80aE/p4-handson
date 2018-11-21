/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_ARP = 0x0806;
const bit<16> TYPE_IPV4 = 0x0800;

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

// ethernetヘッダ
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

// arpヘッダ
header arp_t {
    bit<16>   hw_type;
    bit<16>   proto_type;
    bit<8>    hw_addr_len;
    bit<8>    proto_addr_len;
    bit<16>   opcode;
    macAddr_t hw_src_addr;
    ip4Addr_t proto_src_addr;
    macAddr_t hw_dst_addr;
    ip4Addr_t proto_dst_addr;
}

// ipv4ヘッダ
header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

// メタデータ
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
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_ARP: parse_arp;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_arp {
        packet.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

}

// 割愛
control verifyChecksum(inout headers hdr, inout metadata meta) { 
    apply {  }
}

control ingress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop();
    }

    // arpもどきのハードコード
    // 入ってきた値をみて存在しないGWのIPを返す
    action arp_sendback() {
        bit<48> hsa;
        bit<32> psa;
        hsa = hdr.arp.hw_src_addr;
        psa = hdr.arp.proto_src_addr;
        hdr.arp.hw_type = 1;
        hdr.arp.proto_type = 0x0800;
        hdr.arp.hw_addr_len = 6;
        hdr.arp.proto_addr_len = 4;
        hdr.arp.opcode = 0x0002;
        if (hdr.arp.proto_src_addr == 0x0a000001) {
            hdr.arp.hw_src_addr = 0x000000000011;
            hdr.arp.proto_src_addr = 0x0a0000fe;
        } else {
            hdr.arp.hw_src_addr = 0x000000000111;
            hdr.arp.proto_src_addr = 0x0a0001fe;
        }
        hdr.arp.hw_dst_addr = hsa;
        hdr.arp.proto_dst_addr = psa;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    // ipv4転送
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    // エントリは固定にする
    table arp {
        key = {
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            arp_sendback;
            NoAction;
        }
        const entries = {
            0xffffffffffff : arp_sendback(); // MACやIPの文字列表記からキャストするやりかたがわからなかった…
        }
        default_action = NoAction();
    }
    
    // forwardに渡すmacはvethのに合わせる
    // エントリは固定にする
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        const entries = {
            0x0a000001 : ipv4_forward(0x1054ff990332, 1);
            0x0a000101 : ipv4_forward(0x1054ff990442, 2);
        }
        default_action = drop();
    }
    
    apply {
        if (hdr.arp.isValid()) {
            arp.apply();
        }
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

control egress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

control computeChecksum(inout headers  hdr, inout metadata meta) {
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

control deparse(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.arp);
        packet.emit(hdr.ipv4);
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
