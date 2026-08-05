---
name: verilog-design-skill
description: Verilog/FPGA 代码编写、审查、纠错与分析的专项技能。在需要编写、检查、纠错、分析、优化 Verilog 代码时使用，涵盖编码风格规范、时序打拍与流水线技巧、资源优化（避免除法、移位替代乘法、DSP/BRAM 映射）、复位策略、常见错误防范、像素级判定与区域级聚合模式等。触发场景：(1) 编写新的 Verilog 模块，(2) 审查或纠错已有 Verilog 代码，(3) 优化 FPGA 资源或时序，(4) 设计图像处理流水线，(5) 任何涉及 .v/.sv 文件的工作。
---

# Verilog/FPGA 设计规范与实战指南

## 核心铁律

编写/审查 Verilog 代码时，以下规则不可违反：

1. **赋值不混用**：时序逻辑 `<=`，组合逻辑 `=`，同一 always 块严禁混用
2. **组合逻辑无负反馈**：`assign b = m + b` 会导致仿真死循环，改为时序逻辑
3. **BRAM 数组不加复位**：加复位 → 无法推断 BRAM → 用数千寄存器替代
4. **DSP 内用同步复位**：异步复位 → 寄存器无法吸收进 DSP → 额外 65+32 LUT
5. **除法必须替代**：FPGA 中 `/N` 用移位、定点缩放或离散档比较替代

## 工作流程

### 编写新模块
1. 定义端口（clk, rst_n → pre 输入 → post 输出）
2. 参数化阈值和常量
3. 规划流水线级数与每级运算复杂度
4. 同步信号用移位寄存器对齐 LATENCY 周期
5. 应用核心铁律检查

### 审查/纠错已有代码
按以下清单逐项检查：

| 检查项 | 风险等级 |
|--------|---------|
| 赋值混用 `=`/`<=` | 致命 |
| 组合逻辑缺少敏感量表 | 致命 |
| 组合负反馈 | 致命 |
| BRAM 加复位 | 严重 |
| DSP 异步复位 | 严重 |
| 除法运算 | 严重 |
| 异步复位释放不同步 | 严重 |
| 复位类型混合（同一 DSP/BRAM） | 中等 |
| 省略 begin/end | 低 |
| 同步信号未与数据对齐 | 中等 |

### 优化资源/时序
- 长组合路径 → 拆为多级流水线
- `/N` → `*(K) >> shift` 或离散档比较
- `*2^n` → `<< n`
- `*2k±1` → `(data << n) ± data`
- 比较平方替代开方：`sqrt(a) >= t` → `a >= t*t`
- 数据路径省复位，控制路径保留复位

## 除法替代速查

| 原始运算 | 替代方案 | Verilog 代码 |
|----------|---------|-------------|
| `/256` | 取高位字节 | `result[15:8]` |
| `/2^n` | 右移 | `data >> n` |
| `/3` | 乘85右移8 | `(data * 85) >> 8` |
| `/N` | 定点缩放 | `(data * K) >> S`，K/S ≈ 1/N |
| `a/b >= t` | 离散档 | `if (a * 1000 >= b * t1000)` |
| `sqrt(a) >= t` | 比较平方 | `a >= t * t` |

## 流水线模板

```verilog
// 信号对齐（与数据流水线同步）
reg [LATENCY-1:0] vsync_d, hsync_d, de_d;
always @(posedge clk) begin
    vsync_d <= {vsync_d[LATENCY-2:0], pre_vsync};
    hsync_d <= {hsync_d[LATENCY-2:0], pre_hsync};
    de_d    <= {de_d[LATENCY-2:0],    pre_de};
end
assign post_vsync = vsync_d[LATENCY-1];

// 边沿检测
wire pos_flag = sig_r  & ~sig_r2;
wire neg_flag = ~sig_r &  sig_r2;
```

## 详细参考

需要深入某个方面时，查阅以下参考文件：

- **编码风格与常见错误**：[verilog-coding-style.md](references/verilog-coding-style.md) — 赋值规则、命名惯例、状态机设计、错误清单
- **FPGA 资源与时序优化**：[fpga-resource-and-timing.md](references/fpga-resource-and-timing.md) — DSP/BRAM 映射、复位策略、控制集、除法替代、跨时钟域
- **流水线与图像处理模式**：[verilog-pipeline-patterns.md](references/verilog-pipeline-patterns.md) — 颜色转换、Sobel、run 检测、投影算法、中值滤波