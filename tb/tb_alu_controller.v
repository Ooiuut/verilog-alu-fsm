`timescale 1ns/1ps

module tb_alu_controller;
    reg clk, rst, start;
    reg [2:0] opcode;
    reg [7:0] operand_a, operand_b;
    wire busy, done;
    wire [7:0] result;
    wire carry, borrow, overflow;
    reg [7:0] retained_result;
    reg [2:0] retained_flags;
    integer checks, operations;

    alu_controller dut (
        .clk(clk), .rst(rst), .start(start), .opcode(opcode),
        .operand_a(operand_a), .operand_b(operand_b),
        .busy(busy), .done(done), .result(result),
        .carry(carry), .borrow(borrow), .overflow(overflow)
    );

    always #5 clk = ~clk;

    // Case inequality also rejects X/Z values on every public output.
    task check_outputs;
        input expected_busy, expected_done;
        input [7:0] expected_result;
        input [2:0] expected_flags; // {carry, borrow, overflow}
        begin
            checks = checks + 1;
            if ({busy, done, result, carry, borrow, overflow} !==
                {expected_busy, expected_done, expected_result, expected_flags}) begin
                $display("FAIL at %0t, check %0d, completed operation %0d",
                         $time, checks, operations);
                $display("  got busy=%b done=%b result=%h flags=%b%b%b",
                         busy, done, result, carry, borrow, overflow);
                $display("  expected busy=%b done=%b result=%h flags=%b",
                         expected_busy, expected_done, expected_result, expected_flags);
                $stop;
            end
        end
    endtask

    task sample;
        input expected_busy, expected_done;
        input [7:0] expected_result;
        input [2:0] expected_flags;
        begin
            @(posedge clk); #1;
            check_outputs(expected_busy, expected_done, expected_result, expected_flags);
        end
    endtask

    // Each call checks accept, execute, and done-to-idle edges. Requests
    // and changed operands while busy must neither alter nor queue work.
    task run_operation;
        input [2:0] op;
        input [7:0] a, b, expected_result;
        input [2:0] expected_flags;
        begin
            @(negedge clk);
            start = 1; opcode = op; operand_a = a; operand_b = b;
            sample(1, 0, retained_result, retained_flags);
            @(negedge clk);
            opcode = ~op; operand_a = ~a; operand_b = ~b;
            sample(1, 1, expected_result, expected_flags);
            operations = operations + 1;
            sample(0, 0, expected_result, expected_flags);
            retained_result = expected_result; retained_flags = expected_flags;
        end
    endtask

    initial begin
        clk = 0; rst = 1; start = 0; opcode = 0;
        operand_a = 0; operand_b = 0;
        checks = 0; operations = 0; retained_result = 0; retained_flags = 0;
        $dumpfile("sim/alu_controller.vcd");
        $dumpvars(0, tb_alu_controller);
        sample(0, 0, 8'h00, 3'b000);
        @(negedge clk); rst = 0;
        sample(0, 0, 8'h00, 3'b000);

        // Literal, hand-checked vectors distinguish unsigned and signed flags.
        run_operation(0, 8'h12, 8'h34, 8'h46, 3'b000);
        run_operation(0, 8'hff, 8'h01, 8'h00, 3'b100);
        run_operation(0, 8'h7f, 8'h01, 8'h80, 3'b001);
        run_operation(0, 8'h80, 8'h80, 8'h00, 3'b101);
        run_operation(0, 8'h80, 8'hff, 8'h7f, 3'b101);
        run_operation(0, 8'h00, 8'h00, 8'h00, 3'b000);
        run_operation(0, 8'ha5, 8'h5a, 8'hff, 3'b000);
        run_operation(1, 8'h09, 8'h04, 8'h05, 3'b000);
        run_operation(1, 8'h00, 8'h01, 8'hff, 3'b010);
        run_operation(1, 8'h80, 8'h01, 8'h7f, 3'b001);
        run_operation(1, 8'h7f, 8'hff, 8'h80, 3'b011);
        run_operation(1, 8'hff, 8'h01, 8'hfe, 3'b000);
        run_operation(1, 8'h80, 8'h80, 8'h00, 3'b000);
        run_operation(1, 8'h00, 8'h80, 8'h80, 3'b011);
        run_operation(2, 8'ha5, 8'h3c, 8'h24, 3'b000);
        run_operation(2, 8'hff, 8'h00, 8'h00, 3'b000);
        run_operation(3, 8'ha5, 8'h3c, 8'hbd, 3'b000);
        run_operation(3, 8'h00, 8'hff, 8'hff, 3'b000);
        run_operation(4, 8'ha5, 8'h3c, 8'h99, 3'b000);
        run_operation(4, 8'hff, 8'hff, 8'h00, 3'b000);
        run_operation(5, 8'h55, 8'hff, 8'haa, 3'b000);
        run_operation(5, 8'h00, 8'h00, 8'hff, 3'b000);
        run_operation(5, 8'hff, 8'h5a, 8'h00, 3'b000);
        run_operation(6, 8'h81, 8'hff, 8'h02, 3'b100);
        run_operation(6, 8'h7f, 8'h00, 8'hfe, 3'b000);
        run_operation(6, 8'h80, 8'h55, 8'h00, 3'b100);
        run_operation(6, 8'h00, 8'haa, 8'h00, 3'b000);
        run_operation(7, 8'h81, 8'hff, 8'h40, 3'b100);
        run_operation(7, 8'h80, 8'h00, 8'h40, 3'b000);
        run_operation(7, 8'h01, 8'h55, 8'h00, 3'b100);
        run_operation(7, 8'h00, 8'haa, 8'h00, 3'b000);
        run_operation(6, 8'hff, 8'h00, 8'hfe, 3'b100);
        run_operation(3'bx10, 8'hff, 8'hff, 8'h00, 3'b000);
        run_operation(3'bzz1, 8'hff, 8'hff, 8'h00, 3'b000);

        // Rejected busy requests must not appear later after start falls.
        run_operation(6, 8'hff, 8'h00, 8'hfe, 3'b100);
        @(negedge clk); start = 0;
        sample(0, 0, 8'hfe, 3'b100);
        sample(0, 0, 8'hfe, 3'b100);
        sample(0, 0, 8'hfe, 3'b100);

        // Reset in idle clears both nonzero data and flags, synchronously.
        @(negedge clk); start = 0; rst = 1;
        #1; check_outputs(0, 0, 8'hfe, 3'b100);
        sample(0, 0, 8'h00, 3'b000);
        @(negedge clk); rst = 0;
        sample(0, 0, 8'h00, 3'b000);

        // Reset during execution cancels the accepted request, even with start high.
        @(negedge clk); start = 1; opcode = 0; operand_a = 8'h7f; operand_b = 1;
        sample(1, 0, 8'h00, 3'b000);
        @(negedge clk); rst = 1;
        #1; check_outputs(1, 0, 8'h00, 3'b000);
        sample(0, 0, 8'h00, 3'b000);
        @(negedge clk); rst = 0; start = 0;
        sample(0, 0, 8'h00, 3'b000);
        sample(0, 0, 8'h00, 3'b000);

        // Reset in DONE clears the completed result and ends the done pulse.
        @(negedge clk); start = 1; opcode = 1; operand_a = 0; operand_b = 1;
        sample(1, 0, 8'h00, 3'b000);
        @(negedge clk); start = 0;
        sample(1, 1, 8'hff, 3'b010);
        operations = operations + 1;
        @(negedge clk); rst = 1;
        #1; check_outputs(1, 1, 8'hff, 3'b010);
        sample(0, 0, 8'h00, 3'b000);
        @(negedge clk); rst = 0;
        sample(0, 0, 8'h00, 3'b000);

        // Held-high start repeats every three edges, sampling fresh idle inputs.
        @(negedge clk); start = 1; opcode = 0; operand_a = 1; operand_b = 2;
        sample(1, 0, 8'h00, 3'b000);
        sample(1, 1, 8'h03, 3'b000);
        operations = operations + 1;
        @(negedge clk); opcode = 1; operand_a = 0; operand_b = 1;
        sample(0, 0, 8'h03, 3'b000);
        sample(1, 0, 8'h03, 3'b000);
        @(negedge clk); opcode = 0; operand_a = 8'hff; operand_b = 1;
        sample(1, 1, 8'hff, 3'b010);
        operations = operations + 1;
        sample(0, 0, 8'hff, 3'b010);
        @(negedge clk); start = 0;
        sample(0, 0, 8'hff, 3'b010);
        sample(0, 0, 8'hff, 3'b010);
        $display("PASS: %0d output checks, %0d completed operations", checks, operations);
        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: testbench timeout");
        $stop;
    end
endmodule
