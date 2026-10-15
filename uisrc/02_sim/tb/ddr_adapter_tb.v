`timescale 1ns/1ps
module ddr_adapter_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg wen=0,ren=0;reg [20:0] wa=0,ra=0;reg [31:0] din=0;
wire init,refv,busy,rd;wire [31:0] dout;
sdram dut(clk,!clk,clk,rst,init,refv,busy,wen,wa,4'd0,din,ren,ra,rd,dout);
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
integer requests=0,i;
always @(posedge clk)if(dut.refresh_request && !dut.u_ddr_ctrl.req_seen)requests=requests+1;
initial begin
 cycles(3);rst=0;cycles(4);
 if(!init)$fatal(1,"Init routing failure");
 for(i=0;i<614400;i=i+1)begin
  wa=i;ra=i;din=i;wen=1;ren=0;#1;
  if(dut.u_ddr_ctrl.App_wr_addr!==2*i || dut.u_ddr_ctrl.App_rd_addr!==2*i)$fatal(1,"DDR address conversion failure");
  if(dut.u_ddr_ctrl.App_wr_din!==din || dut.u_ddr_ctrl.App_wr_dm!==0)$fatal(1,"DDR data/mask routing failure");
 end
 wen=0;cycles(2200);if(requests<2)$fatal(1,"Refresh missing");
 rst=1;cycles(2);if(dut.refresh_request)$fatal(1,"Refresh reset failed");
 $display("PASS DDR_ADAPTER: 614400 word addresses to halfwords, data/mask routing, periodic held refresh request and reset");$finish;
end
endmodule
module ddr1_as_ram #(parameter self_refresh_open=0)(input Clk0,Clk90,Clk180,Rst,
 output Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,input App_ref_req,App_wr_en,input [22:0] App_wr_addr,input [1:0] App_wr_dm,input [31:0] App_wr_din,
 input App_rd_en,input [22:0] App_rd_addr,output Sdr_rd_en,output [31:0] Sdr_rd_dout,
 output CLK,CLKN,CKE,CS_N,RAS_N,CAS_N,WE_N,output [1:0] BA,output [11:0] ADDR,output [1:0] DM,inout [15:0] DQ,inout [1:0] DQS);
 reg [3:0] delay_count=0;reg req_seen=0;reg refv=0;
 always @(posedge Clk0)begin
  if(Rst)begin req_seen<=0;delay_count<=0;refv<=0;end
  else begin
   refv<=0;
   if(App_ref_req && !req_seen)begin req_seen<=1;delay_count<=1;end
   if(delay_count!=0)begin delay_count<=delay_count+1'b1;if(delay_count==5)begin refv<=1;delay_count<=0;end end
   if(!App_ref_req)req_seen<=0;
  end
 end
 assign Sdr_init_done=!Rst;assign Sdr_init_ref_vld=refv;assign Sdr_busy=refv;
 assign Sdr_rd_en=App_rd_en;assign Sdr_rd_dout=App_wr_din;
 assign {CLK,CLKN,CKE,CS_N,RAS_N,CAS_N,WE_N,BA,ADDR,DM}=0;
endmodule
module EG_PHY_DDR_8M_16(input clk,clk_n,ras_n,cas_n,we_n,cs_n,input [11:0] addr,input [1:0] ba,inout [15:0] dq,inout ldqs,udqs,input ldm,udm,cke);endmodule
