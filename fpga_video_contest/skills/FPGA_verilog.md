---
name: vivado-fpga-verilog
description: >-
  Xilinx Vivado 平台 Verilog FPGA 开发综合指南，基于真实工程经验整理。
  涵盖编码规范、流水线架构、时序优化、跨时钟域处理、综合实现技巧和调试方法。
  适用场景：
  （1）编写符合 Vivado 综合规范的 Verilog 模块；
  （2）设计带时序约束的 FPGA 数据通路；
  （3）实现流水线、FSM、跨时钟域等常规设计模式；
  （4）优化资源占用与时序收敛；
  （5）审查 RTL 代码的可综合性与正确性；
  （6）调试综合、实现及上板问题。
  每当用户提及 Verilog 编写、FPGA 时序、Vivado 综合报错、RTL 代码审查或上板调试相关问题时，
  请主动调用本技能，即使用户未明确指定工具链或技能名称。
trigger_keywords:
  - verilog
  - fpga
  - vivado
  - 综合
  - 时序
  - 流水线
  - 跨时钟域
  - rtl
  - xdc
  - 约束
  - adc
  - dac
license: MIT
compatibility: 适用于 Claude Code、Cursor 及 AI 编程助手。
metadata:
  version: "1.0"
  based_on: fpga-hardware-design-and-review-guide + vivado-verilog-skill
allowed-tools: Read Write Edit Bash
---
# Vivado Verilog FPGA 开发指南

适用于 `.v`、`.vh` 文件，面向 Xilinx Vivado 工具链（综合、实现、仿真）。

---

## 一、核心设计理念

### 1. 流水线架构优先

处理高速数据流（视频、网络包、ADC采样流）时，采用多级流水线设计：

- **单级处理**：组合逻辑延迟过大，容易出现时序违例
- **多级流水线**：每级插入寄存器，分散延迟，提升时钟频率
- **典型应用**：RGB 转 YUV、图像滤波、协议解析、ADC 数据处理

**实例**：RGB 转 YUV 5 级流水线

- 第 0 级：输入寄存器（同步输入信号）
- 第 1 级：乘法运算（系数 × 像素值）
- 第 2 级：部分累加（R×coef_r + G×coef_g）
- 第 3 级：最终累加（+ B×coef_b）
- 第 4 级：移位与饱和（截取为 8 bit 结果）

### 2. 位宽管理原则

**位宽计算公式**：

```
乘法位宽 = 输入位宽 + 系数位宽 + 1（符号位）
累加位宽 = 乘法位宽 + log2(加法次数) + 1（保护位）
```

**经验规则**：

- 8 bit 无符号 × 9 bit 有符号系数 = 18 bit 有符号结果
- 3 个 18 bit 数相加 = 20 bit（留 2 bit 保护位防溢出）
- 右移 8 bit 后 = 8 bit 最终结果

### 3. 同步设计铁律

**必须遵守的规则**：

1. **所有触发器使用同一时钟域**（除非明确需要跨时钟域处理）
2. **优先使用同步复位**（避免异步复位释放引起亚稳态传播）
3. **外部输入信号必须打两拍**（跨时钟域或外部输入）
4. **组合逻辑输出必须寄存**（避免毛刺传播）

---

## 二、Verilog 编码规范

### 2.1 文档注释

所有模块、线网和寄存器都需要注释：

- 代码中的注释统一使用英文（English only）
- 注释尽量使用 ASCII 字符，避免全角符号导致跨平台乱码

```verilog
// Module: counter
// Function: up counter with synchronous reset
// Target: Xilinx 7 Series / UltraScale
module counter #(
    parameter WIDTH = 8  // Counter width
) (
    input  wire             clk,      // System clock
    input  wire             rst_n,    // Active-low reset
    output reg  [WIDTH-1:0] count     // Current count value
);
```

### 2.2 定点数 Q 标记法

使用 TI 风格 Q 标记法记录所有定点数值：

- `Qm.n` — 有符号：m 位整数（含符号位），n 位小数，总位宽 = m + n
- `UQm.n` — 无符号：m 位整数，n 位小数，总位宽 = m + n

