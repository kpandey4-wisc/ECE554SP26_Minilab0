module MAC (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        En,
    input  wire        Clr,
    input  wire [7:0]  Ain,
    input  wire [7:0]  Bin,
    output reg  [23:0] Cout,
    output reg         En_out,
    output reg  [7:0]  Bout
);

    // Pipeline registers
    reg [15:0] mult_reg;    // Stage 1: registered multiply result
    reg        en_pipe;     // Pipelined enable for accumulate stage
    
    // Stage 1: Multiply (combinational) -> register
    wire [15:0] mult_result;
    assign mult_result = Ain * Bin;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_reg <= 16'd0;
            en_pipe <= 1'b0;
        end else begin
            mult_reg <= mult_result;
            en_pipe <= En;
        end
    end
    
    // Stage 2: Accumulate (uses pipelined multiply result)
    wire [23:0] add_result;
    assign add_result = {8'b0, mult_reg} + Cout;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            Cout <= 24'd0;
        else if (Clr)
            Cout <= 24'd0;
        else if (en_pipe)
            Cout <= add_result;
    end
    
    // Propagate En and B to next MAC (1 cycle delay for systolic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            En_out <= 1'b0;
            Bout <= 8'd0;
        end else begin
            En_out <= En;
            Bout <= Bin;
        end
    end

endmodule