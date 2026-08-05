---
name: fpga-resource-and-timing
description: FPGA 资源优化与时序设计的详细参考，包括 DSP/BRAM 映射、复位策略、控制集优化等
---

# FPGA 资源优化与时序设计参考

## 目录
- [1. DSP 单元利用](#1-dsp-单元利用)
- [2. BRAM 推断与保护](#2-bram-推断与保护)
- [3. 控制集优化](#3-控制集优化)
- [4. 复位策略](#4-复位策略)
- [5. 除法替代方案](#5-除法替代方案)
- [6. 乘法与移位优化](#6-乘法与移位优化)
- [7. 跨时钟域处理](#7-跨时钟域处理)
- [8. 流水线打拍技巧](#8-流水线打拍技巧)

---

## 1. DSP 单元利用

DSP48/DSP58 是 FPGA 内部专用乘加资源，正确映射至关重要。

### 映射要求
- 乘法逻辑应映射到 DSP 原语，获得最佳性能和最低功耗
- 内部管道寄存器（AREG/BREG/MREG/PREG）必须打包进 DSP 以提升 Fmax

### 复位类型约束
- DSP 内部寄存器仅支持同步复位
- 若使用异步复位，综合工具无法将寄存器吸收到 DSP 内部，被迫使用额外 fabric 资源
- 例：16x16 乘法器用异步复位额外消耗 65 个寄存器 + 32 个 LUT
- 所有流水线级必须统一复位类型（全同步或全异步），混合使用导致映射失败

### 示例：RGB2YCbCr 的 DSP 流水线
```verilog
// step1: pipeline mult (映射到 DSP)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rgb_r_m0 <= 16'd0; rgb_r_m1 <= 16'd0; rgb_r_m2 <= 16'd0;
        rgb_g_m0 <= 16'd0; rgb_g_m1 <= 16'd0; rgb_g_m2 <= 16'd0;
        rgb_b_m0 <= 16'd0; rgb_b_m1 <= 16'd0; rgb_b_m2 <= 16'd0;
    end else begin
        rgb_r_m0 <= rgb888_r * 8'd77;
        rgb_r_m1 <= rgb888_r * 8'd43;
        rgb_r_m2 <= rgb888_r << 7;    // 乘128 用移位代替
        rgb_g_m0 <= rgb888_g * 8'd150;
        // ...
    end
end
```

---

## 2. BRAM 推断与保护

### 推断规则
- 描述存储数组时，切勿添加复位条件，否则综合工具无法推断 BRAM，会用数千 fabric 寄存器替代
- 正确做法：仅用时钟使能控制写入，读出无需复位
```verilog
// 正确：可推断 BRAM
always @(posedge clk) begin
    if (wr_en) ram[addr] <= data;
end
assign rd_data = ram[rd_addr];

// 错误：加了复位 → 无法推断 BRAM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) ram[addr] <= 0;  // 这会摧毁 BRAM 推断
    else if (wr_en) ram[addr] <= data;
end
```

### BRAM 保护
- 异步复位在断言期间会损坏 BRAM/LUTRAM/SRL 的存储内容
- 驱动这些资源输入端的寄存器必须使用同步复位

---

## 3. 控制集优化

控制集 = {时钟, 复位, 时钟使能}，过多独特控制集降低 Slice 填充率。

### 优化策略
- 减少低扇出 CE 信号（主要诱因）
- 数据路径省去复位（控制路径保留复位）
- 小规模寄存器避免生成 CE：在 if-else 中给不满足条件的情况赋常量值
```verilog
// 避免 CE 信号
always @(posedge clk) begin
    if (condition)
        data <= new_value;
    else
        data <= 1'b0;  // 赋常量而非保持，避免 CE
end
```

---

## 4. 复位策略

### 核心原则
- FPGA 配置完成后 GSR 将所有寄存器初始化为 0，无需为初始化编写全局复位
- 控制路径需要复位（确保正确启动）；数据路径通常可省去复位（提升布线灵活性和 Fmax）

### 异步复位同步释放
- 异步复位断言可以不及时，但释放必须与时钟同步
- 不同步释放 → 违反 recovery/removal 时间 → 亚稳态 → 设计失效

```verilog
// 异步复位同步释放电路
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
// 使用 rst_sync2 作为模块内部同步复位
```

### 错误的复位移除方式
- 不能仅注释掉复位条件 → 可能导致信号反向使能
- 正确做法：创建独立的顺序逻辑块，分别处理有复位和无复位的寄存器

---

## 5. 除法替代方案

### 核心原则：FPGA 中尽量避免除法
除法运算在 FPGA 中消耗大量资源且时序差，应优先用替代方案。

### 替代方案 1：定点缩放 + 移位（最常用）
将 `/N` 转化为 `*(K/N) >> shift`，其中 K 是整数缩放系数。
```verilog
// 例：除以 256 → 直接取高字节（等价于 >>8）
img_y1 <= img_y0[15:8];      // 等价 img_y0 / 256

// 例：除以 3 → 乘 85 再右移 8（85/256 ≈ 0.332）
result <= (data * 8'd85) >> 8;
```

### 替代方案 2：离散分数档（避免变量除法）
将连续除法比较离散化为 4 档整数乘法比较：
```verilog
// 原始：edge_ratio = vf_edge_count / perim （浮点除法）
// 替代：4档离散比较
if (vf_edge_count * 1000 >= perim * 200) score = 1000;
else if (vf_edge_count * 1000 >= perim * 120) score = 700;
else if (vf_edge_count * 1000 >= perim * 60) score = 400;
else score = 100;
```

### 替代方案 3：调用 IP
复杂除法运算使用 IP Catalog 中的 Divider IP 核，获得优化实现。

---

## 6. 乘法与移位优化

### 何时用移位
- 乘以 2^n：用 `<< n`，零资源消耗
- 乘以接近 2^n 的数：拆分为移位 + 加减
```verilog
data * 6  = (data << 2) + (data << 1)
data * 7  = (data << 3) - data
data * 128 = data << 7
data * 9  = (data << 3) + data
```

### 何时用 DSP
- 任意大系数乘法（如 *77, *150, *107）
- 乘加组合（MAC 操作）
- 16x16 及以上位宽乘法

### Sobel 中的混合策略示例
```verilog
// 2*P23 用移位：matrix_p23 << 1
gx_temp1 <= matrix_p13 + (matrix_p23 << 1) + matrix_p33;
// 梯度平方用 DSP：gx_data * gx_data
gxy_square <= gx_data * gx_data + gy_data * gy_data;
```

---

## 7. 跨时钟域处理

### 基本方法
- 单比特信号：两级同步器（打两拍）
- 多比特信号：异步 FIFO 或握手协议
- 复位信号：异步断言 + 同步释放（见复位策略节）

### 两级同步器
```verilog
always @(posedge dest_clk) begin
    sync1 <= src_signal;
    sync2 <= sync1;
end
// 使用 sync2 作为跨域后的安全信号
```

---

## 8. 流水线打拍技巧

### 基本原则
- 长组合路径拆分为多级寄存器，每级只做简单运算
- 同步信号（vsync/hsync/de）必须与数据流水线对齐，否则时序错位

### 信号对齐方法
用移位寄存器延迟同步信号，延迟周期数 = 数据流水线级数：
```verilog
reg [LATENCY-1:0] vsync_d, hsync_d, de_d;
always @(posedge clk) begin
    vsync_d <= {vsync_d[LATENCY-2:0], pre_frame_vsync};
    hsync_d <= {hsync_d[LATENCY-2:0], pre_frame_hsync};
    de_d    <= {de_d[LATENCY-2:0],    pre_frame_de};
end
assign post_vsync = vsync_d[LATENCY-1];
```

### 流水线级间寄存命名规范
- `_d0`, `_d1`, `_d2` 表示 stage0/1/2 的寄存值
- `_m0`, `_m1`, `_m2` 表示乘法器的不同系数输出
- `_r`, `_r2` 表示打一拍、打两拍

### 行/场同步边沿检测
```verilog
wire vsync_pos = per_frame_vsync_r  & ~per_frame_vsync_r2;
wire vsync_neg = ~per_frame_vsync_r &  per_frame_vsync_r2;
wire href_neg  = ~per_frame_href_r  &  per_frame_href_r2;
```