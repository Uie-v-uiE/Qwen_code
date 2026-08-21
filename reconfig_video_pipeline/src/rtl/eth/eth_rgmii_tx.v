//----------------------------------------------------------------------------------------
// File name:           eth_rgmii_tx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        RGMII发送模块（适配参考工程 rgmii_tx，仅改名，功能逐行一致）
//----------------------------------------------------------------------------------------
module eth_rgmii_tx (
    //GMII发送端口
    input  wire       gmii_tx_clk,
    input  wire       gmii_tx_en,
    input  wire [7:0] gmii_txd,
    //RGMII发送端口
    output wire       rgmii_txc,
    output wire       rgmii_tx_ctl,
    output wire [3:0] rgmii_txd
);
    //*****************************************************
    //**                    main code
    //*****************************************************
    assign rgmii_txc = gmii_tx_clk;
    // tx_ctl：双沿均为 tx_en
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT        (1'b0),
        .SRTYPE      ("SYNC")
    ) ODDR_inst (
        .Q (rgmii_tx_ctl),
        .C (gmii_tx_clk),
        .CE(1'b1),
        .D1(gmii_tx_en),
        .D2(gmii_tx_en),
        .R (1'b0),
        .S (1'b0)
    );
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : txdata_bus
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .INIT        (1'b0),
                .SRTYPE      ("SYNC")
            ) ODDR_inst (
                .Q (rgmii_txd[i]),
                .C (gmii_tx_clk),
                .CE(1'b1),
                .D1(gmii_txd[i]),
                .D2(gmii_txd[4+i]),
                .R (1'b0),
                .S (1'b0)
            );
        end
    endgenerate
endmodule
