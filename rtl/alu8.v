`timescale 1ns/1ps
`default_nettype none

// 8-bit ALU. The output changes when the inputs change.
module alu8 (
    input  wire [7:0] operand_a,
    input  wire [7:0] operand_b,
    input  wire [2:0] opcode,
    output reg  [7:0] result,
    output reg        carry,
    output reg        borrow,
    output reg        overflow
);
    localparam [2:0] OP_ADD = 3'd0,
                     OP_SUB = 3'd1,
                     OP_AND = 3'd2,
                     OP_OR  = 3'd3,
                     OP_XOR = 3'd4,
                     OP_NOT = 3'd5,
                     OP_SHL = 3'd6,
                     OP_SHR = 3'd7;

    // One extra bit to keep the carry from addition.
    reg [8:0] arithmetic_result;

    always @* begin
        // Start with zero values. The selected operation changes what it needs.
        result = 8'd0;
        carry = 1'b0;
        borrow = 1'b0;
        overflow = 1'b0;
        arithmetic_result = 9'd0;

        case (opcode)
            OP_ADD: begin
                // Add a zero on the left of each input to make them 9 bits.
                arithmetic_result = {1'b0, operand_a} + {1'b0, operand_b};
                result = arithmetic_result[7:0];
                carry = arithmetic_result[8];
                // Signed overflow: same input signs, different result sign.
                overflow = ~(operand_a[7] ^ operand_b[7]) &
                            (result[7] ^ operand_a[7]);
            end
            OP_SUB: begin
                arithmetic_result = {1'b0, operand_a} - {1'b0, operand_b};
                result = arithmetic_result[7:0];
                // For this 9-bit subtraction, bit 8 is 1 when A < B.
                borrow = arithmetic_result[8];
                // Signed overflow: inputs differ in sign, result differs from A.
                overflow = (operand_a[7] ^ operand_b[7]) &
                           (result[7] ^ operand_a[7]);
            end
            OP_AND: result = operand_a & operand_b;
            OP_OR:  result = operand_a | operand_b;
            OP_XOR: result = operand_a ^ operand_b;
            OP_NOT: result = ~operand_a;
            OP_SHL: begin
                // Shift left, fill with zero, and save the bit shifted out.
                result = {operand_a[6:0], 1'b0};
                carry = operand_a[7];
            end
            OP_SHR: begin
                // Shift right, fill with zero, and save the bit shifted out.
                result = {1'b0, operand_a[7:1]};
                carry = operand_a[0];
            end
            // An opcode containing X or Z reaches this branch in simulation.
            default: begin
                result = 8'd0;
            end
        endcase
    end
endmodule

`default_nettype wire
