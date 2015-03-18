/**
 * $Id: red_pitaya_top.v 1271 2014-02-25 12:32:34Z matej.oblak $
 *
 * @brief Red Pitaya TOP module. It connects external pins and PS part with 
 *        other application modules. 
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */



/**
 * GENERAL DESCRIPTION:
 *
 * Top module connects PS part with rest of Red Pitaya applications.  
 *
 *
 *
 *                   /-------\      
 *   PS DDR <------> |  PS   |      AXI <-> custom bus
 *   PS MIO <------> |   /   | <------------+
 *   PS CLK -------> |  ARM  |              |
 *                   \-------/              |
 *                                          |
 *                                          |
 *                                          |
 *                            /-------\     |
 *                         -> | SCOPE | <---+
 *                         |  \-------/     |
 *                         |                |
 *                         |                |
 *            /--------\   |   /-----\      |
 *   ADC ---> |        | --+-> |     |      |
 *            | ANALOG |       | PID | <----+
 *   DAC <--- |        | <---- |     |      |
 *            \--------/   ^   \-----/      |
 *                         |                |
 *                         |                |
 *                         |  /-------\     |
 *                         -- |  ASG  | <---+ 
 *                            \-------/     |
 *                                          |
 *                                          |
 *                                          |
 *             /--------\                   |
 *    RX ----> |        |                   |
 *   SATA      | DAISY  | <-----------------+
 *    TX <---- |        | 
 *             \--------/ 
 *               |    |
 *               |    |
 *               (FREE)
 *
 *
 *
 *
 * Inside analog module, ADC data is translated from unsigned neg-slope into
 * two's complement. Similar is done on DAC data.
 *
 * Scope module stores data from ADC into RAM, arbitrary signal generator (ASG)
 * sends data from RAM to DAC. MIMO PID uses ADC ADC as input and DAC as its output.
 *
 * Daisy chain connects with other boards with fast serial link. Data which is
 * send and received is at the moment undefined. This is left for the user.
 * 
 */


module red_pitaya_top
(
   // PS connections
   inout  [54-1: 0] FIXED_IO_mio       ,
   inout            FIXED_IO_ps_clk    ,
   inout            FIXED_IO_ps_porb   ,
   inout            FIXED_IO_ps_srstb  ,
   inout            FIXED_IO_ddr_vrn   ,
   inout            FIXED_IO_ddr_vrp   ,
   inout  [15-1: 0] DDR_addr           ,
   inout  [ 3-1: 0] DDR_ba             ,
   inout            DDR_cas_n          ,
   inout            DDR_ck_n           ,
   inout            DDR_ck_p           ,
   inout            DDR_cke            ,
   inout            DDR_cs_n           ,
   inout  [ 4-1: 0] DDR_dm             ,
   inout  [32-1: 0] DDR_dq             ,
   inout  [ 4-1: 0] DDR_dqs_n          ,
   inout  [ 4-1: 0] DDR_dqs_p          ,
   inout            DDR_odt            ,
   inout            DDR_ras_n          ,
   inout            DDR_reset_n        ,
   inout            DDR_we_n           ,


   // Red Pitaya periphery
  
   // ADC
   input  [16-1: 2] adc_dat_a_i        ,  // ADC CH1
   input  [16-1: 2] adc_dat_b_i        ,  // ADC CH2
   input            adc_clk_p_i        ,  // ADC data clock
   input            adc_clk_n_i        ,  // ADC data clock
   output [ 2-1: 0] adc_clk_o          ,  // optional ADC clock source
   output           adc_cdcs_o         ,  // ADC clock duty cycle stabilizer
  
   // DAC
   output [14-1: 0] dac_dat_o          ,  // DAC combined data
   output           dac_wrt_o          ,  // DAC write
   output           dac_sel_o          ,  // DAC channel select
   output           dac_clk_o          ,  // DAC clock
   output           dac_rst_o          ,  // DAC reset
  
   // PWM DAC
   output [ 4-1: 0] dac_pwm_o          ,  // serial PWM DAC

   // XADC
   input  [ 5-1: 0] vinp_i             ,  // voltages p
   input  [ 5-1: 0] vinn_i             ,  // voltages n

   // Expansion connector
   inout  [ 8-1: 0] exp_p_io           ,
   inout  [ 8-1: 0] exp_n_io           ,


   // SATA connector
   output [ 2-1: 0] daisy_p_o          ,  // line 1 is clock capable
   output [ 2-1: 0] daisy_n_o          ,
   input  [ 2-1: 0] daisy_p_i          ,  // line 1 is clock capable
   input  [ 2-1: 0] daisy_n_i          ,

   // LED
   output [ 8-1: 0] led_o       

);



