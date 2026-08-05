# FPGA Verilog 编码规范 (强制)

## 1. 文件头与宏
所有 `.v` 文件第一行必须是：
`default_nettype none
文件末尾必须是：
`default_nettype wire

## 2. 命名规范
- 时钟：`clk` 或 `clk_<域名>` (如 `clk_pix`, `clk_eth`)。
- 复位：`rst_n` (低电平有效)。
- 参数：全大写 `parameter DATA_WIDTH = 8;`。
- 内部寄存器：`<name>_r` 或 `<name>_reg`。
- 组合逻辑：`<name>_c` 或 `<name>_next`。

## 3. 时序与复位
- **强制使用异步复位，同步释放**。
- 跨时钟域单 bit 信号必须打两拍 (`ASYNC_REG="TRUE"`)。
- 跨时钟域多 bit 数据必须使用异步 FIFO 或 DMEM。
- 视频流跨时钟域使用 Video FIFO。

## 4. 状态机 (FSM)
- 必须使用三段式或两段式写法。
- 状态编码使用 `localparam`，推荐 One-hot 或 Binary。
- 必须有 `default` 分支防止死锁。

## 5. 接口规范
- 视频流内部统一使用类 AXI-Stream 接口：`valid`, `ready`, `data`, `last`, `user` (SOF)。
- 当 `ready` 常拉高时，可简化为 `valid` + `data` + `de`。