在信号注释、localparam 说明和模块级文档中使用 Q 标记法。

```verilog
reg signed [15:0] attr_val;      // Interpolated attribute, Q4.12
reg        [15:0] depth;         // Fragment depth, UQ16.0
reg signed [15:0] deriv_dx;      // Per-scanline step dAttr/dx, Q4.12
```

### 2.3 命名规范

- 低电平有效信号：使用 `_n` 后缀（如 `rst_n`、`chip_select_n`）
- 时钟：`clk` 或 `clk_<时钟域名>`
- 使用描述性名称，避免过度缩写
- 模块实例名使用 `u_` 前缀（如 `u_counter`）
- 参数和 localparam 使用大写（如 `DATA_WIDTH`）
- 次态信号使用 `_next` 后缀（如 `state_next`、`count_next`）

### 2.4 时序逻辑 always 块：默认分离，简单场景可合写

默认推荐“组合次态 + 时序寄存器”两段式写法，便于复杂模块维护、复用与时序收敛。

对于简单控制逻辑（如小计数器、握手标志、短状态流程），允许在同一个时序块中直接写条件判断与更新逻辑，不强制拆分 `_next`。这在复位管理、看门狗喂狗、简单命令应答中是常见且可综合的写法。

合写时遵循以下约束：

- 仅限单时钟域、低复杂度路径
- 全部使用非阻塞赋值 `<=`
- 复位分支和正常分支都要覆盖寄存器赋值意图（避免隐含行为）
- 当分支层级较深、状态较多或需要跨模块复用时，改回两段式/三段式 FSM

> **仍然例外**：存储器推断和异步复位同步器有其专用模板，按对应章节执行。

```verilog
// Recommended: use two-process style for complex control logic
always @(*) begin
    state_next = state;
    if (start) begin
        state_next = STATE_RUN;
    end
end

always @(posedge clk) begin
    state <= state_next;
end

// Allowed: inline simple control logic (for example, reset_manager counter/toggle)
always @(posedge clk) begin
    if (!rst_n) begin
        wdi_cnt <= {WDI_CNT_W{1'b0}};
        wdi_o   <= 1'b0;
    end else if (wdi_cnt == WDI_TOGGLE_CYCLES - 1) begin
        wdi_cnt <= {WDI_CNT_W{1'b0}};
        wdi_o   <= ~wdi_o;
    end else begin
        wdi_cnt <= wdi_cnt + 1'b1;
    end
end
```

### 2.5 组合逻辑 always 块

需要独立组合逻辑时，使用 `always @(*)` 块。若采用第 2.4 节的“简单场景合写”模式，则可不单独拆分该块。

```verilog
always @(*) begin
    count_next = count + 8'd1;
    state_next = enable ? STATE_RUN : STATE_IDLE;
end
```

### 2.6 代码格式规范

- 每行一条语句，不在同一行连写多条赋值
- 每行一个声明
- 所有字面量显式指定位宽（如 `8'd0`，而非 `0`）
- 文件开头使用 `` `default_nettype none ``
- `if`/`else`/`case` 项始终使用 `begin`/`end`
- 模块代码尽量控制在 ~500 行以内；过长时拆分为子模块
- 端口声明使用 Verilog-2001 ANSI 风格

```verilog
`default_nettype none

module example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out
);

    reg  [7:0] data_reg;          // Registered data
    reg  [7:0] data_next;         // Next-state value
    wire       valid;             // Data-valid flag

    localparam [7:0] INIT_VAL = 8'd0;

endmodule

`default_nettype wire
```

### 2.7 模块实例化

- 一个模块对应一个文件，文件名与模块名一致
- 始终使用命名端口连接，禁止位置连接

```verilog
// Correct - named port connection
counter #(
    .WIDTH (16)
) u_counter (
    .clk    (clk),
    .rst_n  (rst_n),
    .count  (count_value)
);

// Incorrect - positional connection
counter u_counter (clk, rst_n, count_value);
```

---

## 三、常用设计模式

### 3.1 复位处理

推荐使用同步复位。对于外部异步复位信号，先进行同步化处理。

```verilog
// Synchronous reset (recommended)
reg  [7:0] count;
reg  [7:0] count_next;

