// Does 3x3 Sobel edge detection on the 640x480 grayscale stream.
// Two row buffers give us 3 rows at a time, and a shift register
// slides across columns for the 3x3 window.
//
// Two kernels you can pick between with filter_sel:
//
//   Gx (vertical edges):     Gy (horizontal edges):
//     [-1  0  1]               [-1 -2 -1]
//     [-2  0  2]               [ 0  0  0]
//     [-1  0  1]               [ 1  2  1]
//
// We take the absolute value and clamp to 8 bits.
// Border pixels (first 2 rows/cols) just output 0 since the
// window isn't full there.

module sobel_filter #(
    parameter WIDTH  = 640,  // 640 for real hw
    parameter HEIGHT = 480   // 480 for real hw
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  iGray,       // grayscale pixel in
    input  wire        iDVAL,       // valid in
    input  wire        filter_sel,  // 0 = Gx, 1 = Gy
    output reg  [7:0]  oEdge,       // edge pixel out
    output reg         oDVAL        // valid out
);

    // track where we are in the 640x480 image
    reg [9:0] col_cnt;
    reg [9:0] row_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 10'd0;
            row_cnt <= 10'd0;
        end else if (iDVAL) begin
            if (col_cnt == (WIDTH - 1)) begin
                col_cnt <= 10'd0;
                if (row_cnt == (HEIGHT - 1))
                    row_cnt <= 10'd0;
                else
                    row_cnt <= row_cnt + 10'd1;
            end else begin
                col_cnt <= col_cnt + 10'd1;
            end
        end
    end

    // two row buffers, WIDTH x 8 bits each
    // row_buf_0 holds the oldest row (i-2)
    // row_buf_1 holds the middle row (i-1)
    // the live input iGray is the newest row (i)
    reg [7:0] row_buf_0 [0:WIDTH-1];
    reg [7:0] row_buf_1 [0:WIDTH-1];

    reg [7:0] rb0_rd, rb1_rd;

    // shift data down: buf1 -> buf0, new -> buf1
    always @(posedge clk) begin
        if (iDVAL) begin
            rb0_rd <= row_buf_0[col_cnt];
            rb1_rd <= row_buf_1[col_cnt];
            row_buf_0[col_cnt] <= row_buf_1[col_cnt];
            row_buf_1[col_cnt] <= iGray;
        end
    end

    // 3x3 pixel window (slides left to right)
    //   p00 p01 p02   <- row i-2 (from row_buf_0)
    //   p10 p11 p12   <- row i-1 (from row_buf_1)
    //   p20 p21 p22   <- row i   (current input)
    reg [7:0] p00, p01, p02;
    reg [7:0] p10, p11, p12;
    reg [7:0] p20, p21, p22;

    reg        dval_p1;
    reg [9:0]  col_p1, row_p1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {p00, p01, p02} <= 24'd0;
            {p10, p11, p12} <= 24'd0;
            {p20, p21, p22} <= 24'd0;
            dval_p1 <= 1'b0;
            col_p1  <= 10'd0;
            row_p1  <= 10'd0;
        end else begin
            dval_p1 <= iDVAL;
            col_p1  <= col_cnt;
            row_p1  <= row_cnt;

            if (iDVAL) begin
                // shift left, new pixel enters on the right
                p00 <= p01; p01 <= p02; p02 <= rb0_rd;
                p10 <= p11; p11 <= p12; p12 <= rb1_rd;
                p20 <= p21; p21 <= p22; p22 <= iGray;
            end
        end
    end

    // sobel convolution
    // doing the math with signed wires so negatives work right
    // just widen the 8-bit unsigned pixels to 12-bit signed before arithmetic
    wire signed [11:0] s00, s01, s02, s10, s12, s20, s21, s22;
    assign s00 = {4'b0, p00};
    assign s01 = {4'b0, p01};
    assign s02 = {4'b0, p02};
    assign s10 = {4'b0, p10};
    assign s12 = {4'b0, p12};
    assign s20 = {4'b0, p20};
    assign s21 = {4'b0, p21};
    assign s22 = {4'b0, p22};

    // gx = -p00 + p02 - 2*p10 + 2*p12 - p20 + p22
    wire signed [11:0] gx;
    assign gx = (s02 - s00) + ((s12 - s10) * 12'sd2) + (s22 - s20);

    // gy = -p00 - 2*p01 - p02 + p20 + 2*p21 + p22
    wire signed [11:0] gy;
    assign gy = (s20 - s00) + ((s21 - s01) * 12'sd2) + (s22 - s02);

    wire signed [11:0] conv_result;
    assign conv_result = filter_sel ? gy : gx;

    // take absolute value
    wire [10:0] abs_val;
    assign abs_val = conv_result[11] ? (~conv_result[10:0] + 11'd1) : conv_result[10:0];

    // clamp to 255 if bigger than 8 bits
    wire [7:0] clamped;
    assign clamped = (|abs_val[10:8]) ? 8'hFF : abs_val[7:0];

    // border handling - no valid 3x3 window for first 2 rows and 2 cols
    wire is_border;
    assign is_border = (row_p1 < 10'd2) | (col_p1 < 10'd2);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            oEdge <= 8'd0;
            oDVAL <= 1'b0;
        end else begin
            oDVAL <= dval_p1;
            if (dval_p1)
                oEdge <= is_border ? 8'd0 : clamped;
        end
    end

endmodule
