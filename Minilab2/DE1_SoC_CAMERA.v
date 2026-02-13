// Added a Sobel edge detection pipeline on top of the original camera design.
// SW[1] toggles between the normal color camera feed and processed output.
// SW[2] picks between Gx (vertical edges) and Gy (horizontal edges).
// SW[3] toggles between edge detection and raw grayscale.
// Everything else (reset, exposure, zoom, etc.) works the same as before.
//
// The image processing chain is:
//   CCD_Capture (1280x960 Bayer) -> bayer_to_gray (640x480 gray)
//     -> sobel_filter (640x480 edges) -> expand to 12-bit RGB -> SDRAM
//
// I marked all my changes with "ADDED" or "CHANGED" comments.

//`define ENABLE_HPS
//`define ENABLE_USB

module DE1_SoC_CAMERA(

      ///////// ADC /////////
      inout              ADC_CS_N,
      output             ADC_DIN,
      input              ADC_DOUT,
      output             ADC_SCLK,

      ///////// AUD /////////
      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

      ///////// CLOCK2 /////////
      input              CLOCK2_50,

      ///////// CLOCK3 /////////
      input              CLOCK3_50,

      ///////// CLOCK4 /////////
      input              CLOCK4_50,

      ///////// CLOCK /////////
      input              CLOCK_50,

      ///////// DRAM /////////
      output      [12:0] DRAM_ADDR,
      output      [1:0]  DRAM_BA,
      output             DRAM_CAS_N,
      output             DRAM_CKE,
      output             DRAM_CLK,
      output             DRAM_CS_N,
      inout       [15:0] DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_RAS_N,
      output             DRAM_UDQM,
      output             DRAM_WE_N,

      ///////// FAN /////////
      output             FAN_CTRL,

      ///////// FPGA /////////
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,

      ///////// GPIO /////////
      inout     [35:0]   GPIO_0,

      ///////// HEX /////////
      output      [6:0]  HEX0,
      output      [6:0]  HEX1,
      output      [6:0]  HEX2,
      output      [6:0]  HEX3,
      output      [6:0]  HEX4,
      output      [6:0]  HEX5,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      input              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout       [3:0]  HPS_FLASH_DATA,
      output             HPS_FLASH_DCLK,
      output             HPS_FLASH_NCSO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_I2C2_SCLK,
      inout              HPS_I2C2_SDAT,
      inout              HPS_I2C_CONTROL,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// IRDA /////////
      input              IRDA_RXD,
      output             IRDA_TXD,

      ///////// KEY /////////
      input       [3:0]  KEY,

      ///////// LEDR /////////
      output      [9:0]  LEDR,

      ///////// PS2 /////////
      inout              PS2_CLK,
      inout              PS2_CLK2,
      inout              PS2_DAT,
      inout              PS2_DAT2,

      ///////// SW /////////
      input       [9:0]  SW,

      ///////// TD /////////
      input              TD_CLK27,
      input      [7:0]   TD_DATA,
      input              TD_HS,
      output             TD_RESET_N,
      input              TD_VS,

`ifdef ENABLE_USB
      ///////// USB /////////
      input              USB_B2_CLK,
      inout       [7:0]  USB_B2_DATA,
      output             USB_EMPTY,
      output             USB_FULL,
      input              USB_OE_N,
      input              USB_RD_N,
      input              USB_RESET_N,
      inout              USB_SCL,
      inout              USB_SDA,
      input              USB_WR_N,
`endif /*ENABLE_USB*/

      ///////// VGA /////////
      output      [7:0]  VGA_B,
      output             VGA_BLANK_N,
      output             VGA_CLK,
      output      [7:0]  VGA_G,
      output             VGA_HS,
      output      [7:0]  VGA_R,
      output             VGA_SYNC_N,
      output             VGA_VS,

      ///////// D5M Camera /////////
      input       [11:0] D5M_D,
      input              D5M_FVAL,
      input              D5M_LVAL,
      input              D5M_PIXLCLK,
      output             D5M_RESET_N,
      output             D5M_SCLK,
      inout              D5M_SDATA,
      input              D5M_STROBE,
      output             D5M_TRIGGER,
      output             D5M_XCLKIN
);


// wires and regs (original stuff from Terasic)
wire        [15:0]  Read_DATA1;
wire        [15:0]  Read_DATA2;

wire        [11:0]  mCCD_DATA;
wire                mCCD_DVAL;
wire                mCCD_DVAL_d;
wire        [15:0]  X_Cont;
wire        [15:0]  Y_Cont;
wire        [9:0]   X_ADDR;
wire        [31:0]  Frame_Cont;
wire                DLY_RST_0;
wire                DLY_RST_1;
wire                DLY_RST_2;
wire                DLY_RST_3;
wire                DLY_RST_4;
wire                Read;
reg         [11:0]  rCCD_DATA;
reg                 rCCD_LVAL;
reg                 rCCD_FVAL;
wire        [11:0]  sCCD_R;
wire        [11:0]  sCCD_G;
wire        [11:0]  sCCD_B;
wire                sCCD_DVAL;

