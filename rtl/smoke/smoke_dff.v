`timescale 1ns/1ps
`default_nettype none

// Environment check only; this is not the research exercise.
// Plain Verilog: one-bit D flip-flop with active-high synchronous reset.
module smoke_dff (
    input  wire clk,
    input  wire rst,
    input  wire d,
    output reg  q
);
    always @(posedge clk) begin
        if (rst) begin
            q <= 1'b0;
        end else begin
            q <= d;
        end
    end
endmodule

`default_nettype wire