//---------------------------------------------------------------------------------
//
//  Connections to PS

wire  [  4-1: 0] fclk               ; //[0]-125MHz, [1]-250MHz, [2]-50MHz, [3]-200MHz
wire  [  4-1: 0] frstn              ;

wire             ps_sys_clk         ;
wire             ps_sys_rstn        ;
wire  [ 32-1: 0] ps_sys_addr        ;
wire  [ 32-1: 0] ps_sys_wdata       ;
wire  [  4-1: 0] ps_sys_sel         ;
wire             ps_sys_wen         ;
wire             ps_sys_ren         ;
wire  [ 32-1: 0] ps_sys_rdata       ;
wire             ps_sys_err         ;
wire             ps_sys_ack         ;

// AXI0 master
wire             axi0_clk           ;
wire             axi0_rstn          ;
wire  [ 32-1: 0] axi0_waddr         ;
wire  [ 64-1: 0] axi0_wdata         ;
wire  [  8-1: 0] axi0_wsel          ;
wire             axi0_wvalid        ;
wire  [  4-1: 0] axi0_wlen          ;
wire             axi0_wfixed        ;
wire             axi0_werr          ;
wire             axi0_wrdy          ;
wire             axi0_rstn_ps       ;

// AXI1 master
wire             axi1_clk           ;
wire             axi1_rstn          ;
wire  [ 32-1: 0] axi1_waddr         ;
wire  [ 64-1: 0] axi1_wdata         ;
wire  [  8-1: 0] axi1_wsel          ;
wire             axi1_wvalid        ;
wire  [  4-1: 0] axi1_wlen          ;
wire             axi1_wfixed        ;
wire             axi1_werr          ;
wire             axi1_wrdy          ;
wire             axi1_rstn_ps       ;

  
red_pitaya_ps i_ps
(
  .FIXED_IO_mio       (  FIXED_IO_mio                ),
  .FIXED_IO_ps_clk    (  FIXED_IO_ps_clk             ),
  .FIXED_IO_ps_porb   (  FIXED_IO_ps_porb            ),
  .FIXED_IO_ps_srstb  (  FIXED_IO_ps_srstb           ),
  .FIXED_IO_ddr_vrn   (  FIXED_IO_ddr_vrn            ),
  .FIXED_IO_ddr_vrp   (  FIXED_IO_ddr_vrp            ),
  .DDR_addr           (  DDR_addr                    ),
  .DDR_ba             (  DDR_ba                      ),
  .DDR_cas_n          (  DDR_cas_n                   ),
  .DDR_ck_n           (  DDR_ck_n                    ),
  .DDR_ck_p           (  DDR_ck_p                    ),
  .DDR_cke            (  DDR_cke                     ),
  .DDR_cs_n           (  DDR_cs_n                    ),
  .DDR_dm             (  DDR_dm                      ),
  .DDR_dq             (  DDR_dq                      ),
  .DDR_dqs_n          (  DDR_dqs_n                   ),
  .DDR_dqs_p          (  DDR_dqs_p                   ),
  .DDR_odt            (  DDR_odt                     ),
  .DDR_ras_n          (  DDR_ras_n                   ),
  .DDR_reset_n        (  DDR_reset_n                 ),
  .DDR_we_n           (  DDR_we_n                    ),

  .fclk_clk_o      (  fclk               ),
  .fclk_rstn_o     (  frstn              ),

   // system read/write channel
  .sys_clk_o       (  ps_sys_clk         ),  // system clock
  .sys_rstn_o      (  ps_sys_rstn        ),  // system reset - active low
  .sys_addr_o      (  ps_sys_addr        ),  // system read/write address
  .sys_wdata_o     (  ps_sys_wdata       ),  // system write data
  .sys_sel_o       (  ps_sys_sel         ),  // system write byte select
  .sys_wen_o       (  ps_sys_wen         ),  // system write enable
  .sys_ren_o       (  ps_sys_ren         ),  // system read enable
  .sys_rdata_i     (  ps_sys_rdata       ),  // system read data
  .sys_err_i       (  ps_sys_err         ),  // system error indicator
  .sys_ack_i       (  ps_sys_ack         ),  // system acknowledge signal

   // SPI master
  .spi_ss_o        (                     ),  // select slave 0
  .spi_ss1_o       (                     ),  // select slave 1
  .spi_ss2_o       (                     ),  // select slave 2
  .spi_sclk_o      (                     ),  // serial clock
  .spi_mosi_o      (                     ),  // master out slave in
  .spi_miso_i      (  1'b0               ),  // master in slave out

   // SPI slave
  .spi_ss_i        (  1'b1               ),  // slave selected
  .spi_sclk_i      (  1'b0               ),  // serial clock
  .spi_mosi_i      (  1'b0               ),  // master out slave in
  .spi_miso_o      (                     ),  // master in slave out

   // AXI0 master
  .axi0_clk_i      (  axi0_clk           ),  // global clock
  .axi0_rstn_i     (  axi0_rstn          ),  // global reset
  .axi0_waddr_i    (  axi0_waddr         ),  // system write address
  .axi0_wdata_i    (  axi0_wdata         ),  // system write data
  .axi0_wsel_i     (  axi0_wsel          ),  // system write byte select
  .axi0_wvalid_i   (  axi0_wvalid        ),  // system write data valid
  .axi0_wlen_i     (  axi0_wlen          ),  // system write burst length
  .axi0_wfixed_i   (  axi0_wfixed        ),  // system write burst type (fixed / incremental)
  .axi0_werr_o     (  axi0_werr          ),  // system write error
  .axi0_wrdy_o     (  axi0_wrdy          ),  // system write ready
  .axi0_rstn_o     (  axi0_rstn_ps       ),  // reset from PS

   // AXI1 master
  .axi1_clk_i      (  axi1_clk           ),  // global clock
  .axi1_rstn_i     (  axi1_rstn          ),  // global reset
  .axi1_waddr_i    (  axi1_waddr         ),  // system write address
  .axi1_wdata_i    (  axi1_wdata         ),  // system write data
  .axi1_wsel_i     (  axi1_wsel          ),  // system write byte select
  .axi1_wvalid_i   (  axi1_wvalid        ),  // system write data valid
  .axi1_wlen_i     (  axi1_wlen          ),  // system write burst length
  .axi1_wfixed_i   (  axi1_wfixed        ),  // system write burst type (fixed / incremental)
  .axi1_werr_o     (  axi1_werr          ),  // system write error
  .axi1_wrdy_o     (  axi1_wrdy          ),  // system write ready
  .axi1_rstn_o     (  axi1_rstn_ps       )   // reset from PS
);








//---------------------------------------------------------------------------------
//
//  Analog peripherials 

// ADC clock duty cycle stabilizer is enabled
assign adc_cdcs_o = 1'b1 ;

// generating ADC clock is disabled
assign adc_clk_o = 2'b10;
//ODDR i_adc_clk_p ( .Q(adc_clk_o[0]), .D1(1'b1), .D2(1'b0), .C(fclk[0]), .CE(1'b1), .R(1'b0), .S(1'b0));
//ODDR i_adc_clk_n ( .Q(adc_clk_o[1]), .D1(1'b0), .D2(1'b1), .C(fclk[0]), .CE(1'b1), .R(1'b0), .S(1'b0));


wire             ser_clk     ;
wire             adc_clk     ;
reg              adc_rstn    ;
wire  [ 14-1: 0] adc_a       ;
wire  [ 14-1: 0] adc_b       ;
reg   [ 14-1: 0] dac_a       ;
reg   [ 14-1: 0] dac_b       ;
wire  [ 24-1: 0] dac_pwm_a   ;
wire  [ 24-1: 0] dac_pwm_b   ;
wire  [ 24-1: 0] dac_pwm_c   ;
wire  [ 24-1: 0] dac_pwm_d   ;

red_pitaya_analog i_analog
(
  // ADC IC
  .adc_dat_a_i        (  adc_dat_a_i      ),  // CH 1
  .adc_dat_b_i        (  adc_dat_b_i      ),  // CH 2
  .adc_clk_p_i        (  adc_clk_p_i      ),  // data clock
  .adc_clk_n_i        (  adc_clk_n_i      ),  // data clock
  
  // DAC IC
  .dac_dat_o          (  dac_dat_o        ),  // combined data
  .dac_wrt_o          (  dac_wrt_o        ),  // write enable
  .dac_sel_o          (  dac_sel_o        ),  // channel select
  .dac_clk_o          (  dac_clk_o        ),  // clock
  .dac_rst_o          (  dac_rst_o        ),  // reset
  
  // PWM DAC
  .dac_pwm_o          (  dac_pwm_o        ),  // serial PWM DAC
  
  
  // user interface
  .adc_dat_a_o        (  adc_a            ),  // ADC CH1
  .adc_dat_b_o        (  adc_b            ),  // ADC CH2
  .adc_clk_o          (  adc_clk          ),  // ADC received clock
  .adc_rst_i          (  adc_rstn         ),  // reset - active low
  .ser_clk_o          (  ser_clk          ),  // fast serial clock

  .dac_dat_a_i        (  dac_a            ),  // DAC CH1
  .dac_dat_b_i        (  dac_b            ),  // DAC CH2

  .dac_pwm_a_i        (  dac_pwm_a        ),  // slow DAC CH1
  .dac_pwm_b_i        (  dac_pwm_b        ),  // slow DAC CH2
  .dac_pwm_c_i        (  dac_pwm_c        ),  // slow DAC CH3
  .dac_pwm_d_i        (  dac_pwm_d        ),  // slow DAC CH4
  .dac_pwm_sync_o     (                   )   // slow DAC sync
);

always @(posedge adc_clk) begin
   adc_rstn <= frstn[0] ;
end








//---------------------------------------------------------------------------------
//
//  system bus decoder & multiplexer
//  it breaks memory addresses into 8 regions

wire                sys_clk    = ps_sys_clk      ;
wire                sys_rstn   = ps_sys_rstn     ;
wire  [    32-1: 0] sys_addr   = ps_sys_addr     ;
wire  [    32-1: 0] sys_wdata  = ps_sys_wdata    ;
wire  [     4-1: 0] sys_sel    = ps_sys_sel      ;
wire  [     8-1: 0] sys_wen    ;
wire  [     8-1: 0] sys_ren    ;
wire  [(8*32)-1: 0] sys_rdata  ;
wire  [ (8*1)-1: 0] sys_err    ;
wire  [ (8*1)-1: 0] sys_ack    ;
reg   [     8-1: 0] sys_cs     ;

always @(sys_addr) begin
   sys_cs = 8'h0 ;
   case (sys_addr[22:20])
      3'h0, 3'h1, 3'h2, 3'h3, 3'h4, 3'h5, 3'h6, 3'h7 : 
         sys_cs[sys_addr[22:20]] = 1'b1 ; 
   endcase
end

assign sys_wen = sys_cs & {8{ps_sys_wen}}  ;
assign sys_ren = sys_cs & {8{ps_sys_ren}}  ;


assign ps_sys_rdata = {32{sys_cs[ 0]}} & sys_rdata[ 0*32+31: 0*32] |
                      {32{sys_cs[ 1]}} & sys_rdata[ 1*32+31: 1*32] |
                      {32{sys_cs[ 2]}} & sys_rdata[ 2*32+31: 2*32] |
                      {32{sys_cs[ 3]}} & sys_rdata[ 3*32+31: 3*32] |
                      {32{sys_cs[ 4]}} & sys_rdata[ 4*32+31: 4*32] | 
                      {32{sys_cs[ 5]}} & sys_rdata[ 5*32+31: 5*32] |
                      {32{sys_cs[ 6]}} & sys_rdata[ 6*32+31: 6*32] |
                      {32{sys_cs[ 7]}} & sys_rdata[ 7*32+31: 7*32] ; 

assign ps_sys_err   = sys_cs[ 0] & sys_err[  0] |
                      sys_cs[ 1] & sys_err[  1] |
                      sys_cs[ 2] & sys_err[  2] |
                      sys_cs[ 3] & sys_err[  3] |
                      sys_cs[ 4] & sys_err[  4] | 
                      sys_cs[ 5] & sys_err[  5] |
                      sys_cs[ 6] & sys_err[  6] |
                      sys_cs[ 7] & sys_err[  7] ; 

assign ps_sys_ack   = sys_cs[ 0] & sys_ack[  0] |
                      sys_cs[ 1] & sys_ack[  1] |
                      sys_cs[ 2] & sys_ack[  2] |
                      sys_cs[ 3] & sys_ack[  3] |
                      sys_cs[ 4] & sys_ack[  4] | 
                      sys_cs[ 5] & sys_ack[  5] |
                      sys_cs[ 6] & sys_ack[  6] |
                      sys_cs[ 7] & sys_ack[  7] ; 


//assign sys_rdata[ 6*32+31: 6*32] = 32'h0;

//assign sys_err[6] = {1{1'b0}} ;
//assign sys_ack[6] = {1{1'b1}} ;



red_pitaya_ams i_ams
(
   // power test
  .clk_i           (  adc_clk                    ),  // clock
  .rstn_i          (  adc_rstn                   ),  // reset - active low

  .vinp_i          (  vinp_i                     ),  // voltages p
  .vinn_i          (  vinn_i                     ),  // voltages n

  .dac_a_o         (  dac_pwm_a                  ),  // values used for
  .dac_b_o         (  dac_pwm_b                  ),  // conversion into PWM signal
  .dac_c_o         (  dac_pwm_c                  ),
  .dac_d_o         (  dac_pwm_d                  ),

   // System bus
  .sys_clk_i       (  sys_clk                    ),  // clock
  .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
  .sys_addr_i      (  sys_addr                   ),  // address
  .sys_wdata_i     (  sys_wdata                  ),  // write data
  .sys_sel_i       (  sys_sel                    ),  // write byte select
  .sys_wen_i       (  sys_wen[4]                 ),  // write enable
  .sys_ren_i       (  sys_ren[4]                 ),  // read enable
  .sys_rdata_o     (  sys_rdata[ 4*32+31: 4*32]  ),  // read data
  .sys_err_o       (  sys_err[4]                 ),  // error indicator
  .sys_ack_o       (  sys_ack[4]                 )   // acknowledge signal
);


//---------------------------------------------------------------------------------
//
//  Daisy chain
//  simple communication module

wire daisy_rx_rdy ;
wire dly_clk = fclk[3]; // 200MHz clock from PS - used for IDELAY (optionaly)

red_pitaya_daisy i_daisy
(
   // SATA connector
  .daisy_p_o       (  daisy_p_o                  ),  // line 1 is clock capable
  .daisy_n_o       (  daisy_n_o                  ),
  .daisy_p_i       (  daisy_p_i                  ),  // line 1 is clock capable
  .daisy_n_i       (  daisy_n_i                  ),

   // Data
  .ser_clk_i       (  ser_clk                    ),  // high speed serial
  .dly_clk_i       (  dly_clk                    ),  // delay clock
   // TX
  .par_clk_i       (  adc_clk                    ),  // data paralel clock
  .par_rstn_i      (  adc_rstn                   ),  // reset - active low
  .par_rdy_o       (  daisy_rx_rdy               ),
  .par_dv_i        (  daisy_rx_rdy               ),
  .par_dat_i       (  16'h1234                   ),
   // RX
  .par_clk_o       (                             ),
  .par_rstn_o      (                             ),
  .par_dv_o        (                             ),
  .par_dat_o       (                             ),

  .debug_o         (/*led_o*/                    ),

   // System bus
  .sys_clk_i       (  sys_clk                    ),  // clock
  .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
  .sys_addr_i      (  sys_addr                   ),  // address
  .sys_wdata_i     (  sys_wdata                  ),  // write data
  .sys_sel_i       (  sys_sel                    ),  // write byte select
  .sys_wen_i       (  sys_wen[5]                 ),  // write enable
  .sys_ren_i       (  sys_ren[5]                 ),  // read enable
  .sys_rdata_o     (  sys_rdata[ 5*32+31: 5*32]  ),  // read data
  .sys_err_o       (  sys_err[5]                 ),  // error indicator
  .sys_ack_o       (  sys_ack[5]                 )   // acknowledge signal
);


//---------------------------------------------------------------------------------
//
//  Peak detector


//reg  [  8-1: 0] led_reg ;
//reg  [  14-1: 0] adc_max ;
//initial begin
//    adc_max <= 14'h0;
//end
//always @(posedge adc_clk)
//begin
//    if (adc_rstn == 1'b0)
//    begin
//       adc_max <= 14'h0;
//    end
//    else
//    begin
//        if (~adc_a[13])
//        begin
//            if (adc_a[12:0]>=adc_max)
//            begin
//                adc_max <= adc_a;    
//            end
//        end
//        else
//        begin
//            if ((~adc_a[12:0])>=adc_max)
//            begin
//                adc_max <= (~adc_a);    
//            end
//        end
//    end
//end
//assign led_o[6:0] = adc_max[12:6];
//assign led_o[7] = adc_a[13];

wire  [14-1:0]    pd_peak_ampl;
wire  [32-1:0]    pd_peak_loc;
wire              pd_done;

assign led_o[6:0]       = pd_peak_ampl[12:6];
assign led_o[7]         = adc_a[13];

peak_detector pd
(
  // Peak detector
  .adc_clk          ( adc_clk         ),
  .adc_rstn         ( adc_rstn        ),
  .adc_a_in         ( adc_a           ),
  .adc_b_in         ( adc_b           ),
  .pd_peak_ampl     ( pd_peak_ampl    ),
  .pd_peak_loc      ( pd_peak_loc     ),
  .pd_done          ( pd_done         ),
  
   // System bus
  .sys_clk_i       (  sys_clk                    ),  // clock
  .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
  .sys_addr_i      (  sys_addr                   ),  // address
  .sys_wdata_i     (  sys_wdata                  ),  // write data
  .sys_sel_i       (  sys_sel                    ),  // write byte select
  .sys_wen_i       (  sys_wen[6]                 ),  // write enable
  .sys_ren_i       (  sys_ren[6]                 ),  // read enable
  .sys_rdata_o     (  sys_rdata[ 6*32+31: 6*32]  ),  // read data
  .sys_err_o       (  sys_err[6]                 ),  // error indicator
  .sys_ack_o       (  sys_ack[6]                 )   // acknowledge signal
);





//---------------------------------------------------------------------------------
//
//  House Keeping

wire  [  8-1: 0] exp_p_in     ;
wire  [  8-1: 0] exp_p_out    ;
wire  [  8-1: 0] exp_p_dir    ;
wire  [  8-1: 0] exp_n_in     ;
wire  [  8-1: 0] exp_n_out    ;
wire  [  8-1: 0] exp_n_dir    ;

red_pitaya_hk i_hk
(
  .clk_i           (  adc_clk                    ),  // clock
  .rstn_i          (  adc_rstn                   ),  // reset - active low

  // LED
  .led_o           (                       ),  // LED output
   // Expansion connector
  .exp_p_dat_i     (  exp_p_in                   ),  // input data
  .exp_p_dat_o     (  exp_p_out                  ),  // output data
  .exp_p_dir_o     (  exp_p_dir                  ),  // 1-output enable
  .exp_n_dat_i     (  exp_n_in                   ),
  .exp_n_dat_o     (  exp_n_out                  ),
  .exp_n_dir_o     (  exp_n_dir                  ),

   // System bus
  .sys_clk_i       (  sys_clk                    ),  // clock
  .sys_rstn_i      (  sys_rstn                   ),  // reset - active low
  .sys_addr_i      (  sys_addr                   ),  // address
  .sys_wdata_i     (  sys_wdata                  ),  // write data
  .sys_sel_i       (  sys_sel                    ),  // write byte select
  .sys_wen_i       (  sys_wen[0]                 ),  // write enable
  .sys_ren_i       (  sys_ren[0]                 ),  // read enable
  .sys_rdata_o     (  sys_rdata[ 0*32+31: 0*32]  ),  // read data
  .sys_err_o       (  sys_err[0]                 ),  // error indicator
  .sys_ack_o       (  sys_ack[0]                 )   // acknowledge signal
);



genvar GV ;

generate
for( GV = 0 ; GV < 8 ; GV = GV + 1)
begin : exp_iobuf
  IOBUF i_iobufp (.O(exp_p_in[GV]), .IO(exp_p_io[GV]), .I(exp_p_out[GV]), .T(!exp_p_dir[GV]) );
  IOBUF i_iobufn (.O(exp_n_in[GV]), .IO(exp_n_io[GV]), .I(exp_n_out[GV]), .T(!exp_n_dir[GV]) );
end
endgenerate


endmodule

