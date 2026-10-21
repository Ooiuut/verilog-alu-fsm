`timescale 1ns/1ps
`default_nettype none

// Save the inputs, let the ALU calculate, then save the answer.
module alu_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [2:0] opcode,
    input  wire [7:0] operand_a,
    input  wire [7:0] operand_b,
    output wire       busy,
    output wire       done,
    output reg  [7:0] result,
    output reg        carry,
    output reg        borrow,
    output reg        overflow
);
    localparam [1:0] IDLE = 2'd0,
                     EXECUTE = 2'd1,
                     DONE = 2'd2;
    reg [1:0] state, next_state;
    reg [7:0] operand_a_reg, operand_b_reg;
    reg [2:0] opcode_reg;
    wire [7:0] alu_result;
    wire alu_carry, alu_borrow, alu_overflow;

    // Connect the saved inputs to the ALU.
    alu8 datapath (
        .operand_a(operand_a_reg),
        .operand_b(operand_b_reg),
        .opcode(opcode_reg),
        .result(alu_result),
        .carry(alu_carry),
        .borrow(alu_borrow),
        .overflow(alu_overflow)
    );

    // DONE lasts one cycle. We accept a new request only in IDLE.
    assign busy = (state != IDLE);
    assign done = (state == DONE);

    // Decide which state to enter at the next rising edge.
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = EXECUTE;
            end
            EXECUTE: next_state = DONE;
            DONE:    next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Registers update at the rising edge. Reset has priority.
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            operand_a_reg <= 8'd0;
            operand_b_reg <= 8'd0;
            opcode_reg <= 3'd0;
            result <= 8'd0;
            carry <= 1'b0;
            borrow <= 1'b0;
            overflow <= 1'b0;
        end else begin
            state <= next_state;
            if ((state == IDLE) && start) begin
                // Keep a copy so changing the external inputs won't affect this task.
                operand_a_reg <= operand_a;
                operand_b_reg <= operand_b;
                opcode_reg <= opcode;
            end
            if (state == EXECUTE) begin
                // The ALU has had a cycle to calculate. Save its answer and flags.
                result <= alu_result;
                carry <= alu_carry;
                borrow <= alu_borrow;
                overflow <= alu_overflow;
            end
            // Otherwise, the result and flags keep their previous values.
        end
    end
endmodule

`default_nettype wire
