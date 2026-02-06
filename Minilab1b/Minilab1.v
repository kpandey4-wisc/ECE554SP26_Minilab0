
module Minilab1 (
    input  wire        CLOCK_50,
    input  wire        CLOCK2_50,
    input  wire        CLOCK3_50,
    input  wire        CLOCK4_50,
    
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5,
    
    output wire [9:0]  LEDR,
    
    input  wire [3:0]  KEY,
    input  wire [9:0]  SW
);

    wire clk;
    wire rst_n;
    
    assign clk = CLOCK_50;
    assign rst_n = KEY[0];  // Active low reset (directly from button)
    

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_FETCH   = 3'd1;
    localparam [2:0] ST_COMPUTE = 3'd2;
    localparam [2:0] ST_DONE    = 3'd3;
    
    reg [2:0] state;
    

    wire [31:0] avm_address;
    wire        avm_read;
    wire [63:0] avm_readdata;
    wire        avm_readdatavalid;
    wire        avm_waitrequest;
    
    wire        mem_ctrl_done;
    wire [2:0]  mem_ctrl_state;
    reg         mem_ctrl_start;
    
    // FIFO interface (mem_controller -> mat_vec_mult)
    wire [7:0]  fifo_a_data_0, fifo_a_data_1, fifo_a_data_2, fifo_a_data_3;
    wire [7:0]  fifo_a_data_4, fifo_a_data_5, fifo_a_data_6, fifo_a_data_7;
    wire [7:0]  fifo_a_wren;
    wire [7:0]  fifo_a_full;
    wire [7:0]  fifo_b_data;
    wire        fifo_b_wren;
    wire        fifo_b_full;
    

    wire        all_fifos_full;
    wire        compute_done;
    reg         start_compute;
    reg         clr_accum;
    
    wire [23:0] mac_out_0, mac_out_1, mac_out_2, mac_out_3;
    wire [23:0] mac_out_4, mac_out_5, mac_out_6, mac_out_7;
    

    mem_wrapper mem_inst (
        .clk(clk),
        .reset_n(rst_n),
        .address(avm_address),
        .read(avm_read),
        .readdata(avm_readdata),
        .readdatavalid(avm_readdatavalid),
        .waitrequest(avm_waitrequest)
    );
    

    mem_controller mem_ctrl_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(mem_ctrl_start),
        
        .avm_address(avm_address),
        .avm_read(avm_read),
        .avm_readdata(avm_readdata),
        .avm_readdatavalid(avm_readdatavalid),
        .avm_waitrequest(avm_waitrequest),
        
        .fifo_a_data_0(fifo_a_data_0),
        .fifo_a_data_1(fifo_a_data_1),
        .fifo_a_data_2(fifo_a_data_2),
        .fifo_a_data_3(fifo_a_data_3),
        .fifo_a_data_4(fifo_a_data_4),
        .fifo_a_data_5(fifo_a_data_5),
        .fifo_a_data_6(fifo_a_data_6),
        .fifo_a_data_7(fifo_a_data_7),
        .fifo_a_wren(fifo_a_wren),
        .fifo_a_full(fifo_a_full),
        
        .fifo_b_data(fifo_b_data),
        .fifo_b_wren(fifo_b_wren),
        .fifo_b_full(fifo_b_full),
        
        .done(mem_ctrl_done),
        .state_out(mem_ctrl_state)
    );
    

    mat_vec_mult mat_vec_mult_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_compute(start_compute),
        .clr_accum(clr_accum),
        
        .fifo_a_data_0(fifo_a_data_0),
        .fifo_a_data_1(fifo_a_data_1),
        .fifo_a_data_2(fifo_a_data_2),
        .fifo_a_data_3(fifo_a_data_3),
        .fifo_a_data_4(fifo_a_data_4),
        .fifo_a_data_5(fifo_a_data_5),
        .fifo_a_data_6(fifo_a_data_6),
        .fifo_a_data_7(fifo_a_data_7),
        .fifo_a_wren(fifo_a_wren),
        .fifo_a_full(fifo_a_full),
        
        .fifo_b_data(fifo_b_data),
        .fifo_b_wren(fifo_b_wren),
        .fifo_b_full(fifo_b_full),
        
        .all_fifos_full(all_fifos_full),
        .compute_done(compute_done),
        
        .mac_out_0(mac_out_0),
        .mac_out_1(mac_out_1),
        .mac_out_2(mac_out_2),
        .mac_out_3(mac_out_3),
        .mac_out_4(mac_out_4),
        .mac_out_5(mac_out_5),
        .mac_out_6(mac_out_6),
        .mac_out_7(mac_out_7)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            mem_ctrl_start <= 1'b0;
            start_compute <= 1'b0;
            clr_accum <= 1'b0;
        end else begin
            clr_accum <= 1'b0;  // Default
            
            case (state)
                ST_IDLE: begin
                    mem_ctrl_start <= 1'b0;
                    start_compute <= 1'b0;
                    if (!KEY[1]) begin
                        clr_accum <= 1'b1;
                        state <= ST_FETCH;
                    end
                end
                
                ST_FETCH: begin
                    mem_ctrl_start <= 1'b1;
                    start_compute <= 1'b0;
                    if (mem_ctrl_done) begin
                        state <= ST_COMPUTE;
                    end
                end
                
                ST_COMPUTE: begin
                    mem_ctrl_start <= 1'b0;
                    start_compute <= 1'b1;
                    if (compute_done) begin
                        state <= ST_DONE;
                    end
                end
                
                ST_DONE: begin
                    mem_ctrl_start <= 1'b0;
                    start_compute <= 1'b0;
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
    

    reg [23:0] selected_mac_out;
    
    always @(*) begin
        case (SW[2:0])
            3'd0: selected_mac_out = mac_out_0;
            3'd1: selected_mac_out = mac_out_1;
            3'd2: selected_mac_out = mac_out_2;
            3'd3: selected_mac_out = mac_out_3;
            3'd4: selected_mac_out = mac_out_4;
            3'd5: selected_mac_out = mac_out_5;
            3'd6: selected_mac_out = mac_out_6;
            3'd7: selected_mac_out = mac_out_7;
            default: selected_mac_out = 24'd0;
        endcase
    end
    
    // 7-Segment Decoders
    wire [6:0] hex0_val, hex1_val, hex2_val, hex3_val, hex4_val, hex5_val;
    
    seg7_decoder seg0 (.hex_val(selected_mac_out[3:0]),   .seg(hex0_val));
    seg7_decoder seg1 (.hex_val(selected_mac_out[7:4]),   .seg(hex1_val));
    seg7_decoder seg2 (.hex_val(selected_mac_out[11:8]),  .seg(hex2_val));
    seg7_decoder seg3 (.hex_val(selected_mac_out[15:12]), .seg(hex3_val));
    seg7_decoder seg4 (.hex_val(selected_mac_out[19:16]), .seg(hex4_val));
    seg7_decoder seg5 (.hex_val(selected_mac_out[23:20]), .seg(hex5_val));
    
    // SW[9] enables display
    assign HEX0 = SW[9] ? hex0_val : 7'b1111111;
    assign HEX1 = SW[9] ? hex1_val : 7'b1111111;
    assign HEX2 = SW[9] ? hex2_val : 7'b1111111;
    assign HEX3 = SW[9] ? hex3_val : 7'b1111111;
    assign HEX4 = SW[9] ? hex4_val : 7'b1111111;
    assign HEX5 = SW[9] ? hex5_val : 7'b1111111;
    
    wire [7:0] debug_rom_byte;
    assign debug_rom_byte = avm_readdata[63:56];
    
    assign LEDR[2:0] = SW[8] ? debug_rom_byte[2:0] : state;
    assign LEDR[5:3] = SW[8] ? debug_rom_byte[5:3] : mem_ctrl_state;
    assign LEDR[6]   = SW[8] ? debug_rom_byte[6]   : all_fifos_full;
    assign LEDR[7]   = SW[8] ? debug_rom_byte[7]   : compute_done;
    assign LEDR[8]   = mem_ctrl_done;
    assign LEDR[9]   = avm_readdatavalid;

endmodule