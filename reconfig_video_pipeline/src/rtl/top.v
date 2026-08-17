`timescale 1ns / 1ps
`default_nettype none
module top #(
    parameter  CLK_FREQ_HZ = 50_000_000,
    parameter  RST_TIME_MS = 20,
    //1280*720 分辨率时序参数
    parameter  H_SYNC      = 11'd40,      //行同步
    parameter  H_BACK      = 11'd220,     //行显示后沿
    parameter  H_DISP      = 11'd1280,    //行有效数据
    parameter  H_FRONT     = 11'd110,     //行显示前沿
    parameter  H_TOTAL     = 11'd1650,    //行扫描周期
    parameter  V_SYNC      = 11'd5,       //场同步
    parameter  V_BACK      = 11'd20,      //场显示后沿
    parameter  V_DISP      = 11'd720,     //场有效数据
    parameter  V_FRONT     = 11'd5,       //场显示前沿
    parameter  V_TOTAL     = 11'd750,     //场扫描周期
    //video_display
    parameter  H_DISP      = 11'd1280,    //分辨率--行
    parameter  V_DISP      = 11'd720,     //分辨率--列
    parameter  DIV_CNT     = 22'd750000,  //分频计数器
    localparam SIDE_W      = 11'd40,      //屏幕边框宽度
    localparam BLOCK_W     = 11'd40,      //方块宽度
    localparam BLUE        = 24'h0000ff,  //屏幕边框颜色 蓝色
    localparam WHITE       = 24'hffffff,  //背景颜色 白色
    localparam BLACK       = 24'h000000   //方块颜色 黑色
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       key_in,
    output            tmds_clk_n,
    output            tmds_clk_p,
    output      [2:0] tmds_data_n,
    output      [2:0] tmds_data_p
);

    //rst_gen
    wire        rst_out;
    wire        rst_n_out;
    wire        locked;
    //debounce
    wire        key_value;
    wire        key_out;
    //video_driver
    wire [23:0] pixel_data;
    wire        video_hs;
    wire        video_vs;
    wire        video_de;
    wire [23:0] video_rgb;
    wire [10:0] pixel_xpos;
    wire [10:0] pixel_ypos;
    //dvi_transmitter_top
    wire        pixel_clk;
    wire        pixel_clk_5x;

    clk_gen u_clk_gen (
        .clk_out1(clk_50m),
        .clk_out2(pixel_clk),
        .clk_out3(pixel_clk_5x),
        .locked  (locked),
        .clk_in  (sys_clk)
    );

    rst_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .RST_TIME_MS(RST_TIME_MS)
    ) u_rst_gen (
        .sys_rst_n_in(clk_50m),
        .sys_rst_n_in(sys_rst_n),
        .rst_out     (rst_out),
        .rst_n_out   (rst_n_out)
    );

    debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .DEB_TIME_MS(DEB_TIME_MS)
    ) u_debounce (
        .sys_clk  (clk_50m),
        .sys_rst_n(rst_n_out),
        .key_in   (key_in),
        .key_value(key_value),
        .key_out  (key_out)
    );

    video_driver #(
        .H_SYNC (H_SYNC),
        .H_BACK (H_BACK),
        .H_DISP (H_DISP),
        .H_FRONT(H_FRONT),
        .H_TOTAL(H_TOTAL),
        .V_SYNC (V_SYNC),
        .V_BACK (V_BACK),
        .V_DISP (V_DISP),
        .V_FRONT(V_FRONT),
        .V_TOTAL(V_TOTAL)
    ) u_video_driver (
        .pixel_clk (pixel_clk),
        .sys_rst_n (rst_n_out),
        .video_hs  (video_hs),
        .video_vs  (video_vs),
        .video_de  (video_de),
        .video_rgb (video_rgb),
        .data_req  (),
        .pixel_data(pixel_data),
        .pixel_xpos(pixel_xpos),
        .pixel_ypos(pixel_ypos),
    );

    video_display #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP),
        .DIV_CNT(DIV_CNT),
        .SIDE_W (SIDE_W),
        .BLOCK_W(BLOCK_W),
        .BLUE   (BLUE),
        .WHITE  (WHITE),
        .BLACK  (BLACK)
    ) u_video_display (
        .pixel_clk (pixel_clk),
        .sys_rst_n (rst_n_out),
        .pixel_xpos(pixel_xpos),
        .pixel_ypos(pixel_ypos),
        .pixel_data(pixel_data)
    );


    dvi_transmitter_top u_dvi_transmitter_top (
        .pixel_clk   (pixel_clk),
        .pixel_clk_5x(pixel_clk_5x),
        .reset_n     (rst_n_out),
        .video_din   (video_rgb),
        .video_hsync (video_hs),
        .video_vsync (video_vs),
        .video_de    (video_de),
        .tmds_clk_p  (tmds_clk_p),
        .tmds_clk_n  (tmds_clk_n),
        .tmds_data_p (tmds_data_p),
        .tmds_data_n (tmds_data_n),
        .tmds_oen    ()
    );


endmodule

`default_nettype wire
