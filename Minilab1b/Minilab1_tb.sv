`timescale 1ns/1ps

module Minilab1_tb;

    // Clock and reset
    reg CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;
    
    // Outputs
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [9:0] LEDR;
    
    // Expected results
    reg [23:0] expected_0, expected_1, expected_2, expected_3;
    reg [23:0] expected_4, expected_5, expected_6, expected_7;
    
    // Timeout counter
    integer timeout_cnt;
    
    // DUT
    Minilab1 dut (
        .CLOCK_50(CLOCK_50),
        .CLOCK2_50(1'b0),
        .CLOCK3_50(1'b0),
        .CLOCK4_50(1'b0),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR),
        .KEY(KEY),
        .SW(SW)
    );
    
    // Clock generation (50 MHz = 20ns period)
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;
    
    // Main test
    initial begin
        // Expected values
        expected_0 = 24'h0012CC;
        expected_1 = 24'h00550C;
        expected_2 = 24'h00974C;
        expected_3 = 24'h00D98C;
        expected_4 = 24'h011BCC;
        expected_5 = 24'h015E0C;
        expected_6 = 24'h01A04C;
        expected_7 = 24'h01E28C;
        
        $display("\n============================================");
        $display("  Minilab1 Testbench - With Real memory.v");
        $display("============================================\n");
        
        // Initialize
        KEY = 4'b1111;  // All keys released (active low)
        SW = 10'b0;
        
        // Reset
        $display("[%0t] Applying reset...", $time);
        KEY[0] = 0;  // Assert reset
        #100;
        KEY[0] = 1;  // Release reset
        #100;
        
        $display("[%0t] Reset complete. State = %d", $time, LEDR[2:0]);
        
        // Start operation
        $display("[%0t] Pressing KEY[1] to start...", $time);
        KEY[1] = 0;  // Press start
        #40;
        KEY[1] = 1;  // Release
        
        // Wait for completion (with timeout)
        $display("[%0t] Waiting for DONE state (state=3)...", $time);
        
        timeout_cnt = 0;
        while (LEDR[2:0] != 3'd3 && timeout_cnt < 5000) begin
            #100;
            timeout_cnt = timeout_cnt + 1;
        end
        
        if (LEDR[2:0] == 3'd3) begin
            $display("[%0t] DONE state reached!", $time);
        end else begin
            $display("[%0t] TIMEOUT! State = %d", $time, LEDR[2:0]);
        end
        
        #100;
        
        // Check results
        $display("\n========== MAC OUTPUT VERIFICATION ==========");
        
        // Enable display
        SW[9] = 1;
        
        // Check each MAC
        if (dut.mat_vec_mult_inst.mac_out_0 == expected_0)
            $display("  [PASS] MAC[0]: 0x%06X", dut.mat_vec_mult_inst.mac_out_0);
        else
            $display("  [FAIL] MAC[0]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_0, expected_0);
            
        if (dut.mat_vec_mult_inst.mac_out_1 == expected_1)
            $display("  [PASS] MAC[1]: 0x%06X", dut.mat_vec_mult_inst.mac_out_1);
        else
            $display("  [FAIL] MAC[1]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_1, expected_1);
            
        if (dut.mat_vec_mult_inst.mac_out_2 == expected_2)
            $display("  [PASS] MAC[2]: 0x%06X", dut.mat_vec_mult_inst.mac_out_2);
        else
            $display("  [FAIL] MAC[2]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_2, expected_2);
            
        if (dut.mat_vec_mult_inst.mac_out_3 == expected_3)
            $display("  [PASS] MAC[3]: 0x%06X", dut.mat_vec_mult_inst.mac_out_3);
        else
            $display("  [FAIL] MAC[3]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_3, expected_3);
            
        if (dut.mat_vec_mult_inst.mac_out_4 == expected_4)
            $display("  [PASS] MAC[4]: 0x%06X", dut.mat_vec_mult_inst.mac_out_4);
        else
            $display("  [FAIL] MAC[4]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_4, expected_4);
            
        if (dut.mat_vec_mult_inst.mac_out_5 == expected_5)
            $display("  [PASS] MAC[5]: 0x%06X", dut.mat_vec_mult_inst.mac_out_5);
        else
            $display("  [FAIL] MAC[5]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_5, expected_5);
            
        if (dut.mat_vec_mult_inst.mac_out_6 == expected_6)
            $display("  [PASS] MAC[6]: 0x%06X", dut.mat_vec_mult_inst.mac_out_6);
        else
            $display("  [FAIL] MAC[6]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_6, expected_6);
            
        if (dut.mat_vec_mult_inst.mac_out_7 == expected_7)
            $display("  [PASS] MAC[7]: 0x%06X", dut.mat_vec_mult_inst.mac_out_7);
        else
            $display("  [FAIL] MAC[7]: Got 0x%06X, Expected 0x%06X", dut.mat_vec_mult_inst.mac_out_7, expected_7);
        
        $display("==============================================\n");
        
        #100;
        $display("Simulation complete.");
        $finish;
    end
    
    // Monitor state changes
    always @(LEDR[2:0]) begin
        case (LEDR[2:0])
            3'd0: $display("[%0t] State: IDLE", $time);
            3'd1: $display("[%0t] State: FETCH", $time);
            3'd2: $display("[%0t] State: COMPUTE", $time);
            3'd3: $display("[%0t] State: DONE", $time);
        endcase
    end

endmodule