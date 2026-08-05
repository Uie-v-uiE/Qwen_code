---
name: verilog-pipeline-patterns
description: Verilog 流水线与图像处理设计模式参考，包含典型流水线结构、区域检测、投影算法等实战模式
---

# Verilog 流水线与图像处理设计模式参考

## 目录
- [1. 图像流水线标准架构](#1-图像流水线标准架构)
- [2. 颜色空间转换流水线](#2-颜色空间转换流水线)
- [3. 算法级流水线（Sobel）](#3-算法级流水线sobel)
- [4. 像素级判定 + 区域级聚合](#4-像素级判定--区域级聚合)
- [5. 投影算法（水平/垂直）](#5-投影算法水平垂直)
- [6. 中值滤波器流水线](#6-中值滤波器流水线)
- [7. 3x3 矩阵生成模块](#7-3x3-矩阵生成模块)

---

## 1. 图像流水线标准架构

所有图像处理模块遵循统一接口约定：

```
输入侧：  pre_frame_vsync, pre_frame_hsync, pre_frame_de, per_img_xxx
输出侧：  post_frame_vsync, post_frame_hsync, post_frame_de, post_img_xxx
```

关键约束：**每级流水线的 LATENCY 必须用移位寄存器精确对齐同步信号**。

```verilog
reg [LATENCY-1:0] vsync_d, hsync_d, de_d;
always @(posedge clk) begin
    vsync_d <= {vsync_d[LATENCY-2:0], pre_frame_vsync};
    hsync_d <= {hsync_d[LATENCY-2:0], pre_frame_hsync};
    de_d    <= {de_d[LATENCY-2:0],    pre_frame_de};
end
assign post_frame_vsync = vsync_d[LATENCY-1];
assign post_frame_hsync = hsync_d[LATENCY-1];
assign post_frame_de    = de_d[LATENCY-1];
```

---

## 2. 颜色空间转换流水线

RGB → YCbCr 的经典 3 级流水线，定点数运算避免浮点：

### 数学原理
```
Y  = 0.299R + 0.587G + 0.114B
Cb = -0.172R - 0.339G + 0.511B + 128
Cr = 0.511R - 0.428G - 0.083B + 128

定点化（乘256取整）：
Y  = (77*R + 150*G + 29*B) >> 8
Cb = (128*B - 43*R - 85*G + 32768) >> 8
Cr = (128*R - 107*G - 21*B + 32768) >> 8
```

### 流水线结构
```
step1: 9路并行乘法（映射到DSP）
       rgb_r_m0 = R*77, rgb_r_m1 = R*43, rgb_r_m2 = R*128(移位)
       rgb_g_m0 = G*150, ...
step2: 3路加法
       img_y0  = r_m0 + g_m0 + b_m0
       img_cb0 = b_m1 - r_m1 - g_m1 + 32768
       img_cr0 = r_m2 - g_m2 - b_m2 + 32768
step3: 右移8位（等价除256）
       img_y1  = img_y0[15:8]
```

### 关键技巧
- `/256` 用取高位字节 `[15:8]` 替代除法
- `*128` 用 `<< 7` 替代乘法
- RGB 通道用独立寄存器 `_d0/_d1/_d2` 穿通对齐到最终输出

---

## 3. 算法级流水线（Sobel）

4 级流水线 + 比较平方替代开方：

### Sobel 算法流水线
```
step1: 加权求和
       gx_temp1 = P13 + 2*P23 + P33   // 2*用移位
       gx_temp2 = P11 + 2*P21 + P31
step2: 绝对值差
       gx_data = |gx_temp1 - gx_temp2|
step3: 梯度平方（DSP乘法）
       gxy_square = gx^2 + gy^2
step4: 阈值比较
       edge = (gxy_square >= THRESHOLD_SQ)
```

### 关键优化：比较平方替代开方
```verilog
// 避免 sqrt(gx^2+gy^2) >= threshold
// 替代为 gx^2+gy^2 >= threshold^2
localparam SOBEL_THRESHOLD_SQ = SOBEL_THRESHOLD * SOBEL_THRESHOLD;
```

---

## 4. 像素级判定 + 区域级聚合

Color_Mask_new 的 4 级架构，从像素到区域候选：

### 架构
```
stage0: 输入捕获
stage1: 差值计算（B-G, B-R, |Cb-128| 等）
stage2: 像素级判定（strict + relax 双阈值）
stage3: 区域级聚合（水平 run → 垂直聚合 → bbox → 打分决策）
```

### strict/relax 双阈值策略
```verilog
// strict：高置信种子（强差值 + 高色度）
blue_strict <= (bg_diff > D_BG) && (br_diff > D_BR) && (cb >= CB_MIN) && (s >= 48);
// relax：低置信扩展（弱差值 + 低色度）
blue_relax  <= (bg_diff > D_BG/2) && (br_diff > D_BR/2) && (cb >= CB_MIN-8) && (s >= 24);
```

### 区域级 run 检测
```
水平：连续 strict/relax 像素 ≥ H_RUN_STRICT/H_RUN_RELAX → 有效行段
垂直：连续行段水平重叠 ≥ V_RUN_STRICT/V_RUN_RELAX → 垂直聚合 → bbox
```

### 离散打分（避免除法）
```verilog
// 4档离散分数替代连续浮点除法
// 边缘密度：edge_count/perim → 4档比较
if (vf_edge_count * 1000 >= perim * 200) edge_score = 1000;
else if (vf_edge_count * 1000 >= perim * 120) edge_score = 700;
else if (vf_edge_count * 1000 >= perim * 60) edge_score = 400;
else edge_score = 100;
```

---

## 5. 投影算法（水平/垂直）

### 核心思路
- 用 RAM 累加每行/列的像素统计值
- 首行写 0 初始化 RAM
- 后续行累加：`ram_wr_data = ram_rd_data + per_img_Bit`
- 最后一行读出 RAM 数据，找峰值位置

### RAM 地址策略
```verilog
// 首行：地址 = x_cnt（初始化清零）
// 非首行：读地址 = x_cnt（当前列），写地址 = x_cnt_d1（延迟一拍的列）
assign ram_wr_addr = (y_cnt == 0) ? x_cnt : y_cnt_r;
assign ram_rd_addr = (y_cnt == 0 || y_cnt == VDISP-1) ? x_cnt : y_cnt;
```

### 峰值检测
```verilog
// 上升沿和下降沿检测找峰值
if ((rd_data_d2 > rd_data_d1) && (rd_data_d2 > 30) && (max_y1 == 0))
    max_y1 <= x_cnt_r - 3;  // 峰值位置（减去RAM读取延迟补偿）
```

---

## 6. 中值滤波器流水线

3x3 中值滤波器 = 7 个 Sort3 模块级联，3 级流水线：

```
Step1: 3组 Sort3（行1/2/3各自排序）
Step2: 3组 Sort3（max列取min, mid列取mid, min列取max）
Step3: 1个 Sort3（3个中间值再取中值）
```

每个 Sort3 模块内部打一拍（1级流水线），总计约 3 级延迟。

---

## 7. 3x3 矩阵生成模块

图像处理的标准前置模块，从逐像素流生成 3x3 窗口：

- 使用 line_shift_ram 存储前两行像素
- 输出 9 个像素值 matrix_p11..p33
- 带有 vsync/hsync/clken 同步信号延迟补偿