wire                sdram_ctrl_clk;
wire        [9:0]   oVGA_R;
wire        [9:0]   oVGA_G;
wire        [9:0]   oVGA_B;

wire                auto_start;

// ADDED - wires for image processing pipeline
wire        [7:0]   gray_pixel;     // output of bayer_to_gray
wire                gray_dval;
wire        [7:0]   edge_pixel;     // output of sobel_filter
wire                edge_dval;

// ADDED - pick which 8-bit result to display based on SW[3]
// SW[3] = 0 -> edge detection,  SW[3] = 1 -> raw grayscale (no sobel)
wire        [7:0]   proc_pixel;
wire                proc_pixel_dval;

assign proc_pixel      = SW[3] ? gray_pixel : edge_pixel;
assign proc_pixel_dval = SW[3] ? gray_dval  : edge_dval;

// ADDED - expand 8-bit to 12-bit for SDRAM packing
// replicate top 4 bits to fill the lower nibble
wire        [11:0]  proc_R, proc_G, proc_B;
wire                proc_DVAL;

assign proc_R    = {proc_pixel, proc_pixel[7:4]};
assign proc_G    = {proc_pixel, proc_pixel[7:4]};
assign proc_B    = {proc_pixel, proc_pixel[7:4]};
assign proc_DVAL = proc_pixel_dval;

// ADDED - mux between original color and processed output
// SW[1] = 0 -> normal camera,  SW[1] = 1 -> processed (gray or edge)
wire        [11:0]  final_R, final_G, final_B;
wire                final_DVAL;

assign final_R    = SW[1] ? proc_R    : sCCD_R;
assign final_G    = SW[1] ? proc_G    : sCCD_G;
assign final_B    = SW[1] ? proc_B    : sCCD_B;
assign final_DVAL = SW[1] ? proc_DVAL : sCCD_DVAL;


// the rest is mostly the original Terasic code
// i only changed the SDRAM write data/valid signals

// D5M camera control (unchanged)
assign  D5M_TRIGGER = 1'b1;
assign  D5M_RESET_N = DLY_RST_1;
assign  VGA_CTRL_CLK = VGA_CLK;
assign  LEDR = Y_Cont;

// VGA output (unchanged) - just grabs top 8 of 10 bits
assign  VGA_R = oVGA_R[9:2];
assign  VGA_G = oVGA_G[9:2];
assign  VGA_B = oVGA_B[9:2];

// register the camera data on pixel clock (unchanged)
always @(posedge D5M_PIXLCLK) begin
    rCCD_DATA <= D5M_D;
    rCCD_LVAL <= D5M_LVAL;
    rCCD_FVAL <= D5M_FVAL;
end

// auto start on power up (unchanged)
assign auto_start = ((KEY[0])&&(DLY_RST_3)&&(!DLY_RST_4)) ? 1'b1 : 1'b0;

// reset delay chain (unchanged)
Reset_Delay         u2 (
    .iCLK   (CLOCK_50),
    .iRST   (KEY[0]),
    .oRST_0 (DLY_RST_0),
    .oRST_1 (DLY_RST_1),
    .oRST_2 (DLY_RST_2),
    .oRST_3 (DLY_RST_3),
    .oRST_4 (DLY_RST_4)
);

// camera capture module (unchanged)
// outputs raw bayer data + X/Y counters
CCD_Capture         u3 (
    .oDATA      (mCCD_DATA),
    .oDVAL      (mCCD_DVAL),
    .oX_Cont    (X_Cont),
    .oY_Cont    (Y_Cont),
    .oFrame_Cont(Frame_Cont),
    .iDATA      (rCCD_DATA),
    .iFVAL      (rCCD_FVAL),
    .iLVAL      (rCCD_LVAL),
    .iSTART     (!KEY[3]|auto_start),
    .iEND       (!KEY[2]),
    .iCLK       (~D5M_PIXLCLK),
    .iRST       (DLY_RST_2)
);

// original bayer-to-RGB converter (unchanged, still needed for SW[1]=0)
RAW2RGB             u4 (
    .iCLK    (D5M_PIXLCLK),
    .iRST    (DLY_RST_1),
    .iDATA   (mCCD_DATA),
    .iDVAL   (mCCD_DVAL),
    .oRed    (sCCD_R),
    .oGreen  (sCCD_G),
    .oBlue   (sCCD_B),
    .oDVAL   (sCCD_DVAL),
    .iX_Cont (X_Cont),
    .iY_Cont (Y_Cont)
);


// ADDED - image processing pipeline
// step 1: convert bayer to grayscale (1280x960 -> 640x480)
bayer_to_gray       u_b2g (
    .clk     (~D5M_PIXLCLK),  // same clock as CCD_Capture
    .rst_n   (DLY_RST_2),
    .iDATA   (mCCD_DATA),
    .iDVAL   (mCCD_DVAL),
    .iX_Cont (X_Cont),
    .iY_Cont (Y_Cont),
    .oGray   (gray_pixel),
    .oDVAL   (gray_dval)
);

