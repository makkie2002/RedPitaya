`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     SCKCEN
// Engineer:    M. Dierckx
// 
// Create Date: 14.03.2015 01:04:16
// Design Name: 
// Module Name: peak_detector
// Project Name: MYRRHA 
// Target Devices: RedPitaya
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module peak_detector(
  // Peak detector
  input                 adc_clk,
  input                 adc_rstn,
  input       [14-1:0]  adc_a_in,
  input       [14-1:0]  adc_b_in,
  output reg  [14-1:0]  pd_peak_ampl,
  output reg  [32-1:0]  pd_peak_loc,
  output reg            pd_done,
  
  // System bus
  input                 sys_clk_i       ,  //!< bus clock
  input                 sys_rstn_i      ,  //!< bus reset - active low
  input      [ 32-1: 0] sys_addr_i      ,  //!< bus address
  input      [ 32-1: 0] sys_wdata_i     ,  //!< bus write data
  input      [  4-1: 0] sys_sel_i       ,  //!< bus write byte select
  input                 sys_wen_i       ,  //!< bus write enable
  input                 sys_ren_i       ,  //!< bus read enable
  output     [ 32-1: 0] sys_rdata_o     ,  //!< bus read data
  output                sys_err_o       ,  //!< bus error indicator
  output                sys_ack_o          //!< bus acknowledge signal  
  );
 
  wire [ 32-1: 0] addr         ;
  wire [ 32-1: 0] wdata        ;
  wire            wen          ;
  wire            ren          ;
  reg  [ 32-1: 0] rdata        ;
  reg             err          ;
  reg             ack          ;
  
  reg       [14-1:0]    peak_ampl_temp;
  reg       [32-1:0]    peak_loc_temp;
  wire      [14-1:0]    adc_a_in_abs;
  wire      [14-1:0]    adc_b_in_abs;
  reg       [32-1:0]    pos_counter;
  reg       [32-1:0]    gate_start;
  reg       [32-1:0]    gate_stop;
  reg       [32-1:0]    gate_length;
  reg       [32-1:0]    trig_lvl;
  reg       [32-1:0]    trig_cntr;
  reg       [32-1:0]    marc_cntr_1;
  reg       [32-1:0]    marc_cntr_2;  
  

  assign adc_a_in_abs = (adc_a_in[13]==1)?(-adc_a_in):(adc_a_in);
  assign adc_b_in_abs = (adc_b_in[13]==1)?(-adc_b_in):(adc_b_in);

  initial begin
    peak_ampl_temp<=14'h0;
    peak_loc_temp<=32'h0;
    pd_peak_ampl<=14'h0;
    pd_peak_loc<=32'h0;
    pos_counter<=32'h0;
    pd_done<=1'b1;
    trig_cntr<=32'h0;
    marc_cntr_1<=32'h0;    
    marc_cntr_2<=32'h0;
  end
  
  always @(posedge adc_clk)
  begin
    gate_stop<=gate_start+gate_length;
    if (pd_done==1'b1)
      begin
      if (adc_b_in_abs>trig_lvl)
        begin
          peak_ampl_temp<=14'h0;
          peak_loc_temp<=32'h0;
          pos_counter<=32'h0;
          pd_done<=1'b0;
          trig_cntr<=trig_cntr+1'b1;
        end
      end
    else
      begin
        marc_cntr_1<=marc_cntr_1+1'b1;
        if ((pos_counter>=gate_start)&&(pos_counter<=gate_stop)&&(adc_a_in_abs>peak_ampl_temp))
          begin
            peak_ampl_temp<=adc_a_in_abs;
            peak_loc_temp<=pos_counter;        
          end
        if (pos_counter<gate_stop)
          begin
            marc_cntr_2<=marc_cntr_2+1'b1;
            pos_counter<=pos_counter+1'b1;
          end
        else
          begin
            pos_counter<=32'h0;
            pd_done<=1'd1;
            pd_peak_ampl<=peak_ampl_temp;
            pd_peak_loc<=peak_loc_temp;
          end   
      end  
  end



//---------------------------------------------------------------------------------
//
//  System bus connection

always @(posedge adc_clk) begin
   if (adc_rstn == 1'b0) begin
      trig_lvl     <=  14'd400    ;
      gate_start   <=  32'd7000   ;
      gate_length  <=  32'd700000  ;
   end
   else begin
      if (wen) begin
         if (addr[19:0]==20'h8)    trig_lvl    <= wdata[14-1:0] ;
         if (addr[19:0]==20'hC)    gate_start  <= wdata[32-1:0] ;
         if (addr[19:0]==20'h10)   gate_length <= wdata[32-1:0] ;
      end
   end
end




always @(*) begin
   err <= 1'b0 ;
   casez (addr[19:0])
     20'h00008 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, trig_lvl}        ; end
     20'h0000C : begin ack <= 1'b1;          rdata <= {               gate_start}      ; end
     20'h00010 : begin ack <= 1'b1;          rdata <= {               gate_length}     ; end

     20'h00014 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, pd_peak_ampl}    ; end
     20'h00018 : begin ack <= 1'b1;          rdata <= {               pd_peak_loc}     ; end
     20'h0001C : begin ack <= 1'b1;          rdata <= {               trig_cntr}       ; end     
     20'h00020 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, adc_a_in}        ; end
     20'h00024 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, adc_a_in_abs}    ; end     
     20'h00028 : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, adc_b_in}        ; end
     20'h0002C : begin ack <= 1'b1;          rdata <= {{32-14{1'b0}}, adc_b_in_abs}    ; end
     20'h00030 : begin ack <= 1'b1;          rdata <= {               pos_counter}     ; end
     20'h00038 : begin ack <= 1'b1;          rdata <= {{32-31{1'b0}}, pd_done}         ; end
     20'h0003C : begin ack <= 1'b1;          rdata <= {               gate_stop}       ; end
     20'h00040 : begin ack <= 1'b1;          rdata <= {               marc_cntr_1}     ; end
     20'h00044 : begin ack <= 1'b1;          rdata <= {               marc_cntr_2}     ; end                                
     20'h000A0 : begin ack <= 1'b1;          rdata <= {               32'hDEADBEAF}    ; end
       default : begin ack <= 1'b1;          rdata <=  32'h0                           ; end
   endcase
end

// bridge between ADC and sys clock
bus_clk_bridge i_bridge
(
   .sys_clk_i     (  sys_clk_i      ),
   .sys_rstn_i    (  sys_rstn_i     ),
   .sys_addr_i    (  sys_addr_i     ),
   .sys_wdata_i   (  sys_wdata_i    ),
   .sys_sel_i     (  sys_sel_i      ),
   .sys_wen_i     (  sys_wen_i      ),
   .sys_ren_i     (  sys_ren_i      ),
   .sys_rdata_o   (  sys_rdata_o    ),
   .sys_err_o     (  sys_err_o      ),
   .sys_ack_o     (  sys_ack_o      ),

   .clk_i         (  adc_clk        ),
   .rstn_i        (  adc_rstn       ),
   .addr_o        (  addr           ),
   .wdata_o       (  wdata          ),
   .wen_o         (  wen            ),
   .ren_o         (  ren            ),
   .rdata_i       (  rdata          ),
   .err_i         (  err            ),
   .ack_i         (  ack            )
);

endmodule // peak_detector
