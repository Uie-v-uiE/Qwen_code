# 全局接口与架构约束 (强制遵守)

## 1. 统一视频流接口 (类 AXI-Stream)
所有图像处理模块（ISP, CNN, 滤波等）必须使用以下标准接口，禁止自定义散乱信号：
```verilog
input  wire        clk,
input  wire        rst_n,
// Input Stream
input  wire [7:0]  s_axis_tdata,
input  wire        s_axis_tvalid,
output wire        s_axis_tready,
input  wire        s_axis_tlast,  // End of Line (EOL)
input  wire        s_axis_tuser,  // Start of Frame (SOF)
// Output Stream
output wire [7:0]  m_axis_tdata,
output wire        m_axis_tvalid,
input  wire        m_axis_tready,
output wire        m_axis_tlast,
output wire        m_axis_tuser