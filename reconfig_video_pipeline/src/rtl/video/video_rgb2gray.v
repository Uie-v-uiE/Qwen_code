// ============================================================
// Module: video_rgb2gray
// Function: RGB888 -> GRAY8 (BT.601)
// Contract: 04_AXI_STREAM_CONTRACT.md
// Latency: 1 cycle (registered output)
// Throughput: 1 pixel/clock (II=1)
// Bypass: enable=0 -> transparent 1-cycle register
// Language: Verilog (IEEE 1364-2005), synthesizable
// ============================================================

module video_rgb2gray #(
    parameter IMAGE_WIDTH  = 640,
    parameter IMAGE_HEIGHT = 480
) (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI4-Stream Slave
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    input  wire [31:0] s_axis_tuser,
    // AXI4-Stream Master
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    output wire [31:0] m_axis_tuser,
    // Control
    input  wire        enable
);

    // --------------------------------------------------------
    // Gray computation (combinational)
    // BT.601: Y = 0.299R + 0.587G + 0.114B
    // Integer: (77*R + 150*G + 29*B) >> 8
    // Max: 255*(77+150+29) = 65280, fits 16-bit
    // --------------------------------------------------------
    wire [7:0] pix_r, pix_g, pix_b;
    wire [15:0] gray_acc;
    wire [ 7:0] gray_out;

    assign pix_r    = s_axis_tdata[23:16];
    assign pix_g    = s_axis_tdata[15:8];
    assign pix_b    = s_axis_tdata[7:0];

    assign gray_acc = ({8'h00, pix_r} * 16'd77) + ({8'h00, pix_g} * 16'd150) + ({8'h00, pix_b} * 16'd29);
    assign gray_out = gray_acc[15:8];

    // --------------------------------------------------------
    // Output data MUX: process or bypass
    // --------------------------------------------------------
    wire [31:0] tdata_sel;
    assign tdata_sel = enable ? {8'h00, 16'h0000, gray_out} : s_axis_tdata;

    // --------------------------------------------------------
    // Output register (1-cycle pipeline)
    // AXI rule: TVALID held stable until handshake
    // --------------------------------------------------------
    reg [31:0] m_tdata_q;
    reg        m_tvalid_q;
    reg        m_tlast_q;
    reg [31:0] m_tuser_q;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_tdata_q  <= 32'd0;
            m_tvalid_q <= 1'b0;
            m_tlast_q  <= 1'b0;
            m_tuser_q  <= 32'd0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                m_tdata_q  <= tdata_sel;
                m_tvalid_q <= 1'b1;
                m_tlast_q  <= s_axis_tlast;
                m_tuser_q  <= s_axis_tuser;
            end else if (m_tvalid_q && m_axis_tready) begin
                m_tvalid_q <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------
    // Output / Ready
    // --------------------------------------------------------
    assign m_axis_tdata  = m_tdata_q;
    assign m_axis_tvalid = m_tvalid_q;
    assign m_axis_tlast  = m_tlast_q;
    assign m_axis_tuser  = m_tuser_q;
    assign s_axis_tready = m_axis_tready || !m_tvalid_q;

endmodule
