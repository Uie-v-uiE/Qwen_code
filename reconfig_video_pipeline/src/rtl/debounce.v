`timescale 1ns / 1ps
`default_nettype none

module debounce #(
    parameter CLK_FREQ_HZ = 50_000_000,  // 时钟频率(Hz)
    parameter DEB_TIME_MS = 20           // 消抖时间(ms)
) (
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_in,
    output wire key_value,  // 稳定的按键电平
    output reg  key_out     // 单周期高脉冲
);

    localparam DEB_CNT_MAX = CLK_FREQ_HZ / 1000 * DEB_TIME_MS - 1;
    localparam DEB_CNT_WIDTH = DEB_CNT_MAX > 1 ? $clog2(DEB_CNT_MAX + 1) : 1;

    (* ASYNC_REG = "TRUE" *)reg [              1:0] key_sync;
    reg [DEB_CNT_WIDTH-1:0] key_cnt;

    reg                     key_state;
    reg                     key_state_d;  // 保存上一拍状态，用于边沿检测

    assign key_value = key_state;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            key_sync <= 2'b11;
        end else begin
            key_sync <= {key_sync[0], key_in};
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            key_cnt     <= {DEB_CNT_WIDTH{1'b0}};
            key_state   <= 1'b1;  // 默认未按下(高电平)
            key_state_d <= 1'b1;
        end else begin
            key_state_d <= key_state;
            if (key_sync[1] != key_state) begin
                if (key_cnt == DEB_CNT_MAX) begin
                    key_state <= key_sync[1];
                    key_cnt   <= {DEB_CNT_WIDTH{1'b0}};
                end else begin
                    key_cnt <= key_cnt + 1'b1;
                end
            end else begin
                key_cnt <= {DEB_CNT_WIDTH{1'b0}};
            end
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            key_out <= 1'b0;
        end else begin
            if (key_state_d ^ key_state) begin
                key_out <= 1'b1;
            end else begin
                key_out <= 1'b0;
            end
        end

    end

endmodule

`default_nettype wire
