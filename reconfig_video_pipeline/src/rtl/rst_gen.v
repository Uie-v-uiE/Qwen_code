`timescale 1ns / 1ps
`default_nettype none

module rst_gen #(
    parameter CLK_FREQ_HZ = 50_000_000,  // 时钟频率 (Hz)
    parameter RST_TIME_MS = 100          // 复位保持时间 (ms)
) (
    input  wire sys_clk,
    input  wire sys_rst_n_in,  // 外部异步复位输入，低电平有效
    output wire rst_out,       // 同步后的复位输出，高电平有效
    output wire rst_n_out      // 同步后的复位输出，低电平有效
);

    localparam RST_CNT_MAX = CLK_FREQ_HZ / 1000 * RST_TIME_MS - 1;
    localparam RST_CNT_WIDTH = RST_CNT_MAX > 1 ? $clog2(RST_CNT_MAX + 1) : 1;

    (* ASYNC_REG = "TRUE" *)reg                     rst_sync_ff1;
    (* ASYNC_REG = "TRUE" *)reg                     rst_sync_ff2;

    reg [RST_CNT_WIDTH-1:0] rst_cnt;
    reg                     rst_out_reg;
    reg                     rst_n_out_reg;

    assign rst_out   = rst_out_reg;
    assign rst_n_out = rst_n_out_reg;

    always @(posedge sys_clk or negedge sys_rst_n_in) begin
        if (!sys_rst_n_in) begin
            rst_sync_ff1 <= 1'b0;
            rst_sync_ff2 <= 1'b0;
        end else begin
            rst_sync_ff1 <= 1'b1;
            rst_sync_ff2 <= rst_sync_ff1;
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n_in) begin
        if (!sys_rst_n_in) begin
            rst_cnt       <= {RST_CNT_WIDTH{1'b0}};
            rst_out_reg   <= 1'b1;
            rst_n_out_reg <= 1'b0;
        end else begin
            if (rst_sync_ff2) begin
                if (rst_cnt < RST_CNT_MAX) begin
                    rst_cnt <= rst_cnt + 1'b1;
                end else begin
                    rst_out_reg   <= 1'b0;
                    rst_n_out_reg <= 1'b1;
                end
            end else begin
                rst_cnt <= {RST_CNT_WIDTH{1'b0}};
            end
        end
    end

endmodule

`default_nettype wire
