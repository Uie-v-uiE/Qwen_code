//----------------------------------------------------------------------------------------
// File name:           eth_arp_tx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        ARP发送模块（适配参考工程 arp_tx，功能逐行一致）
//----------------------------------------------------------------------------------------
module eth_arp_tx #(
    parameter BOARD_MAC = 48'h00_11_22_33_44_55,
    parameter BOARD_IP  = {8'd192, 8'd168, 8'd1, 8'd10},
    parameter DES_MAC   = 48'hff_ff_ff_ff_ff_ff,
    parameter DES_IP    = {8'd192, 8'd168, 8'd1, 8'd102}
) (
    input             clk,          // 时钟信号
    input             rst_n,        // 复位信号，低电平有效
    input             arp_tx_en,    // ARP发送使能信号
    input             arp_tx_type,  // ARP发送类型 0:请求  1:应答
    input      [47:0] des_mac,      // 发送的目标MAC地址
    input      [31:0] des_ip,       // 发送的目标IP地址
    input      [31:0] crc_data,     // CRC校验数据
    input      [ 7:0] crc_next,     // CRC下次校验完成数据
    output reg        tx_done,      // 以太网发送完成信号
    output reg        gmii_tx_en,   // GMII输出数据有效信号
    output reg [ 7:0] gmii_txd,     // GMII输出数据
    output reg        crc_en,       // CRC开始校验使能
    output reg        crc_clr       // CRC数据复位信号 
);
    // localparam define
    localparam st_idle = 5'b0_0001;
    localparam st_preamble = 5'b0_0010;
    localparam st_eth_head = 5'b0_0100;
    localparam st_arp_data = 5'b0_1000;
    localparam st_crc = 5'b1_0000;
    localparam ETH_TYPE = 16'h0806;
    localparam HD_TYPE = 16'h0001;
    localparam PROTOCOL_TYPE = 16'h0800;
    localparam MIN_DATA_NUM = 16'd46;

    // reg define
    reg  [4:0] cur_state;
    reg  [4:0] next_state;
    reg  [7:0] preamble   [ 7:0];
    reg  [7:0] eth_head   [13:0];
    reg  [7:0] arp_data   [27:0];
    reg        tx_en_d0;
    reg        tx_en_d1;
    reg        tx_en_d2;
    reg        skip_en;
    reg  [5:0] cnt;
    reg  [4:0] data_cnt;
    reg        tx_done_t;

    wire       pos_tx_en;
    assign pos_tx_en = (~tx_en_d2) & tx_en_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_en_d0 <= 1'b0;
            tx_en_d1 <= 1'b0;
            tx_en_d2 <= 1'b0;
        end else begin
            tx_en_d0 <= arp_tx_en;
            tx_en_d1 <= tx_en_d0;
            tx_en_d2 <= tx_en_d1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cur_state <= st_idle;
        else cur_state <= next_state;
    end

    always @(*) begin
        next_state = st_idle;
        case (cur_state)
            st_idle: begin
                if (skip_en) next_state = st_preamble;
                else next_state = st_idle;
            end
            st_preamble: begin
                if (skip_en) next_state = st_eth_head;
                else next_state = st_preamble;
            end
            st_eth_head: begin
                if (skip_en) next_state = st_arp_data;
                else next_state = st_eth_head;
            end
            st_arp_data: begin
                if (skip_en) next_state = st_crc;
                else next_state = st_arp_data;
            end
            st_crc: begin
                if (skip_en) next_state = st_idle;
                else next_state = st_crc;
            end
            default: next_state = st_idle;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            skip_en      <= 1'b0;
            cnt          <= 6'd0;
            data_cnt     <= 5'd0;
            crc_en       <= 1'b0;
            gmii_tx_en   <= 1'b0;
            gmii_txd     <= 8'd0;
            tx_done_t    <= 1'b0;
            preamble[0]  <= 8'h55;
            preamble[1]  <= 8'h55;
            preamble[2]  <= 8'h55;
            preamble[3]  <= 8'h55;
            preamble[4]  <= 8'h55;
            preamble[5]  <= 8'h55;
            preamble[6]  <= 8'h55;
            preamble[7]  <= 8'hd5;
            eth_head[0]  <= DES_MAC[47:40];
            eth_head[1]  <= DES_MAC[39:32];
            eth_head[2]  <= DES_MAC[31:24];
            eth_head[3]  <= DES_MAC[23:16];
            eth_head[4]  <= DES_MAC[15:8];
            eth_head[5]  <= DES_MAC[7:0];
            eth_head[6]  <= BOARD_MAC[47:40];
            eth_head[7]  <= BOARD_MAC[39:32];
            eth_head[8]  <= BOARD_MAC[31:24];
            eth_head[9]  <= BOARD_MAC[23:16];
            eth_head[10] <= BOARD_MAC[15:8];
            eth_head[11] <= BOARD_MAC[7:0];
            eth_head[12] <= ETH_TYPE[15:8];
            eth_head[13] <= ETH_TYPE[7:0];
            arp_data[0]  <= HD_TYPE[15:8];
            arp_data[1]  <= HD_TYPE[7:0];
            arp_data[2]  <= PROTOCOL_TYPE[15:8];
            arp_data[3]  <= PROTOCOL_TYPE[7:0];
            arp_data[4]  <= 8'h06;
            arp_data[5]  <= 8'h04;
            arp_data[6]  <= 8'h00;
            arp_data[7]  <= 8'h01;
            arp_data[8]  <= BOARD_MAC[47:40];
            arp_data[9]  <= BOARD_MAC[39:32];
            arp_data[10] <= BOARD_MAC[31:24];
            arp_data[11] <= BOARD_MAC[23:16];
            arp_data[12] <= BOARD_MAC[15:8];
            arp_data[13] <= BOARD_MAC[7:0];
            arp_data[14] <= BOARD_IP[31:24];
            arp_data[15] <= BOARD_IP[23:16];
            arp_data[16] <= BOARD_IP[15:8];
            arp_data[17] <= BOARD_IP[7:0];
            arp_data[18] <= DES_MAC[47:40];
            arp_data[19] <= DES_MAC[39:32];
            arp_data[20] <= DES_MAC[31:24];
            arp_data[21] <= DES_MAC[23:16];
            arp_data[22] <= DES_MAC[15:8];
            arp_data[23] <= DES_MAC[7:0];
            arp_data[24] <= DES_IP[31:24];
            arp_data[25] <= DES_IP[23:16];
            arp_data[26] <= DES_IP[15:8];
            arp_data[27] <= DES_IP[7:0];
        end else begin
            skip_en    <= 1'b0;
            crc_en     <= 1'b0;
            gmii_tx_en <= 1'b0;
            tx_done_t  <= 1'b0;
            case (next_state)
                st_idle: begin
                    if (pos_tx_en) begin
                        skip_en <= 1'b1;
                        if ((des_mac != 48'b0) || (des_ip != 32'd0)) begin
                            eth_head[0]  <= des_mac[47:40];
                            eth_head[1]  <= des_mac[39:32];
                            eth_head[2]  <= des_mac[31:24];
                            eth_head[3]  <= des_mac[23:16];
                            eth_head[4]  <= des_mac[15:8];
                            eth_head[5]  <= des_mac[7:0];
                            arp_data[18] <= des_mac[47:40];
                            arp_data[19] <= des_mac[39:32];
                            arp_data[20] <= des_mac[31:24];
                            arp_data[21] <= des_mac[23:16];
                            arp_data[22] <= des_mac[15:8];
                            arp_data[23] <= des_mac[7:0];
                            arp_data[24] <= des_ip[31:24];
                            arp_data[25] <= des_ip[23:16];
                            arp_data[26] <= des_ip[15:8];
                            arp_data[27] <= des_ip[7:0];
                        end
                        if (arp_tx_type == 1'b0) arp_data[7] <= 8'h01;
                        else arp_data[7] <= 8'h02;
                    end
                end
                st_preamble: begin
                    gmii_tx_en <= 1'b1;
                    gmii_txd   <= preamble[cnt];
                    if (cnt == 6'd7) begin
                        skip_en <= 1'b1;
                        cnt     <= 1'b0;
                    end else cnt <= cnt + 1'b1;
                end
                st_eth_head: begin
                    gmii_tx_en <= 1'b1;
                    crc_en     <= 1'b1;
                    gmii_txd   <= eth_head[cnt];
                    if (cnt == 6'd13) begin
                        skip_en <= 1'b1;
                        cnt     <= 1'b0;
                    end else cnt <= cnt + 1'b1;
                end
                st_arp_data: begin
                    crc_en     <= 1'b1;
                    gmii_tx_en <= 1'b1;
                    if (cnt == MIN_DATA_NUM - 1'b1) begin
                        skip_en  <= 1'b1;
                        cnt      <= 1'b0;
                        data_cnt <= 1'b0;
                    end else cnt <= cnt + 1'b1;
                    if (data_cnt <= 6'd27) begin
                        data_cnt <= data_cnt + 1'b1;
                        gmii_txd <= arp_data[data_cnt];
                    end else gmii_txd <= 8'd0;
                end
                st_crc: begin
                    gmii_tx_en <= 1'b1;
                    cnt        <= cnt + 1'b1;
                    if (cnt == 6'd0)
                        gmii_txd <= {
                            ~crc_next[0],
                            ~crc_next[1],
                            ~crc_next[2],
                            ~crc_next[3],
                            ~crc_next[4],
                            ~crc_next[5],
                            ~crc_next[6],
                            ~crc_next[7]
                        };
                    else if (cnt == 6'd1)
                        gmii_txd <= {
                            ~crc_data[16],
                            ~crc_data[17],
                            ~crc_data[18],
                            ~crc_data[19],
                            ~crc_data[20],
                            ~crc_data[21],
                            ~crc_data[22],
                            ~crc_data[23]
                        };
                    else if (cnt == 6'd2)
                        gmii_txd <= {
                            ~crc_data[8],
                            ~crc_data[9],
                            ~crc_data[10],
                            ~crc_data[11],
                            ~crc_data[12],
                            ~crc_data[13],
                            ~crc_data[14],
                            ~crc_data[15]
                        };
                    else if (cnt == 6'd3) begin
                        gmii_txd <= {
                            ~crc_data[0],
                            ~crc_data[1],
                            ~crc_data[2],
                            ~crc_data[3],
                            ~crc_data[4],
                            ~crc_data[5],
                            ~crc_data[6],
                            ~crc_data[7]
                        };
                        tx_done_t <= 1'b1;
                        skip_en <= 1'b1;
                        cnt <= 1'b0;
                    end
                end
                default: ;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_done <= 1'b0;
            crc_clr <= 1'b0;
        end else begin
            tx_done <= tx_done_t;
            crc_clr <= tx_done_t;
        end
    end
endmodule
