# P4ハンズオン(1)

## P4とは

[Programming Protocol-Independent Packet Processors](https://www.sigcomm.org/sites/default/files/ccr/papers/2014/July/0000000-0000004.pdf)の略。  
ネットワーク機器でパケットを受信して処理する部分(d-plane)を記述できる高位言語。  
特定のプロトコルに依存せず、また、ハードウェアの細かい実装差異より上の共通言語で、独自にパケット処理を記述できる。  

### 「特定のプロトコルに依存しない」「独自にパケット処理を記述できる」の意味

大体以下。

* ヘッダ構造を自分で自由に定義できる
* そのヘッダのパーサ、デパーサを定義できる
* そのヘッダのフィールドに対するmatchを定義できる
* matchに対するactionを定義できる(actionで使えるもの(primitive)はincludeした.p4に定義されてたりする。v1model.p4、psa.p4など。)
(v1modelかPSAかでpipelineは微妙に違う)

実装範囲で理解するなら、pioとtrema applicationを自分で書くイメージ（厳密にはかなり違うけど、することとしては）。

### Openflowとの違い

Openflowはその仕様バージョンとヘッダフィールドが密結合している。  
つまり、ヘッダやフィールドを増やすにはOpenflowのバージョンを上げて装置も対応させるしかないし、使っていないものを省くこともできない。  
P4はその部分の詳細仕様を誰も決めていなくてもまず自分で定義し始めることができるので、迅速であり無駄もない。  

ペイロードは基本的に見ない。
p4cの構成はフロントエンドやバックエンドなどのモジュールに分かれている。詳しくは[こちら](https://p4.org/assets/p4-ws-2017-p4-compiler.pdf)。
要するにLLVMみたなものだと思えば良く、LLVMベースにすることに関しては[それっぽい提案](http://lists.llvm.org/pipermail/llvm-dev/2018-March/121736.html)もある。

### 嬉しい部分

* ASICは異常に開発に時間とコストが掛かるが、P4があると新しいプロトコルの対応を自分で迅速に書いて試す事が出来る
* 今までCPUで行っていた処理もASICで実装できるため、大量にトラフィックを捌きながら色々な事ができる
* ファイルのモジュール化などで共通処理を使える

### P4言語仕様

現状[P4-14](https://p4.org/p4-spec/p4-14/v1.0.4/tex/p4.pdf)と[P4-16](https://p4.org/p4-spec/docs/P4-16-v1.0.0-spec.html)の2つが存在し、並行でメンテナンスされている。  
サポートされているハードウェアはP414が多いが、使い勝手としてはP4-16のほうがより抽象化されていてC言語に近く、ハードルが低い(多分)。  
なお、今回のハンズオンはP4-16で書く。  

言語仕様に互換がなく、P4-16で書きたいがサンプルをググるとP4-14が出てきて面倒ということもよくあるが、P4-14からP4-16に変換することもできる(試してない)。  
header定義からして書き方が違うため、ファイルを開いたら大体すぐどちらのバージョンか判断できる。  
shebangのような感じでバージョンを指定できるっぽい。  

### P4を動かす流れ

1. d-planeのp4プログラムを準備する(*.p4)。記述内容は大まかに、ヘッダ定義、parser、ingress、egress、deparser。ファイル分割してincludeも出来る。
2. p4cでコンパイルする。ターゲットを変更する場合、バックエンド(-b)を指定してターゲットに合わせたものを選ぶ。d-plane runtimeファイル(フォーマット選べる？)ができる。
3. ターゲットで出力ファイルを読み込んで動かす。BMv2の場合はjsonファイル。

### コントローラとスイッチの間

今回のハンズオンではThriftAPIでスイッチを操作することになるが、  
コントローラとスイッチの連携は[P4Runtime](https://p4.org/assets/P4_D2_East_2018_02_p4runtime.pdf)で規格化されてきている。  
コントローラフレームワークとして[PI](https://github.com/p4lang/PI)が存在する。  
P4RuntimeではgRPCを使うようになっていくらしい。
[このへん](https://github.com/p4lang/PI/issues/330)を見ると、grpc版(with pi)でビルドした場合、grpcでのCLIはない(実際ビルドしてもCLIは無い)ので、プログラムからエントリ操作が必要。  

プログラムを目的にしていないのであれば、simple_switch_CLI等を使うほうが恐らく簡単。

### テーブルエントリ

スイッチ単体で固定エントリをいれておくことも出来(*.p4にentriesで記述可能)、今回は固定にする。

### スイッチの実装

色々なベンダが色々なものを出している。  
とりあえず試したいだけなら[BMv2](https://github.com/p4lang/behavioral-model)(Behavioir Model v2)が便利。OVSなどと違って性能は出ないので、機能確認くらい。  
BMv2は[v1model](https://cs344-stanford.github.io/deliverables/p4-mininet/)というスイッチアーキテクチャをもっていて、  
これに従って動くアーキテクチャは[いくつかサンプル](https://github.com/p4lang/behavioral-model/tree/master/targets)がある。  
P4-14、P4-16で書くことができて、simple_switchがスタンダードなやつらしい。  
これとは別に、P4-16では[PSA](https://p4.org/p4-spec/docs/PSA-v1.0.0.html)というアーキテクチャがあり、現在実装中。Pilelineもv1modelと違っていて、ingress deparserやegress parserがあったりする。  

Openflowのようにデータをコントロールプレーンに渡すのはDigestを使う。  
P4-14では、https://github.com/p4lang/behavioral-model/tree/master/targets/l2_switch
などにあるように、例えばラーニングは[switch.h](https://github.com/p4lang/behavioral-model/blob/master/include/bm/bm_sim/switch.h)で定義されたインタフェースを使っている。  
先述したようにP4-16には[PSA](https://p4.org/p4-spec/docs/PSA.html)があるがこれは標準ライブラリ的なのもあるらしく、そこにDigestを始め[色々](https://github.com/p4lang/p4-spec/blob/master/p4-16/psa/psa.p4)機能が定義されている。ラーニングの例は[こちら](https://github.com/p4lang/p4-spec/blob/master/p4-16/psa/examples/psa-example-digest.p4)。

### p4プログラムの記述内容

多分ソース読んだほうが早い。  
先述したとおり、v1modelかPSAかで微妙に違う。例えばPSAにはingress deparserとegress parserなどがあったりする。

* header
  * パケットにどんなヘッダが書かれてるか
* parser
  * どのヘッダをどの順番で解析するか
* ingress/egress (入ってきたパケット1つについて/出て行くパケットそれぞれについて)
  * table
    * match
      * どこが一致したら
    * action
      * 何をするか
* deparser
  * どうヘッダを組み立てるか

特殊なものとしてmetadataがあるが、これはパケット処理に付随するランタイムデータのようなもの。大体は参照するデータだが一部は設定によって動作の決定を行うものがあって、例えば出力先決定などはintrinsic metadataのegress_specを設定することで行う。  
正確には、P4_14であればingressでegress specを決めて、queueでそのspecを見てegressに向けたパケットを作り、という流れらしい。  
フィールドがたくさんあるので詳しくは[これ](https://p4.org/p4-spec/p4-14/v1.0.4/tex/p4.pdf)を参照。

### 記述できない事

* ポインタ
* ループ
* 再帰
  * parserに関しては可能(でないと入れ子ヘッダが処理できない。ただし、実機が対応しているかは別問題。)
* 浮動小数点処理

基本はif elseで条件マッチした、しないを並べるようなもので、それに特化しているとも言える。  
これ以外がしたい場合、他の言語等との組み合わせが必要らしい(試してない)。

## 記述と実行

書いて動かしたほうが早いので、実際に動かす。  
留意点として、そもそもプロトコルの中身を知らないと非常に辛い。  
自分の使おうとしてるプロトコルには何が含まれてるのか(ヘッダフォーマット等)、を知るのが先。

### 今回やろうとしている事

ググるとmininetを使う例が多く、チュートリアルも例に漏れずだが、特にmininetである必要はない。 
色々使うと実体が余計にわかりにくくなるので、シンプルにnetnsとvethで動作を理解する。  
BMv2の実体として、NICとして見えるものを掴んでパケット処理するので、試すだけであればそれで十分だったりする。

#### 実施例1

damn hubを作る。  
learning switchは外部プロセスとのdigest連携になるが、時間があれば。

```
物理：
[host1(netns)-veth12]-[veth11-simple_switch-veth21]-[veth22-host2(netns)]

論理：
[10.0.0.1/24]-[simple_switch]-[10.0.0.2/24]
```

#### 実施例2

ルーティング？  
物理？的には間にスイッチが１つ挟まっただけだが、veth12とveth22は異なるサブネットで、間でルーティングされるとする。  
これは[tutorialにもあるbasic](https://github.com/p4lang/tutorials/tree/master/exercises/basic)と大体同じ構成だが、そちらはarp処理がなく静的arpエントリが必要であるため、もう少しおもしろくなるようハードコードでいいのでarpもどうにかした上でpingが通るようにする。  

```
物理：
[host3(netns)-veth32]-[veth31-simple_switch-veth41]-[veth42-host4(netns)]

論理：
[10.0.0.1/24]-[10.0.0.254/24 simple_switch 10.0.1.254/24]-[10.0.1.1/24]
```


例1、2共にテーブルエントリはとりあえず固定とし、CLIは古いがthriftのものを使う。  
grpcのランタイムは時間があれば。(simple_switch_grpcをインストールするのは[この手順](https://github.com/p4lang/behavioral-model/blob/master/Dockerfile.grpc)で出来る。ただしPIが最新だとチュートリアルも動作しない。)

### 事前準備

READMEに則ってOSインストールとパッケージインストールを行う。  
READMEはUbuntu 16.04の記述になっているので、16.04で実施する。18.04だとパッケージが一部存在しなかったりして面倒。

```
$ sudo apt update
$ sudo apt upgrade -y
$ sudo apt install unzip cmake g++ git automake libtool libgc-dev bison flex libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev libboost-graph-dev llvm pkg-config python python-scapy python-ipaddr python-ply tcpdump
```

### p4のtoolchainをインストール

コンパイラ(``p4c``)やヘッダをインストールする。  

[README](https://github.com/p4lang/p4c/blob/master/README.md)に則って作業を進める。  
まずp4cのインストールの前にprotobufが必要(PI使ってなくても、無いとautogen.shでエラーになる)なので、そちらを先にインストールする。

```
$ mkdir ~/work # 以降、ここで作業
$ cd ~/work
$ git clone https://github.com/google/protobuf.git
$ cd protobuf
$ git checkout v3.2.0 # README推奨のバージョン
$ ./autogen.sh
$ ./configure
$ make
$ sudo make install
$ sudo ldconfig
```

その後、p4cをインストールする。

```
$ cd ~/work
$ git clone --recursive https://github.com/p4lang/p4c.git 
$ cd p4c
$ ./bootstrap.sh
$ cd build
$ cmake .. -DENABLE_EBPF=OFF # 今回使わない(準備しておかないとcmakeでエラーになる)のでdisableにする。
$ make # coreたくさんあれば-jX指定すると早く終わる。
$ sudo make install
```

``p4c`` の構成はフロントエンドやバックエンドなどのモジュールに分かれている。詳しくは[こちら](https://p4.org/assets/p4-ws-2017-p4-compiler.pdf)。BMv2のsimple_switch向けのバックエンドは ``p4c-bm2-ss``。  
要するにLLVMみたなものだと思えば良く、LLVMベースにすることに関しては[それっぽい提案](http://lists.llvm.org/pipermail/llvm-dev/2018-March/121736.html)もあるが、今回は議論の対象にしないので、気になったら各自調べる。

### BMv2のインストール

ソフトウェアスイッチ実装のBMv2をインストールする。  

[README](https://github.com/p4lang/behavioral-model/blob/master/README.md)に則って作業を進める。  
``install_deps.sh`` はUbuntu 14.04向けだが、16.04でも動く。

```
$ cd ~/work
$ git clone https://github.com/p4lang/behavioral-model.git
$ cd behavioral-model
$ ./install_deps.sh
$ ./autogen.sh
$ ./configure
$ make
$ sudo make install
$ sudo ldconfig
```

先述したとおり、このインストールの仕方だとthriftで通信する版のものしか入らないが、最初に試すのには特に問題にならない。

### 実施例1の.p4の記述

``example1.p4`` とする。

```
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
        // broadcastする場合はmulticastを使うため、simple_switchに対してmulticast groupを設定しておく必要がある
        // 後述のsimple_switch_CLIで設定する
        standard_metadata.mcast_grp = 1;
    }

    // エントリは固定にする
    table bcast {
        actions = {
            broadcast;
        }
        default_action = broadcast; // table miss扱い
    }
    
    apply {
        bcast.apply();
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
        packet.emit(hdr.ethernet); // 組み立て
    }
}

// v1modelを利用
V1Switch(
parse(),
verifyChecksum(),
ingress(),
egress(),
computeChecksum(),
deparse()
) main;
```

### example1.p4をp4cでコンパイル

```
$ p4c --std p4-16 example1.p4 -o build
```

成功すると ``build/example1.json`` が出来る。

``--std`` をつけなくてもp4-16で解釈されるのでなくてもいい。  
``-b`` をつけなくてもbmv2用になるのでつけなくてもいい。

### 実施例1でスイッチにつなげるホスト、NICの作成とルーティング設定

1回だけ実行する。

```
$ sudo ip netns add host1
$ sudo ip netns add host2
$ sudo ip link add v11 type veth peer name v12
$ sudo ip link add v21 type veth peer name v22
$ sudo ip link set dev v11 addr 10:54:ff:99:01:11
$ sudo ip link set dev v12 addr 10:54:ff:99:01:12
$ sudo ip link set dev v21 addr 10:54:ff:99:02:21
$ sudo ip link set dev v22 addr 10:54:ff:99:02:22
$ sudo ip link set v12 netns host1
$ sudo ip link set v22 netns host2
$ sudo ip link set v11 up
$ sudo ip link set v21 up
$ sudo ip netns exec host1 ip link set v12 up
$ sudo ip netns exec host2 ip link set v22 up
$ sudo ip netns exec host1 ip link set lo up
$ sudo ip netns exec host2 ip link set lo up
$ sudo ip netns exec host1 ip addr add 10.0.0.1/24 dev v12
$ sudo ip netns exec host2 ip addr add 10.0.0.2/24 dev v22 
```

### 実施例1のsimple_switch起動

``build/example1.json`` を指定して起動する。

```
$ sudo simple_switch build/example1.json -i 1@v11 -i 2@v21 --log-console -L debug &
```

### simple_switch_CLIでConfig設定、エントリの追加や確認

```
$ simple_switch_CLI
RuntimeCmd: # ? でhelpが見れる。table_add等でエントリをいれることができる。
> 
```

.p4のコメントのとおり、broadcastする場合はmulticastを使うため、multicast groupを設定しておく。(P4Runtimeを使っている場合はRuntime側から設定する)

```
RuntimeCmd: mc_mgrp_create 1
RuntimeCmd: mc_node_create 0 1
RuntimeCmd: mc_node_create 1 2
RuntimeCmd: mc_node_associate 1 0
RuntimeCmd: mc_node_associate 1 1
```

### 実施例1でpingする

```
sudo ip netns exec host1 ping 10.0.0.2
```

replyが返ってくるのを確認する。  
simple_switchのstdoutにログが出るので、返ってこない場合はおかしな挙動をしていないか確認する。

### 実施例2の.p4の記述

``example2.p4`` とする。

```
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
```

### example2.p4をp4cでコンパイル

```
$ p4c --std p4-16 example2.p4 -o build
```

成功すると ``build/example2.json`` が出来る。

### 実施例2でスイッチにつなげるホスト、NICの作成とルーティング設定

1回だけ実行する。

```
$ sudo ip netns add host3
$ sudo ip netns add host4
$ sudo ip link add v31 type veth peer name v32
$ sudo ip link add v41 type veth peer name v42
$ sudo ip link set dev v31 addr 10:54:ff:99:03:31
$ sudo ip link set dev v32 addr 10:54:ff:99:03:32
$ sudo ip link set dev v41 addr 10:54:ff:99:04:41
$ sudo ip link set dev v42 addr 10:54:ff:99:04:42
$ sudo ip link set v32 netns host3
$ sudo ip link set v42 netns host4
$ sudo ip link set v31 up
$ sudo ip link set v41 up
$ sudo ip netns exec host3 ip link set v32 up
$ sudo ip netns exec host4 ip link set v42 up
$ sudo ip netns exec host3 ip link set lo up
$ sudo ip netns exec host4 ip link set lo up
$ sudo ip netns exec host3 ip addr add 10.0.0.1/24 dev v32
$ sudo ip netns exec host4 ip addr add 10.0.1.1/24 dev v42 
$ sudo ip netns exec host3 ip route add 10.0.1.0/24 via 10.0.0.254
$ sudo ip netns exec host4 ip route add 10.0.0.0/24 via 10.0.1.254
```

### 実施例2のsimple_switch起動

``build/example2.json`` を指定して起動する。

```
$ sudo simple_switch build/example2.json -i 1@v31 -i 2@v41 --log-console -L debug &
```

例2はbroadcastを使っていないため、mc設定はいらない。

### 実施例2でpingする

```
sudo ip netns exec host3 ping 10.0.1.1
```

replyが返ってくるのを確認する。  

## 次にすること

* PI等を使ってCLIでなくコントローラアプリケーションを書く
  * 最新のPIだとエラーになるらしい
* l2_switchのようにCPUと連携する
  * PASのDigestを使うのがいいのかも
* 怪しいプロトコルを作る
  * [計算機](https://github.com/p4lang/tutorials/tree/master/exercises/other/calc)など
  * 送受信のテストにはパケットジェネレータが必要になるため、scapyなどを使う
* 理解が浅い点を補強する
  * 試してない、らしい、っぽい、多分、と書いてるもの

この先は集まってハッカソン的にやるのがいいかも。
