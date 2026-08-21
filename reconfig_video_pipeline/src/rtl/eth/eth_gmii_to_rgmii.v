//----------------------------------------------------------------------------------------
// File name:           eth_gmii_to_rgmii.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        GMII<->RGMII 封装（适配参考工程，仅改名；gmii_tx_clk=gmii_rx_clk 保留）
//----------------------------------------------------------------------------------------
module eth_gmii_to_rgmii (
    input  wire       idelay_clk,
    //GMII接口
    output wire       gmii_rx_clk,
    output wire       gmii_rx_dv,
    output wire [7:0] gmii_rxd,
    output wire       gmii_tx_clk,
    input  wire       gmii_tx_en,
    input  wire [7:0] gmii_txd,
    //RGMII接口
    input  wire       rgmii_rxc,
    input  wire       rgmii_rx_ctl,
    input  wire [3:0] rgmii_rxd,
    output wire       rgmii_txc,
    output wire       rgmii_tx_ctl,
    output wire [3:0] rgmii_txd
);
    parameter IDELAY_VALUE = 0;
    //*****************************************************
    //**                    main code
    //*****************************************************
    assign gmii_tx_clk = gmii_rx_clk;  // TX 时钟源自 RX 时钟（链路在才有 TX）

    eth_rgmii_rx #(
        .IDELAY_VALUE(IDELAY_VALUE)
    ) u_rgmii_rx (
        .idelay_clk  (idelay_clk),
        .gmii_rx_clk (gmii_rx_clk),
        .rgmii_rxc   (rgmii_rxc),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxd   (rgmii_rxd),
        .gmii_rx_dv  (gmii_rx_dv),
        .gmii_rxd    (gmii_rxd)
    );

    eth_rgmii_tx u_rgmii_tx (
        .gmii_tx_clk (gmii_tx_clk),
        .gmii_tx_en  (gmii_tx_en),
        .gmii_txd    (gmii_txd),
        .rgmii_txc   (rgmii_txc),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txd   (rgmii_txd)
    );
endmodule
