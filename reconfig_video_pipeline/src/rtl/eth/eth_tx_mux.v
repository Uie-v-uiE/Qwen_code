//----------------------------------------------------------------------------------------
// File name:           eth_tx_mux.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        发送仲裁模块（简化参考工程 eth_ctrl，删除 UDP，ARP 优先于 ICMP）
//----------------------------------------------------------------------------------------
module eth_tx_mux (
    input            clk,
    input            rst_n,
    // ARP
    input            arp_rx_done,
    input            arp_rx_type,
    output reg       arp_tx_en,
    output           arp_tx_type,
    input            arp_tx_done,
    input            arp_gmii_tx_en,
    input      [7:0] arp_gmii_txd,
    // ICMP
    input            icmp_tx_start_en,
    input            icmp_tx_done,
    input            icmp_gmii_tx_en,
    input      [7:0] icmp_gmii_txd,
    // ICMP FIFO
    input            icmp_rec_en,
    input      [7:0] icmp_rec_data,
    input            icmp_tx_req,
    output     [7:0] icmp_tx_data,
    // GMII TX
    input      [7:0] tx_data,
    output           tx_req,
    output reg       gmii_tx_en,
    output reg [7:0] gmii_txd
);
    reg [1:0] protocol_sw;
    reg       icmp_tx_busy;
    reg       arp_rx_flag;
    reg       icmp_tx_req_d0;

    assign arp_tx_type  = 1'b1;
    assign tx_req       = icmp_tx_req;
    assign icmp_tx_data = icmp_tx_req_d0 ? tx_data : 8'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) icmp_tx_req_d0 <= 1'd0;
        else icmp_tx_req_d0 <= icmp_tx_req;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gmii_tx_en <= 1'd0;
            gmii_txd   <= 8'd0;
        end else begin
            case (protocol_sw)
                2'b00: begin
                    gmii_tx_en <= arp_gmii_tx_en;
                    gmii_txd   <= arp_gmii_txd;
                end
                2'b10: begin
                    gmii_tx_en <= icmp_gmii_tx_en;
                    gmii_txd   <= icmp_gmii_txd;
                end
                default: begin
                    gmii_tx_en <= 1'b0;
                    gmii_txd   <= 8'd0;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) icmp_tx_busy <= 1'b0;
        else if (icmp_tx_start_en) icmp_tx_busy <= 1'b1;
        else if (icmp_tx_done) icmp_tx_busy <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) arp_rx_flag <= 1'b0;
        else if (arp_rx_done && (arp_rx_type == 1'b0)) arp_rx_flag <= 1'b1;
        else arp_rx_flag <= 1'b0;
    end

    // 新增：ARP 挂起锁存器
    reg arp_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) arp_pending <= 1'b0;
        else if (arp_rx_done && (arp_rx_type == 1'b0)) arp_pending <= 1'b1;  // 收到请求，标记挂起
        else if (arp_tx_en) arp_pending <= 1'b0;  // 触发发送时清除
    end

    // 修改：触发 ARP 发送的仲裁逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            protocol_sw <= 2'b0;
            arp_tx_en   <= 1'b0;
        end else begin
            arp_tx_en <= 1'b0;
            if (icmp_tx_start_en) protocol_sw <= 2'b10;
            // 【修改点】：只要 flag 或 pending 有一个为 1，且 ICMP 不忙，就触发
            else if ((arp_rx_flag || arp_pending) && (icmp_tx_busy == 1'b0)) begin
                protocol_sw <= 2'b0;
                arp_tx_en   <= 1'b1;
            end
        end
    end
endmodule
