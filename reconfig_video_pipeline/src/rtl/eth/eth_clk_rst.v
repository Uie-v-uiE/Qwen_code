//----------------------------------------------------------------------------------------
// File name:           eth_clk_rst.v
// Project:             RK7020 Video Processing (Window 2)
// Descriptions:        时钟/复位基础设施：200M(IDELAYCTRL) + 100M(aclk) + aclk域复位同步
//----------------------------------------------------------------------------------------
module eth_clk_rst (
    input  wire sys_clk,    // 50MHz 板时钟 (W17)
    input  wire sys_rst_n,  // 系统复位，低有效
    output wire clk_200m,   // IDELAYCTRL 参考时钟
    output wire aclk,       // 100MHz AXI-Stream 时钟
    output wire locked,     // PLL 锁定指示
    output wire aresetn     // aclk 域复位，低有效（异步断言/同步释放）
);
    //*****************************************************
    //**                    main code
    //*****************************************************
    eth_clk_wiz u_clk_wiz (
        .clk_out1(clk_200m),
        .clk_out2(aclk),
        .reset   (~sys_rst_n),
        .locked  (locked),
        .clk_in1 (sys_clk)
    );

    // aclk 域复位同步：locked 后延迟释放
    reg [3:0] rst_sync;
    always @(posedge aclk or negedge sys_rst_n) begin
        if (!sys_rst_n) rst_sync <= 4'h0;
        else rst_sync <= {rst_sync[2:0], locked};
    end
    assign aresetn = rst_sync[3];
endmodule
