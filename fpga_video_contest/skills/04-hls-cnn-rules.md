# Vitis HLS 与轻量 CNN 规范

## 1. HLS 接口规范
- 使用 `hls::stream<ap_uint<N>>` 进行流式数据传输。
- 使用 `ap_int<N>` (有符号) 和 `ap_uint<N>` (无符号) 进行定点数计算。
- 顶层函数必须使用 `#pragma HLS INTERFACE axis port=...`。

## 2. 轻量 CNN 架构 (残差增强)
- 输入：64x64 灰度图块 (8-bit)。
- Layer 1：3x3 Conv, 16 channels, ReLU (16-bit 激活)。
- Layer 2：3x3 Conv, 16 channels, ReLU。
- Layer 3：3x3 Conv, 1 channel, 输出残差 (8-bit)。
- 输出：Input + Residual (饱和截断到 0~255)。

## 3. 优化目标 (LLM Agent 关注点)
- 目标 II (Initiation Interval) = 1 (每时钟周期处理 1 个像素)。
- 使用 `#pragma HLS PIPELINE` 和 `#pragma HLS DATAFLOW`。
- 卷积核权重使用 `#pragma HLS ARRAY_PARTITION` 展开。
- 行缓存 (Line Buffer) 和 窗口 (Window) 必须使用 BRAM 和寄存器阵列。