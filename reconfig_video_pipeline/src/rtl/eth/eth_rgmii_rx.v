//----------------------------------------------------------------------------------------
// File name:           eth_rgmii_rx.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        RGMII接收模块（适配参考工程 rgmii_rx，仅改名，功能逐行一致）
//                      BUFG/BUFIO + IDELAYE2(FIXED) + IDDR(SAME_EDGE_PIPELINED)
//----------------------------------------------------------------------------------------
module eth_rgmii_rx (
    input  wire       idelay_clk,    // 200MHz IDELAY参考时钟
    //以太网RGMII接口
    input  wire       rgmii_rxc,     // RGMII接收时钟
    input  wire       rgmii_rx_ctl,  // RGMII接收控制信号
    input  wire [3:0] rgmii_rxd,     // RGMII接收数据
    //以太网GMII接口
    output wire       gmii_rx_clk,   // GMII接收时钟
    output wire       gmii_rx_dv,    // GMII接收数据有效
    output wire [7:0] gmii_rxd       // GMII接收数据
);
    //parameter define
    parameter IDELAY_VALUE = 0;  // 输入延时 tap (n*78ps)，板上验证值=0
    //wire define
    wire       rgmii_rxc_bufg;
    wire       rgmii_rxc_bufio;
    wire [3:0] rgmii_rxd_delay;
    wire       rgmii_rx_ctl_delay;
    wire [1:0] gmii_rxdv_t;
    //*****************************************************
    //**                    main code
    //*****************************************************
    assign gmii_rx_clk = rgmii_rxc_bufg;
    assign gmii_rx_dv  = gmii_rxdv_t[0] & gmii_rxdv_t[1];

    BUFG BUFG_inst (
        .I(rgmii_rxc),
        .O(rgmii_rxc_bufg)
    );
    BUFIO BUFIO_inst (
        .I(rgmii_rxc),
        .O(rgmii_rxc_bufio)
    );
    // IDELAYCTRL（RST 接地，与参考工程一致，已上板验证）
    (* IODELAY_GROUP = "rgmii_rx_delay" *)
    IDELAYCTRL IDELAYCTRL_inst (
        .RDY   (),
        .REFCLK(idelay_clk),
        .RST   (1'b0)
    );
    // rx_ctl 延时 + 双沿采样
    (* IODELAY_GROUP = "rgmii_rx_delay" *)
    IDELAYE2 #(
        .IDELAY_TYPE     ("FIXED"),
        .IDELAY_VALUE    (IDELAY_VALUE),
        .REFCLK_FREQUENCY(200.0)
    ) u_delay_rx_ctrl (
        .CNTVALUEOUT(),
        .DATAOUT    (rgmii_rx_ctl_delay),
        .C          (1'b0),
        .CE         (1'b0),
        .CINVCTRL   (1'b0),
        .CNTVALUEIN (5'b0),
        .DATAIN     (1'b0),
        .IDATAIN    (rgmii_rx_ctl),
        .INC        (1'b0),
        .LD         (1'b0),
        .LDPIPEEN   (1'b0),
        .REGRST     (1'b0)
    );
    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1     (1'b0),
        .INIT_Q2     (1'b0),
        .SRTYPE      ("SYNC")
    ) u_iddr_rx_ctl (
        .Q1(gmii_rxdv_t[0]),
        .Q2(gmii_rxdv_t[1]),
        .C (rgmii_rxc_bufio),
        .CE(1'b1),
        .D (rgmii_rx_ctl_delay),
        .R (1'b0),
        .S (1'b0)
    );
    // rxd[3:0] 延时 + 双沿采样
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : rxdata_bus
            (* IODELAY_GROUP = "rgmii_rx_delay" *)
            IDELAYE2 #(
                .IDELAY_TYPE     ("FIXED"),
                .IDELAY_VALUE    (IDELAY_VALUE),
                .REFCLK_FREQUENCY(200.0)
            ) u_delay_rxd (
                .CNTVALUEOUT(),
                .DATAOUT    (rgmii_rxd_delay[i]),
                .C          (1'b0),
                .CE         (1'b0),
                .CINVCTRL   (1'b0),
                .CNTVALUEIN (5'b0),
                .DATAIN     (1'b0),
                .IDATAIN    (rgmii_rxd[i]),
                .INC        (1'b0),
                .LD         (1'b0),
                .LDPIPEEN   (1'b0),
                .REGRST     (1'b0)
            );
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1     (1'b0),
                .INIT_Q2     (1'b0),
                .SRTYPE      ("SYNC")
            ) u_iddr_rxd (
                .Q1(gmii_rxd[i]),
                .Q2(gmii_rxd[4+i]),
                .C (rgmii_rxc_bufio),
                .CE(1'b1),
                .D (rgmii_rxd_delay[i]),
                .R (1'b0),
                .S (1'b0)
            );
        end
    endgenerate
endmodule
