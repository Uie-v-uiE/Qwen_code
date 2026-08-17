`timescale 1ns / 1ps
`default_nettype none
module serializer_10_to_1 (
    input       reset,
    input       paralell_clk,
    input       serial_clk_5x,
    input [9:0] paralell_data,

    output serial_data_out
);

    wire cascade1;
    wire cascade2;

    OSERDESE2 #(
        .DATA_RATE_OQ  ("DDR"),     // DDR, SDR
        .DATA_RATE_TQ  ("SDR"),     // DDR, BUF, SDR
        .DATA_WIDTH    (10),        // Parallel data width (2-8,10,14)
        .INIT_OQ       (1'b0),      // Initial value of OQ output (1'b0,1'b1)
        .INIT_TQ       (1'b0),      // Initial value of TQ output (1'b0,1'b1)
        .SERDES_MODE   ("MASTER"),  // MASTER, SLAVE
        .SRVAL_OQ      (1'b0),      // OQ output value when RST is used (1'b0,1'b1)
        .SRVAL_TQ      (1'b0),      // TQ output value when RST is used (1'b0,1'b1)
        .TBYTE_CTL     ("FALSE"),   // Enable tristate byte operation (FALSE, TRUE)
        .TBYTE_SRC     ("FALSE"),   // Tristate byte source (FALSE, TRUE)
        .TRISTATE_WIDTH(1)          // 3-state converter width (1,4)
    ) OSERDESE2_Master (
        .OFB      (),                  // 1-bit output: Feedback path for data
        .OQ       (serial_data_out),   // 1-bit output: Data path output
        // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .TBYTEOUT (),                  // 1-bit output: Byte group tristate
        .TFB      (),                  // 1-bit output: 3-state control
        .TQ       (),                  // 1-bit output: 3-state control
        .CLK      (serial_clk_5x),     // 1-bit input: High speed clock
        .CLKDIV   (paralell_clk),      // 1-bit input: Divided clock
        // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
        .D1       (paralell_data[0]),
        .D2       (paralell_data[1]),
        .D3       (paralell_data[2]),
        .D4       (paralell_data[3]),
        .D5       (paralell_data[4]),
        .D6       (paralell_data[5]),
        .D7       (paralell_data[6]),
        .D8       (paralell_data[7]),
        .OCE      (1'b1),              // 1-bit input: Output data clock enable
        .RST      (reset),             // 1-bit input: Reset
        // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
        .SHIFTIN1 (cascade1),
        .SHIFTIN2 (cascade2),
        // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
        .T1       (1'b0),
        .T2       (1'b0),
        .T3       (1'b0),
        .T4       (1'b0),
        .TBYTEIN  (1'b0),              // 1-bit input: Byte group tristate
        .TCE      (1'b0)               // 1-bit input: 3-state clock enable
    );

    OSERDESE2 #(
        .DATA_RATE_OQ  ("DDR"),    // DDR, SDR
        .DATA_RATE_TQ  ("SDR"),    // DDR, BUF, SDR
        .DATA_WIDTH    (10),       // Parallel data width (2-8,10,14)
        .INIT_OQ       (1'b0),     // Initial value of OQ output (1'b0,1'b1)
        .INIT_TQ       (1'b0),     // Initial value of TQ output (1'b0,1'b1)
        .SERDES_MODE   ("SLAVE"),  // MASTER, SLAVE
        .SRVAL_OQ      (1'b0),     // OQ output value when RST is used (1'b0,1'b1)
        .SRVAL_TQ      (1'b0),     // TQ output value when RST is used (1'b0,1'b1)
        .TBYTE_CTL     ("FALSE"),  // Enable tristate byte operation (FALSE, TRUE)
        .TBYTE_SRC     ("FALSE"),  // Tristate byte source (FALSE, TRUE)
        .TRISTATE_WIDTH(1)         // 3-state converter width (1,4)
    ) OSERDESE2_inst (
        .OFB      (),                  // 1-bit output: Feedback path for data
        .OQ       (),                  // 1-bit output: Data path output
        // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
        .SHIFTOUT1(cascade1),
        .SHIFTOUT2(cascade2),
        .TBYTEOUT (),                  // 1-bit output: Byte group tristate
        .TFB      (),                  // 1-bit output: 3-state control
        .TQ       (),                  // 1-bit output: 3-state control
        .CLK      (serial_clk_5x),     // 1-bit input: High speed clock
        .CLKDIV   (paralell_clk),      // 1-bit input: Divided clock
        // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
        .D1       (1'b0),
        .D2       (1'b0),
        .D3       (paralell_data[8]),
        .D4       (paralell_data[9]),
        .D5       (1'b0),
        .D6       (1'b0),
        .D7       (1'b0),
        .D8       (1'b0),
        .OCE      (1'b1),              // 1-bit input: Output data clock enable
        .RST      (reset),             // 1-bit input: Reset
        // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
        .SHIFTIN1 (1'b0),
        .SHIFTIN2 (1'b0),
        // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
        .T1       (1'b0),
        .T2       (1'b0),
        .T3       (1'b0),
        .T4       (1'b0),
        .TBYTEIN  (1'b0),              // 1-bit input: Byte group tristate
        .TCE      (1'b0)               // 1-bit input: 3-state clock enable
    );

endmodule

`default_nettype wire
