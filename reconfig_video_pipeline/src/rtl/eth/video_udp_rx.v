//----------------------------------------------------------------------------------------
// File name:           video_udp_rx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        视频 UDP 接收模块：Eth/IPv4/UDP 过滤 + Payload 提取
//----------------------------------------------------------------------------------------
module video_udp_rx #(
    parameter BOARD_MAC      = 48'h00_11_22_33_44_55,
    parameter BOARD_IP       = {8'd192, 8'd168, 8'd1, 8'd10},
    parameter VIDEO_UDP_PORT = 16'd4096
) (
    input       clk,         // gmii_rx_clk (125MHz)
    input       rst_n,
    input       gmii_rx_dv,
    input [7:0] gmii_rxd,

    output reg       udp_pay_valid,  // UDP Payload 字节有效
    output reg [7:0] udp_pay_data,   // UDP Payload 字节数据
    output reg       udp_pay_sop,    // Start of Packet (帧第一个字节)
    output reg       udp_pay_eop     // End of Packet (帧最后一个字节)
);
    // 状态机定义
    localparam st_idle = 6'b000_001;
    localparam st_preamble = 6'b000_010;
    localparam st_eth_head = 6'b000_100;
    localparam st_ip_head = 6'b001_000;
    localparam st_udp_head = 6'b010_000;
    localparam st_rx_data = 6'b100_000;

    localparam ETH_TYPE = 16'h0800;
    localparam IP_PROTO_UDP = 8'd17;

    reg [5:0] cur_state, next_state;
    reg skip_en, error_en;
    reg [ 4:0] cnt;
    reg [47:0] des_mac;
    reg [15:0] eth_type;
    reg [31:0] des_ip;
    reg [15:0] udp_len;
    reg [15:0] udp_dst_port;
    reg [15:0] byte_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cur_state <= st_idle;
        else cur_state <= next_state;
    end

    always @(*) begin
        next_state = st_idle;
        case (cur_state)
            st_idle:     if (skip_en) next_state = st_preamble;
            st_preamble: if (skip_en) next_state = st_eth_head;
 else if (error_en) next_state = st_idle;
            st_eth_head: if (skip_en) next_state = st_ip_head;
 else if (error_en) next_state = st_idle;
            st_ip_head:  if (skip_en) next_state = st_udp_head;
 else if (error_en) next_state = st_idle;
            st_udp_head: if (skip_en) next_state = st_rx_data;
 else if (error_en) next_state = st_idle;
            st_rx_data:  if (skip_en) next_state = st_idle;
            default:     next_state = st_idle;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            skip_en       <= 1'b0;
            error_en      <= 1'b0;
            cnt           <= 5'd0;
            des_mac       <= 48'd0;
            eth_type      <= 16'd0;
            des_ip        <= 32'd0;
            udp_len       <= 16'd0;
            udp_dst_port  <= 16'd0;
            byte_cnt      <= 16'd0;
            udp_pay_valid <= 1'b0;
            udp_pay_data  <= 8'd0;
            udp_pay_sop   <= 1'b0;
            udp_pay_eop   <= 1'b0;
        end else begin
            skip_en       <= 1'b0;
            error_en      <= 1'b0;
            udp_pay_valid <= 1'b0;
            udp_pay_sop   <= 1'b0;
            udp_pay_eop   <= 1'b0;

            case (next_state)
                st_idle: begin
                    if (gmii_rx_dv && gmii_rxd == 8'h55) skip_en <= 1'b1;
                end
                st_preamble: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 1'b1;
                        if (cnt < 5'd6 && gmii_rxd != 8'h55) error_en <= 1'b1;
                        else if (cnt == 5'd6) begin
                            cnt <= 5'd0;
                            if (gmii_rxd == 8'hd5) skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_eth_head: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 1'b1;
                        if (cnt < 5'd6) des_mac <= {des_mac[39:0], gmii_rxd};
                        else if (cnt == 5'd12) eth_type[15:8] <= gmii_rxd;
                        else if (cnt == 5'd13) begin
                            eth_type[7:0] <= gmii_rxd;
                            cnt           <= 5'd0;
                            if ((des_mac == BOARD_MAC || des_mac == 48'hff_ff_ff_ff_ff_ff) && eth_type == ETH_TYPE)
                                skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_ip_head: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 1'b1;
                        if (cnt == 5'd9) begin
                            if (gmii_rxd != IP_PROTO_UDP) error_en <= 1'b1;
                        end else if (cnt >= 5'd16 && cnt <= 5'd19) begin
                            des_ip <= {des_ip[23:0], gmii_rxd};
                        end else if (cnt == 5'd19) begin  // 实际是 cnt=20 时判断，这里简化
                            cnt <= 5'd0;
                            // 注意：IP 头长度可能变化，这里假设固定 20 字节
                            if (des_ip == BOARD_IP) skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_udp_head: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 1'b1;
                        if (cnt == 5'd0) udp_dst_port[15:8] <= gmii_rxd;
                        else if (cnt == 5'd1) udp_dst_port[7:0] <= gmii_rxd;
                        else if (cnt == 5'd2) udp_len[15:8] <= gmii_rxd;
                        else if (cnt == 5'd3) udp_len[7:0] <= gmii_rxd;
                        else if (cnt == 5'd7) begin
                            cnt <= 5'd0;
                            if (udp_dst_port == VIDEO_UDP_PORT) skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_rx_data: begin
                    if (gmii_rx_dv) begin
                        byte_cnt      <= byte_cnt + 1'b1;
                        udp_pay_valid <= 1'b1;
                        udp_pay_data  <= gmii_rxd;
                        if (byte_cnt == 16'd0) udp_pay_sop <= 1'b1;

                        // UDP len 包含 8 字节头，所以 payload 长度是 udp_len - 8
                        if (byte_cnt == (udp_len - 16'd9)) begin
                            skip_en     <= 1'b1;
                            udp_pay_eop <= 1'b1;
                            byte_cnt    <= 16'd0;
                        end
                    end else if (!gmii_rx_dv && byte_cnt > 0) begin
                        // 异常截断
                        skip_en  <= 1'b1;
                        byte_cnt <= 16'd0;
                    end
                end
                default: ;
            endcase
        end
    end
endmodule
