`timescale 1ns / 1ps
`default_nettype none

module video_driver #(
    //1280*720 分辨率时序参数
    parameter H_SYNC  = 11'd40,    //行同步
    parameter H_BACK  = 11'd220,   //行显示后沿
    parameter H_DISP  = 11'd1280,  //行有效数据
    parameter H_FRONT = 11'd110,   //行显示前沿
    parameter H_TOTAL = 11'd1650,  //行扫描周期

    parameter V_SYNC  = 11'd5,    //场同步
    parameter V_BACK  = 11'd20,   //场显示后沿
    parameter V_DISP  = 11'd720,  //场有效数据
    parameter V_FRONT = 11'd5,    //场显示前沿
    parameter V_TOTAL = 11'd750   //场扫描周期

    //1920*1080分辨率时序参数
    // parameter H_SYNC  = 12'd44,    //行同步
    // parameter H_BACK  = 12'd148,   //行显示后沿
    // parameter H_DISP  = 12'd1920,  //行有效数据
    // parameter H_FRONT = 12'd88,    //行显示前沿
    // parameter H_TOTAL = 12'd2200,  //行扫描周期

    // parameter V_SYNC  = 12'd5,     //场同步
    // parameter V_BACK  = 12'd36,    //场显示后沿
    // parameter V_DISP  = 12'd1080,  //场有效数据
    // parameter V_FRONT = 12'd4,     //场显示前沿
    // parameter V_TOTAL = 12'd1125   //场扫描周期
) (
    input pixel_clk,
    input sys_rst_n,

    //RGB接口	
    output            video_hs,   //行同步信号
    output            video_vs,   //场同步信号
    output            video_de,   //数据使能
    output     [23:0] video_rgb,  //RGB888颜色数据
    output reg        data_req,

    input      [23:0] pixel_data,  //像素点数据
    output reg [10:0] pixel_xpos,  //像素点横坐标
    output reg [10:0] pixel_ypos   //像素点纵坐标
);

    reg [11:0] cnt_h;
    reg [11:0] cnt_v;
    reg        video_en;

    assign video_de = video_en;
    assign video_hs = (cnt_h < H_SYNC) ? 1'b0 : 1'b1;  //行同步信号赋值
    assign video_vs = (cnt_v < V_SYNC) ? 1'b0 : 1'b1;  //场同步信号赋值

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            video_en <= 1'b0;
        end else begin
            video_en <= data_req;
        end
    end

    assign video_rgb = video_de ? pixel_data : 24'd0;

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            data_req <= 1'b0;
        end else if (((cnt_h >= H_SYNC + H_BACK - 2'd2) && (cnt_h < H_SYNC + H_BACK + H_DISP - 2'd2)) &&
                     ((cnt_v >= V_SYNC + V_BACK) && (cnt_v < V_SYNC + V_BACK + V_DISP))) begin
            data_req <= 1'b1;
        end else begin
            data_req <= 1'b0;
        end
    end

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pixel_xpos <= 11'd0;
        end else if (data_req) begin
            pixel_xpos <= cnt_h + 2'd2 - H_SYNC - H_BACK;
        end else begin
            pixel_xpos <= 11'd0;
        end
    end

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pixel_ypos <= 11'd0;
        end else if ((cnt_v >= (V_SYNC + V_BACK)) && (cnt_v < (V_SYNC + V_BACK + V_DISP))) begin
            pixel_ypos <= cnt_v + 1'b1 - (V_SYNC + V_BACK);
        end else begin
            pixel_ypos <= 11'd0;
        end
    end

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt_h <= 11'd0;
        end else begin
            if (cnt_h < H_TOTAL - 1'b1) cnt_h <= cnt_h + 1'b1;
            else cnt_h <= 11'd0;
        end
    end

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cnt_v <= 11'd0;
        end else if (cnt_h == H_TOTAL - 1'b1) begin
            if (cnt_v < V_TOTAL - 1'b1) cnt_v <= cnt_v + 1'b1;
            else cnt_v <= 11'd0;
        end
    end

endmodule

`default_nettype wire
