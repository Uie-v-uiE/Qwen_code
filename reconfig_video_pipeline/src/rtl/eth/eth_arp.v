//----------------------------------------------------------------------------------------
// File name:           eth_arp.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        ARP顶层模块（适配参考工程 arp，功能逐行一致）
//----------------------------------------------------------------------------------------
module eth_arp #(
    parameter BOARD_MAC = 48'h00_11_22_33_44_55,
    parameter BOARD_IP  = {8'd192, 8'd168, 8'd1, 8'd10},
    parameter DES_MAC   = 48'hff_ff_ff_ff_ff_ff,
    parameter DES_IP    = {8'd192, 8'd168, 8'd1, 8'd102}
) (
    input         rst_n,        // 复位信号，低电平有效
    // GMII接口
    input         gmii_rx_clk,  // GMII接收数据时钟
    input         gmii_rx_dv,   // GMII输入数据有效信号
    input  [ 7:0] gmii_rxd,     // GMII输入数据
    input         gmii_tx_clk,  // GMII发送数据时钟
    output        gmii_tx_en,   // GMII输出数据有效信号
    output [ 7:0] gmii_txd,     // GMII输出数据          
    // 用户接口
    output        arp_rx_done,
    output        arp_rx_type,
    output [47:0] src_mac,
    output [31:0] src_ip,
    input         arp_tx_en,
    input         arp_tx_type,
    input  [47:0] des_mac,
    input  [31:0] des_ip,
    output        tx_done
);
    // wire define
    wire        crc_en;
    wire        crc_clr;
    wire [ 7:0] crc_d8;
    wire [31:0] crc_data;
    wire [31:0] crc_next;

    assign crc_d8 = gmii_txd;

    eth_arp_rx #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP (BOARD_IP)
    ) u_arp_rx (
        .clk        (gmii_rx_clk),
        .rst_n      (rst_n),
        .gmii_rx_dv (gmii_rx_dv),
        .gmii_rxd   (gmii_rxd),
        .arp_rx_done(arp_rx_done),
        .arp_rx_type(arp_rx_type),
        .src_mac    (src_mac),
        .src_ip     (src_ip)
    );

    eth_arp_tx #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP (BOARD_IP),
        .DES_MAC  (DES_MAC),
        .DES_IP   (DES_IP)
    ) u_arp_tx (
        .clk        (gmii_tx_clk),
        .rst_n      (rst_n),
        .arp_tx_en  (arp_tx_en),
        .arp_tx_type(arp_tx_type),
        .des_mac    (des_mac),
        .des_ip     (des_ip),
        .crc_data   (crc_data),
        .crc_next   (crc_next[31:24]),
        .tx_done    (tx_done),
        .gmii_tx_en (gmii_tx_en),
        .gmii_txd   (gmii_txd),
        .crc_en     (crc_en),
        .crc_clr    (crc_clr)
    );

    eth_crc32_d8 u_crc32_d8 (
        .clk     (gmii_tx_clk),
        .rst_n   (rst_n),
        .data    (crc_d8),
        .crc_en  (crc_en),
        .crc_clr (crc_clr),
        .crc_data(crc_data),
        .crc_next(crc_next)
    );
endmodule