// step 2: sobel edge detection on the grayscale stream
// SW[2] picks the filter: 0 = Gx (vertical edges), 1 = Gy (horizontal edges)
sobel_filter        u_sobel (
    .clk        (~D5M_PIXLCLK),
    .rst_n      (DLY_RST_2),
    .iGray      (gray_pixel),
    .iDVAL      (gray_dval),
    .filter_sel (SW[2]),
    .oEdge      (edge_pixel),
    .oDVAL      (edge_dval)
);


// frame counter on hex displays (unchanged)
SEG7_LUT_6          u5 (
    .oSEG0 (HEX0), .oSEG1 (HEX1),
    .oSEG2 (HEX2), .oSEG3 (HEX3),
    .oSEG4 (HEX4), .oSEG5 (HEX5),
    .iDIG  (Frame_Cont[23:0])
);

// PLL for SDRAM, camera, and VGA clocks (unchanged)
sdram_pll           u6 (
    .refclk   (CLOCK_50),
    .rst      (1'b0),
    .outclk_0 (sdram_ctrl_clk),
    .outclk_1 (DRAM_CLK),
    .outclk_2 (D5M_XCLKIN),
    .outclk_3 (VGA_CLK)
);

// SDRAM frame buffer
// CHANGED - swapped sCCD_R/G/B for final_R/G/B so the mux output goes to SDRAM
// the packing format is the same as the original:
//   WR1 = {0, green[11:7], blue[11:2]}
//   WR2 = {0, green[6:2],  red[11:2]}
// for grayscale R=G=B so it all comes out the same shade on screen
Sdram_Control       u7 (
    .RESET_N     (KEY[0]),
    .CLK         (sdram_ctrl_clk),

    // write side 1 - CHANGED data and valid
    .WR1_DATA    ({1'b0, final_G[11:7], final_B[11:2]}),
    .WR1         (final_DVAL),
    .WR1_ADDR    (0),
    .WR1_MAX_ADDR(640*480),
    .WR1_LENGTH  (8'h50),
    .WR1_LOAD    (!DLY_RST_0),
    .WR1_CLK     (~D5M_PIXLCLK),

    // write side 2 - CHANGED data and valid
    .WR2_DATA    ({1'b0, final_G[6:2], final_R[11:2]}),
    .WR2         (final_DVAL),
    .WR2_ADDR    (23'h100000),
    .WR2_MAX_ADDR(23'h100000+640*480),
    .WR2_LENGTH  (8'h50),
    .WR2_LOAD    (!DLY_RST_0),
    .WR2_CLK     (~D5M_PIXLCLK),

    // read side 1 (unchanged)
    .RD1_DATA    (Read_DATA1),
    .RD1         (Read),
    .RD1_ADDR    (0),
    .RD1_MAX_ADDR(640*480),
    .RD1_LENGTH  (8'h50),
    .RD1_LOAD    (!DLY_RST_0),
    .RD1_CLK     (~VGA_CTRL_CLK),

    // read side 2 (unchanged)
    .RD2_DATA    (Read_DATA2),
    .RD2         (Read),
    .RD2_ADDR    (23'h100000),
    .RD2_MAX_ADDR(23'h100000+640*480),
    .RD2_LENGTH  (8'h50),
    .RD2_LOAD    (!DLY_RST_0),
    .RD2_CLK     (~VGA_CTRL_CLK),

    // SDRAM pins (unchanged)
    .SA    (DRAM_ADDR),
    .BA    (DRAM_BA),
    .CS_N  (DRAM_CS_N),
    .CKE   (DRAM_CKE),
    .RAS_N (DRAM_RAS_N),
    .CAS_N (DRAM_CAS_N),
    .WE_N  (DRAM_WE_N),
    .DQ    (DRAM_DQ),
    .DQM   ({DRAM_UDQM, DRAM_LDQM})
);

// I2C config for the camera (unchanged)
I2C_CCD_Config      u8 (
    .iCLK            (CLOCK2_50),
    .iRST_N          (DLY_RST_2),
    .iEXPOSURE_ADJ   (KEY[1]),
    .iEXPOSURE_DEC_p (SW[0]),
    .iZOOM_MODE_SW   (SW[9]),
    .I2C_SCLK        (D5M_SCLK),
    .I2C_SDAT        (D5M_SDATA)
);

// VGA controller (unchanged)
VGA_Controller      u1 (
    .oRequest       (Read),
    .iRed           (Read_DATA2[9:0]),
    .iGreen         ({Read_DATA1[14:10], Read_DATA2[14:10]}),
    .iBlue          (Read_DATA1[9:0]),
    .oVGA_R         (oVGA_R),
    .oVGA_G         (oVGA_G),
    .oVGA_B         (oVGA_B),
    .oVGA_H_SYNC    (VGA_HS),
    .oVGA_V_SYNC    (VGA_VS),
    .oVGA_SYNC      (VGA_SYNC_N),
    .oVGA_BLANK     (VGA_BLANK_N),
    .iCLK           (VGA_CTRL_CLK),
    .iRST_N         (DLY_RST_2),
    .iZOOM_MODE_SW  (SW[9])
);

endmodule
