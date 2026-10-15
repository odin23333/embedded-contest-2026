`timescale 1ns/1ps
// PT7C4337 (7-bit I2C address 0x68), explicit host calibration only.
module rtc_time #(parameter POLL_CYCLES=6250000,parameter I2C_DIV=249)(
 input clk,rst_n,set_pulse,input[23:0] set_time,output scl,inout sda,
 output reg[23:0] time_bcd,output reg time_valid,update_toggle,reply,reply_ok);
reg req;reg[39:0] wr;reg[7:0] wc,rc;wire[127:0] rd;wire busy,error;
uii2c #(.WMEN_LEN(5),.RMEN_LEN(16),.CLK_DIV(I2C_DIV)) bus(
 .clk_i(clk),.rstn_i(rst_n),.iic_scl(scl),.iic_sda(sda),.wr_data(wr),.wr_cnt(wc),.rd_data(rd),.rd_cnt(rc),.iic_req(req),.iic_busy(busy),.iic_bus_error(error),.iic_sda_dg());
reg[3:0] state,op;reg[31:0] timer,guard;reg seen_busy,failed,queued;reg[23:0] target;reg[127:0] snapshot;
function valid_bcd;input[7:0] a;input[7:0] maxval;begin valid_bcd=a[3:0]<=9 && a[7:4]<=9 && a<=maxval;end endfunction
wire good_snapshot=!snapshot[127] && !snapshot[119] && valid_bcd(snapshot[7:0],8'h59) && valid_bcd(snapshot[15:8],8'h59) && valid_bcd(snapshot[23:16],8'h23);
localparam IDLE=0,LAUNCH=1,WAITBUS=2,WAITDONE=3,COMPLETE=4;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin req<=0;wr<=0;wc<=0;rc<=0;state<=IDLE;op<=0;timer<=POLL_CYCLES-1;guard<=0;seen_busy<=0;failed<=0;queued<=0;target<=0;snapshot<=0;time_bcd<=0;time_valid<=0;update_toggle<=0;reply<=0;reply_ok<=0;end
 else begin
  reply<=0;
  if(set_pulse)begin queued<=1;target<=set_time;time_valid<=0;update_toggle<=~update_toggle;end
  case(state)
   IDLE:begin req<=0;
    if(queued)begin queued<=0;op<=0;state<=LAUNCH;timer<=0;end
    else if(timer>=POLL_CYCLES-1)begin op<=4;timer<=0;state<=LAUNCH;end
    else timer<=timer+1'b1;
   end
   LAUNCH:if(!busy)begin
    case(op)
     // Stop time chain, set 24h time, enable it, then clear oscillator-stop flag.
     0:begin wr<={16'd0,8'h84,8'h0e,8'hd0};wc<=3;rc<=0;end
     1:begin wr<={target[23:16],target[15:8],target[7:0],8'h00,8'hd0};wc<=5;rc<=0;end
     2:begin wr<={16'd0,8'h04,8'h0e,8'hd0};wc<=3;rc<=0;end
     3:begin wr<={16'd0,8'h00,8'h0f,8'hd0};wc<=3;rc<=0;end
     4:begin wr<=40'h00000000d0;wc<=2;rc<=16;end
     5:begin wr<=40'h00000000d0;wc<=2;rc<=1;end
    endcase
    req<=1;failed<=0;guard<=0;state<=WAITBUS;
   end
   WAITBUS:begin guard<=guard+1'b1;if(error)failed<=1;
    if(busy)begin req<=0;state<=WAITDONE;end
    else if(guard==2500000)begin req<=0;time_valid<=0;update_toggle<=~update_toggle;reply<=op<4;reply_ok<=0;state<=IDLE;end
   end
   WAITDONE:begin guard<=guard+1'b1;if(error)failed<=1;
    if(!busy)state<=COMPLETE;
    else if(guard==2500000)begin req<=0;time_valid<=0;update_toggle<=~update_toggle;reply<=op<4;reply_ok<=0;state<=IDLE;end
   end
   COMPLETE:begin
    if(failed || error)begin time_valid<=0;update_toggle<=~update_toggle;reply<=op<4;reply_ok<=0;state<=IDLE;end
    else if(op<3)begin op<=op+1'b1;state<=LAUNCH;end
    else if(op==3)begin reply<=1;reply_ok<=1;op<=4;state<=LAUNCH;end
    else if(op==4)begin snapshot<=rd;op<=5;state<=LAUNCH;end
    else begin
     if(good_snapshot && rd[7:0]==snapshot[7:0])begin time_bcd<={snapshot[23:16],snapshot[15:8],snapshot[7:0]};time_valid<=1;end
     else time_valid<=0;
     update_toggle<=~update_toggle;state<=IDLE;
    end
   end
   default:state<=IDLE;
  endcase
 end
end
endmodule
