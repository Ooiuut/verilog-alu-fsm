`timescale 1ns/1ps
`default_nettype none

// Environment check only; this is not the research exercise.
module tb_smoke_dff;
    reg clk;
    reg rst;
    reg d;
    wire q;

    smoke_dff dut (
        .clk(clk),
        .rst(rst),
        .d(d),
        .q(q)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;  // 10 ns clock period; testbench only.

    initial begin
        $dumpfile("sim/smoke.vcd");
        $dumpvars(0, tb_smoke_dff);

        rst = 1'b1;
        d = 1'b1;

        // Check 1 ns after each rising edge, after nonblocking updates.
        @(posedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Initial reset failed");
            $stop;
        end

        // Drive inputs on falling edges to avoid races with the DUT.
        @(negedge clk);
        rst = 1'b0;
        d = 1'b1;
        @(posedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Capture of 1 failed");
            $stop;
        end

        @(negedge clk);
        d = 1'b0;
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Output changed between rising edges");
            $stop;
        end
        @(posedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Capture of 0 failed");
            $stop;
        end

        @(negedge clk);
        d = 1'b1;
        @(posedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Second capture of 1 failed");
            $stop;
        end

        @(negedge clk);
        rst = 1'b1;
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Reset acted before the rising edge");
            $stop;
        end
        @(posedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Reset did not override d = 1");
            $stop;
        end

        $display("PASS: smoke D flip-flop (7 checks)");
        $finish;
    end

    // Fail instead of hanging if the clock or stimulus stops progressing.
    initial begin
        #200;
        $display("FAIL: Smoke test timed out");
        $stop;
    end
endmodule

`default_nettype wire
