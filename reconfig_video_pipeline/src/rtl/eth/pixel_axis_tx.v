//----------------------------------------------------------------------------------------
// File name:           pixel_axis_tx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        像素组装 + CDC + AXI4-Stream 输出 (符合 04 Contract)
//----------------------------------------------------------------------------------------
module pixel_axis_tx #(
    parameter IMG_WIDTH = 640
) (
    // 125MHz 域 (gmii_rx_clk)
    input       wr_clk,
    input       wr_rst_n,
    input       pix_byte_valid,
    input [7:0] pix_byte_data,
    input       frame_sof,

    // 100MHz 域 (aclk)
    input aclk,
    input aresetn,

    // AXI4-Stream Output
    output reg [31:0] m_axis_tdata,
    output reg        m_axis_tvalid,
    input             m_axis_tready,
    output reg        m_axis_tlast,
    output reg [31:0] m_axis_tuser
);
    // ---------------------------------------------------------
    // 125MHz 域：字节转像素 + Sideband 生成
    // ---------------------------------------------------------
    reg [1:0] byte_cnt;
    reg [9:0] pixel_cnt;
    reg [7:0] r_reg, g_reg;

    reg        fifo_wr_en;
    reg [31:0] fifo_din;  // {6'b0, sof, eol, R, G, B}

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            byte_cnt   <= 2'd0;
            pixel_cnt  <= 10'd0;
            r_reg      <= 8'd0;
            g_reg      <= 8'd0;
            fifo_wr_en <= 1'b0;
            fifo_din   <= 32'd0;
        end else begin
            fifo_wr_en <= 1'b0;
            if (pix_byte_valid) begin
                case (byte_cnt)
                    2'd0: begin
                        r_reg    <= pix_byte_data;
                        byte_cnt <= 2'd1;
                    end
                    2'd1: begin
                        g_reg    <= pix_byte_data;
                        byte_cnt <= 2'd2;
                    end
                    2'd2: begin
                        byte_cnt   <= 2'd0;
                        fifo_wr_en <= 1'b1;
                        fifo_din   <= {6'b0, frame_sof, (pixel_cnt == IMG_WIDTH - 1), r_reg, g_reg, pix_byte_data};

                        if (pixel_cnt == IMG_WIDTH - 1) pixel_cnt <= 10'd0;
                        else pixel_cnt <= pixel_cnt + 1'b1;
                    end
                endcase
            end
        end
    end

    // ---------------------------------------------------------
    // CDC: Async FIFO (125MHz -> 100MHz)
    // 注意：实际工程中请例化 Xilinx FIFO Generator IP (32-bit width)
    // 这里使用行为级模型替代，综合时需替换为 IP
    // ---------------------------------------------------------
    reg [31:0] fifo_mem[0:1023];
    reg [10:0] wr_ptr, rd_ptr;
    wire [31:0] fifo_dout;
    wire fifo_empty, fifo_full;

    assign fifo_dout  = fifo_mem[rd_ptr[9:0]];
    assign fifo_empty = (wr_ptr == rd_ptr);
    assign fifo_full  = (wr_ptr[10] != rd_ptr[10]) && (wr_ptr[9:0] == rd_ptr[9:0]);

    always @(posedge wr_clk) begin
        if (fifo_wr_en && !fifo_full) begin
            fifo_mem[wr_ptr[9:0]] <= fifo_din;
            wr_ptr                <= wr_ptr + 1'b1;
        end
    end

    // ---------------------------------------------------------
    // 100MHz 域：AXI4-Stream 输出
    // ---------------------------------------------------------
    reg rd_en;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 32'd0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= 32'd0;
            rd_ptr        <= 11'd0;
            rd_en         <= 1'b0;
        end else begin
            // 握手逻辑
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end

            // 读取 FIFO
            if (!m_axis_tvalid || m_axis_tready) begin
                if (!fifo_empty) begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= {8'h00, fifo_dout[23:0]};
                    m_axis_tuser  <= {31'd0, fifo_dout[25]};  // SOF
                    m_axis_tlast  <= fifo_dout[24];  // EOL
                    rd_ptr        <= rd_ptr + 1'b1;
                end
            end
        end
    end
endmodule
