module bayer_to_gray #(
    parameter BAYER_COLS = 1280  // 1280 for real hardware, override for sim
)(
    input  wire        clk,       // ~D5M_PIXLCLK
    input  wire        rst_n,     // DLY_RST_2
    input  wire [11:0] iDATA,     // mCCD_DATA from CCD_Capture
    input  wire        iDVAL,     // mCCD_DVAL
    input  wire [15:0] iX_Cont,   // column counter from CCD_Capture
    input  wire [15:0] iY_Cont,   // row counter from CCD_Capture
    output reg  [7:0]  oGray,     // 8-bit grayscale output
    output reg         oDVAL      // pulses high for each output pixel
);

    // stores one full row of bayer pixels so we can look back
    reg [11:0] row_buf [0:BAYER_COLS-1];

    // pixel we just read out of the row buffer (prev row, current col)
    reg [11:0] prev_row_rd;

    // read the old value then overwrite it with the new one
    always @(posedge clk) begin
        if (iDVAL) begin
            prev_row_rd            <= row_buf[iX_Cont[10:0]];
            row_buf[iX_Cont[10:0]] <= iDATA;
        end
    end

    // pipeline stage 1 - delay everything by one pixel so we have col and col-1
    reg [11:0] prev_row_d1;  // prev row at col-1
    reg [11:0] cur_d1;       // current row at col-1
    reg        dval_d1;
    reg [15:0] x_d1, y_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_row_d1 <= 12'd0;
            cur_d1      <= 12'd0;
            dval_d1     <= 1'b0;
            x_d1        <= 16'd0;
            y_d1        <= 16'd0;
        end else begin
            dval_d1 <= iDVAL;
            x_d1    <= iX_Cont;
            y_d1    <= iY_Cont;
            if (iDVAL) begin
                prev_row_d1 <= prev_row_rd;
                cur_d1      <= iDATA;
            end
        end
    end

    // pipeline stage 2 - now all 4 pixels in the 2x2 block are aligned
    //   p_tl | p_tr   <- previous row
    //   p_bl | p_br   <- current row
    reg [11:0] p_tl, p_tr, p_bl, p_br;
    reg        dval_d2;
    reg [15:0] x_d2, y_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_tl <= 12'd0; p_tr <= 12'd0;
            p_bl <= 12'd0; p_br <= 12'd0;
            dval_d2 <= 1'b0;
            x_d2 <= 16'd0; y_d2 <= 16'd0;
        end else begin
            dval_d2 <= dval_d1;
            x_d2    <= x_d1;
            y_d2    <= y_d1;
            if (dval_d1) begin
                p_tl <= prev_row_d1;
                p_tr <= prev_row_rd;
                p_bl <= cur_d1;
                p_br <= iDATA;
            end
        end
    end

    // average the four 12-bit pixels, divide by 4, grab top 8 bits
    wire [13:0] pixel_sum;
    assign pixel_sum = {2'b0, p_tl} + {2'b0, p_tr} + {2'b0, p_bl} + {2'b0, p_br};

    wire [7:0] gray_8;
    assign gray_8 = pixel_sum[13:6]; // sum/4 then top 8 of 12 = shift right by 6 total

    // output one pixel per 2x2 block = when both X and Y are odd
    // gives us 640x480 from the 1280x960 input
    wire output_en;
    assign output_en = dval_d2 & x_d2[0] & y_d2[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            oGray <= 8'd0;
            oDVAL <= 1'b0;
        end else begin
            oDVAL <= output_en;
            if (output_en)
                oGray <= gray_8;
        end
    end

endmodule