always @(*) begin
    count_next = rst_n ? (count + 8'd1) : 8'd0;
end

always @(posedge clk) begin
    count <= count_next;
end

// Asynchronous reset synchronizer (async assert, sync release)
// Note: this is a required exception for conditional logic in a sequential block
module reset_sync (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync;  // Synchronizer flip-flops

    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async)
            sync <= 2'b00;        // Asynchronous assert (immediate reset)
        else
            sync <= {sync[0], 1'b1};  // Synchronous release
    end

    assign rst_n_sync = sync[1];
endmodule
```

### 3.2 防止锁存器推断

信号未在所有分支赋值时会推断出锁存器。预防方法：在 `always @(*)` 块开头设置默认赋值，并覆盖所有 case 分支。

```verilog
always @(*) begin
    // Default assignments to avoid latch inference
    data_next  = data_reg;
    valid_next = 1'b0;

    case (state)
        STATE_IDLE: begin
            data_next = 8'd0;
        end
        STATE_LOAD: begin
            data_next = data_in;
        end
        default: begin
            data_next = data_reg;
        end
    endcase
end
```

### 3.3 有限状态机（FSM）

将状态寄存器与次态逻辑分离，使用 `localparam` 定义状态编码。

```verilog
// State encoding
localparam [1:0] STATE_IDLE = 2'd0;
localparam [1:0] STATE_RUN  = 2'd1;
localparam [1:0] STATE_DONE = 2'd2;

(* FSM_ENCODING = "one_hot" *) reg [1:0] state;      // Current state register
                               reg [1:0] state_next;  // Next-state value

// Next-state logic (combinational)
always @(*) begin
    state_next = state;
    case (state)
        STATE_IDLE: begin
            if (start) state_next = STATE_RUN;
        end
        STATE_RUN: begin
            if (finish) state_next = STATE_DONE;
        end
        STATE_DONE: begin
            state_next = STATE_IDLE;
        end
        default: begin
            state_next = STATE_IDLE;  // Safe recovery path
        end
    endcase
end

// State register (sequential)
always @(posedge clk) begin
    state <= state_next;
end
```

### 3.4 跨时钟域（CDC）

**单 bit 信号**：使用 2 级触发器同步器（`(* ASYNC_REG = "TRUE" *)`）。
**多 bit 信号**：使用格雷码编码 + 异步 FIFO。
代码模板见 `references/design-patterns.md` → "CDC 快速模板"。

### 3.5 存储器推断

使用 Vivado 识别的标准模式推断 Block RAM / Distributed RAM / ROM（`(* RAM_STYLE = "block" *)`）。
代码模板见 `references/design-patterns.md` → "存储器推断模板"。

### 3.6 流水线设计模式

带 Valid/Ready 握手的标准流水线级，支持背压（`in_ready = out_ready || !out_valid`）。
代码模板见 `references/design-patterns.md` → "Valid/Ready 流水线模板"。

---

## 四、Vivado 综合与约束

综合属性（`KEEP`、`ASYNC_REG`、`RAM_STYLE`、`MARK_DEBUG` 等）、不可综合构造清单、LUT/BRAM/DSP 资源优化策略、Xilinx 原语实例化、XDC 约束文件模板等内容，详见 `references/synthesis-and-constraints.md`。

**关键要点速查**：

- 跨时钟域寄存器必须加 `(* ASYNC_REG = "TRUE" *)`
- 综合代码禁用 `real`、`#delay`、`force/release`、`initial` 赋值寄存器
- 深度 > 16 → BRAM；深度 ≤ 16 → Distributed RAM
- 小位宽乘法 (< 8 bit) 用 LUT，大位宽用 DSP48E1

---

## 五、时序收敛实践

### 6.1 分析关键路径

1. 检查综合报告中的 **Worst Negative Slack (WNS)**
2. 分析 **Total Negative Slack (TNS)** 分布
3. 定位延迟最大的逻辑层级

### 6.2 优化策略

1. **插入流水线寄存器**（最有效）

   - 在组合逻辑中间插入 FF
   - 每级延迟 < 目标时钟周期的 70%
2. **逻辑重定时（Retiming）**

   ```tcl
   set_property RETIMING true [get_cells u_pipeline]
   ```
3. **关键信号优化**

   - 对高扇出信号使用 `set_max_fanout 32`
   - 关键模块手动布局 `set_property LOC ...`

**实测数据**：

- 原始设计：关键路径 15 ns，目标 10 ns（不满足）
- 插入 2 级流水线后：关键路径 7 ns（满足 + 30% 裕量）
- 延迟代价：2 个时钟周期（可接受）

---

## 六、综合实现与仿真

Vivado Tcl 流程命令（综合、实现、比特流生成、时序/资源报告）以及 Testbench 编写规范和 xsim 仿真方法，详见 `references/tcl-and-simulation.md`。

**快速参考**：

- 综合：`launch_runs synth_1 -jobs 4` → `wait_on_run synth_1`
- 实现：`launch_runs impl_1 -jobs 4` → `wait_on_run impl_1`
- 比特流：`launch_runs impl_1 -to_step write_bitstream -jobs 4`
- 仿真：`xvlog` → `xelab` → `xsim`，或 Tcl `launch_simulation`

---

## 七、上板调试

### 7.1 ILA（集成逻辑分析仪）

1. 在 RTL 中标记需要调试的信号：
   ```verilog
   (* MARK_DEBUG = "TRUE" *) reg [7:0] debug_data;
   (* MARK_DEBUG = "TRUE" *) wire      debug_valid;
   ```
2. 综合后通过 Vivado GUI **Set Up Debug** 向导插入 ILA 核，或在 XDC 中创建：
   ```tcl
   create_debug_core u_ila_0 ila
   set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
   ```
3. 设置触发条件（如错误标志、特定状态），捕获数据后在 Vivado 中分析。

### 7.2 VIO（虚拟输入/输出）

- 实时修改参数（如滤波器系数）
- 监控内部状态寄存器
- 无需重新编译即可调试

### 7.3 调试实例

- **现象**：YUV 输出偶发错误值
- **方法**：ILA 捕获乘法中间结果
- **根因**：符号扩展错误导致高位溢出
- **解决**：修复有符号数扩展逻辑

---

## 八、综合与实现检查清单

综合与实现后需关注以下 Vivado 输出：

- **Critical Warnings**：必须全部解决
- **Timing Summary**：确认所有时序约束满足（WNS > 0，WHS > 0）
- **Utilization Report**：建议逻辑资源占用 ≤ 70%，BRAM ≤ 80%
- **DRC**：实现后运行 DRC 确保无违规
- **CDC 报告**：`report_cdc` 检查跨时钟域问题

---

## 九、黄金法则

1. **功能优先，优化其次** — 先确保设计功能正确，再优化时序和资源
2. **早约束，晚放松** — 先施加严格时序约束，再根据情况适当放松
3. **寄存所有边界** — 模块输入输出必须寄存，避免时序耦合
4. **注释即代码** — 清晰的注释和文档比复杂的设计更重要
5. **测试驱动开发** — 先写 testbench，再实现功能
6. **禁用隐式线网** — 文件开头使用 `` `default_nettype none `` 防止拼写错误产生隐式 wire

---

## 参考文档

- **详细设计模式**：见 `references/design-patterns.md`（CDC 同步器、异步 FIFO、AXI-Stream 接口等）
- **常见问题排查**：见 `references/troubleshooting.md`（时序违例、亚稳态、仿真综合不一致等）
- **器件选型指南**：见 `references/device-selection.md`（Xilinx 7 系列 Artix/Kintex/Virtex 选型）
- **综合属性与约束**：见 `references/synthesis-and-constraints.md`（综合属性、资源优化、原语、XDC）
- **Tcl 命令与仿真**：见 `references/tcl-and-simulation.md`（Vivado Tcl 流程、xsim 仿真、Testbench）

---

*本指南基于真实工程经验整理，持续更新。*
