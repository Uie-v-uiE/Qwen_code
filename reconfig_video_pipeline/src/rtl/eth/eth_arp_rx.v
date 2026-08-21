//----------------------------------------------------------------------------------------
// File name:           eth_arp_rx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        ARP接收模块（适配参考工程 arp_rx，功能逐行一致）
//----------------------------------------------------------------------------------------
module eth_arp_rx #(
    parameter BOARD_MAC = 48'h00_11_22_33_44_55,
    parameter BOARD_IP  = {8'd192, 8'd168, 8'd1, 8'd10}
) (
    input             clk,          // 时钟信号
    input             rst_n,        // 复位信号，低电平有效
    input             gmii_rx_dv,   // GMII输入数据有效信号
    input      [ 7:0] gmii_rxd,     // GMII输入数据
    output reg        arp_rx_done,  // ARP接收完成信号
    output reg        arp_rx_type,  // ARP接收类型 0:请求  1:应答
    output reg [47:0] src_mac,      // 接收到的源MAC地址
    output reg [31:0] src_ip        // 接收到的源IP地址
);
    // parameter define
    localparam st_idle = 5'b0_0001;
    localparam st_preamble = 5'b0_0010;
    localparam st_eth_head = 5'b0_0100;
    localparam st_arp_data = 5'b0_1000;
    localparam st_rx_end = 5'b1_0000;
    localparam ETH_TYPE = 16'h0806;  // 修正了原代码的 ETH_TPYE 拼写

    // reg define
    reg [ 4:0] cur_state;
    reg [ 4:0] next_state;
    reg        skip_en;
    reg        error_en;
    reg [ 4:0] cnt;
    reg [47:0] des_mac_t;
    reg [31:0] des_ip_t;
    reg [47:0] src_mac_t;
    reg [31:0] src_ip_t;
    reg [15:0] eth_type;
    reg [15:0] op_data;

    //*****************************************************
    //**                    main code
    //*****************************************************
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
                else if (error_en) next_state = st_rx_end;
                else next_state = st_preamble;
            end
            st_eth_head: begin
                if (skip_en) next_state = st_arp_data;
                else if (error_en) next_state = st_rx_end;
                else next_state = st_eth_head;
            end
            st_arp_data: begin
                if (skip_en) next_state = st_rx_end;
                else if (error_en) next_state = st_rx_end;
                else next_state = st_arp_data;
            end
            st_rx_end: begin
                if (skip_en) next_state = st_idle;
                else next_state = st_rx_end;
            end
            default: next_state = st_idle;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            skip_en     <= 1'b0;
            error_en    <= 1'b0;
            cnt         <= 5'd0;
            des_mac_t   <= 48'd0;
            des_ip_t    <= 32'd0;
            src_mac_t   <= 48'd0;
            src_ip_t    <= 32'd0;
            eth_type    <= 16'd0;
            op_data     <= 16'd0;
            arp_rx_done <= 1'b0;
            arp_rx_type <= 1'b0;
            src_mac     <= 48'd0;
            src_ip      <= 32'd0;
        end else begin
            skip_en     <= 1'b0;
            error_en    <= 1'b0;
            arp_rx_done <= 1'b0;
            case (next_state)
                st_idle: begin
                    if ((gmii_rx_dv == 1'b1) && (gmii_rxd == 8'h55)) skip_en <= 1'b1;
                end
                st_preamble: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 5'd1;
                        if ((cnt < 5'd6) && (gmii_rxd != 8'h55)) error_en <= 1'b1;
                        else if (cnt == 5'd6) begin
                            cnt <= 5'd0;
                            if (gmii_rxd == 8'hd5) skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_eth_head: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 5'b1;
                        if (cnt < 5'd6) des_mac_t <= {des_mac_t[39:0], gmii_rxd};
                        else if (cnt == 5'd6) begin
                            if ((des_mac_t != BOARD_MAC) && (des_mac_t != 48'hff_ff_ff_ff_ff_ff)) error_en <= 1'b1;
                        end else if (cnt == 5'd12) eth_type[15:8] <= gmii_rxd;
                        else if (cnt == 5'd13) begin
                            eth_type[7:0] <= gmii_rxd;
                            cnt           <= 5'd0;
                            if (eth_type[15:8] == ETH_TYPE[15:8] && gmii_rxd == ETH_TYPE[7:0]) skip_en <= 1'b1;
                            else error_en <= 1'b1;
                        end
                    end
                end
                st_arp_data: begin
                    if (gmii_rx_dv) begin
                        cnt <= cnt + 5'd1;
                        if (cnt == 5'd6) op_data[15:8] <= gmii_rxd;
                        else if (cnt == 5'd7) op_data[7:0] <= gmii_rxd;
                        else if (cnt >= 5'd8 && cnt < 5'd14) src_mac_t <= {src_mac_t[39:0], gmii_rxd};
                        else if (cnt >= 5'd14 && cnt < 5'd18) src_ip_t <= {src_ip_t[23:0], gmii_rxd};
                        else if (cnt >= 5'd24 && cnt < 5'd28) des_ip_t <= {des_ip_t[23:0], gmii_rxd};
                        else if (cnt == 5'd28) begin
                            cnt <= 5'd0;
                            if (des_ip_t == BOARD_IP) begin
                                if ((op_data == 16'd1) || (op_data == 16'd2)) begin
                                    skip_en     <= 1'b1;
                                    arp_rx_done <= 1'b1;
                                    src_mac     <= src_mac_t;
                                    src_ip      <= src_ip_t;
                                    src_mac_t   <= 48'd0;
                                    src_ip_t    <= 32'd0;
                                    des_mac_t   <= 48'd0;
                                    des_ip_t    <= 32'd0;
                                    if (op_data == 16'd1) arp_rx_type <= 1'b0;
                                    else arp_rx_type <= 1'b1;
                                end else error_en <= 1'b1;
                            end else error_en <= 1'b1;
                        end
                    end
                end
                st_rx_end: begin
                    cnt <= 5'd0;
                    if (gmii_rx_dv == 1'b0 && skip_en == 1'b0) skip_en <= 1'b1;
                end
                default: ;
            endcase
        end
    end
endmodule
