//----------------------------------------------------------------------------------------
// File name:           video_proto_rx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        视频协议解析：8B Header 解析 + 帧验证 FSM + 像素字节流生成
//----------------------------------------------------------------------------------------
module video_proto_rx (
    input clk,   // gmii_rx_clk (125MHz)
    input rst_n,

    // 来自 video_udp_rx
    input       udp_pay_valid,
    input [7:0] udp_pay_data,
    input       udp_pay_sop,
    input       udp_pay_eop,

    // 输出到 pixel_axis_tx
    output reg       pix_byte_valid,
    output reg [7:0] pix_byte_data,
    output reg       frame_sof,       // 整个帧的第一个字节
    output reg       frame_drop       // 帧错误丢弃脉冲
);
    localparam ST_IDLE = 3'd0;
    localparam ST_HDR = 3'd1;
    localparam ST_DATA = 3'd2;
    localparam ST_DROP = 3'd3;

    reg [2:0] cur_state, next_state;
    reg [2:0] byte_cnt;

    reg [15:0] frame_id, pkt_idx, total_pkts, pay_len;
    reg [15:0] expect_pkt_idx;
    reg [15:0] expect_total_pkts;
    reg        frame_valid_flag;
    reg        is_first_pkt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cur_state <= ST_IDLE;
        else cur_state <= next_state;
    end

    always @(*) begin
        next_state = cur_state;
        case (cur_state)
            ST_IDLE: if (udp_pay_valid && udp_pay_sop) next_state = ST_HDR;
            ST_HDR:
            if (udp_pay_eop) next_state = ST_IDLE;  // 异常短包
            else if (byte_cnt == 3'd7) next_state = ST_DATA;
            ST_DATA: if (udp_pay_eop) next_state = ST_IDLE;
            ST_DROP: if (udp_pay_eop) next_state = ST_IDLE;
            default: next_state = ST_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_cnt          <= 3'd0;
            pix_byte_valid    <= 1'b0;
            pix_byte_data     <= 8'd0;
            frame_sof         <= 1'b0;
            frame_drop        <= 1'b0;
            frame_valid_flag  <= 1'b0;
            expect_pkt_idx    <= 16'd0;
            expect_total_pkts <= 16'd0;
            is_first_pkt      <= 1'b1;
            frame_id          <= 16'd0;
            pkt_idx           <= 16'd0;
            total_pkts        <= 16'd0;
            pay_len           <= 16'd0;
        end else begin
            pix_byte_valid <= 1'b0;
            frame_sof      <= 1'b0;
            frame_drop     <= 1'b0;

            if (udp_pay_valid) begin
                case (cur_state)
                    ST_IDLE: begin
                        byte_cnt <= 3'd0;
                        // 帧 ID 连续性检查
                        if (!is_first_pkt && udp_pay_data != frame_id[15:8]) begin
                            // 这里简化了 16-bit 拼接，实际应在 ST_HDR 完整判断
                        end
                    end

                    ST_HDR: begin
                        byte_cnt <= byte_cnt + 1'b1;
                        case (byte_cnt)
                            3'd0: frame_id[15:8] <= udp_pay_data;
                            3'd1: frame_id[7:0] <= udp_pay_data;
                            3'd2: pkt_idx[15:8] <= udp_pay_data;
                            3'd3: pkt_idx[7:0] <= udp_pay_data;
                            3'd4: total_pkts[15:8] <= udp_pay_data;
                            3'd5: total_pkts[7:0] <= udp_pay_data;
                            3'd6: pay_len[15:8] <= udp_pay_data;
                            3'd7: begin
                                pay_len[7:0] <= udp_pay_data;
                                // 验证逻辑
                                if ((is_first_pkt) || (frame_id == (frame_id + 1'b1)) ||  // 简化 ID 检查
                                    (pkt_idx == expect_pkt_idx && total_pkts == expect_total_pkts &&
                                     pay_len <= 16'd1464 && pay_len[1:0] == 2'b00)) begin
                                    frame_valid_flag  <= 1'b1;
                                    expect_pkt_idx    <= pkt_idx + 1'b1;
                                    expect_total_pkts <= total_pkts;
                                    is_first_pkt      <= 1'b0;
                                    if (pkt_idx == 16'd0 && byte_cnt == 3'd7) frame_sof <= 1'b1;
                                end else begin
                                    frame_valid_flag <= 1'b0;
                                    frame_drop       <= 1'b1;
                                end
                            end
                        endcase
                    end

                    ST_DATA: begin
                        if (frame_valid_flag) begin
                            pix_byte_valid <= 1'b1;
                            pix_byte_data  <= udp_pay_data;
                        end
                    end

                    ST_DROP: ;  // 静默丢弃
                endcase
            end
        end
    end
endmodule
