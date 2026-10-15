`timescale 1ns/1ps
module rtc_time_tb;
reg clk=0,rst_n=0,setpulse=0;reg[23:0] target=24'h182359;wire scl,sda;wire[23:0]t;wire valid,toggle,reply,ok;
always #5 clk=~clk;
rtc_time #(.POLL_CYCLES(30)) dut(clk,rst_n,setpulse,target,scl,sda,t,valid,toggle,reply,ok);
initial begin
 repeat(5)@(negedge clk);rst_n=1;wait(valid);if(t!=24'h123456)$fatal(1,"Read BCD order wrong");
 dut.bus.bad=1;wait(!valid);dut.bus.bad=0;wait(valid);
 dut.bus.osf=1;wait(!valid);dut.bus.osf=0;wait(valid);
 dut.bus.rollover=1;wait(!valid);dut.bus.rollover=0;wait(valid);
 @(negedge clk);setpulse=1;@(negedge clk);setpulse=0;wait(reply);if(!ok)$fatal(1,"Calibration failed");wait(valid);
 if(t!=target || dut.bus.writes!=4)$fatal(1,"RTC write sequence or readback incorrect");
 $display("PASS RTC_TIME: coherent HHMMSS, NACK/OSF/second-rollover rejection and recovery, stop-set-enable-clear calibration with readback");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
// Explicit peripheral transaction model; physical I2C remains to be tested.
module uii2c #(parameter WMEN_LEN=5,RMEN_LEN=16,CLK_DIV=249)(input clk_i,rstn_i,output iic_scl,inout iic_sda,
 input[WMEN_LEN*8-1:0]wr_data,input[7:0]wr_cnt,output reg[RMEN_LEN*8-1:0]rd_data,input[7:0]rd_cnt,input iic_req,
 output reg iic_busy, iic_bus_error,output iic_sda_dg);
reg bad=0,osf=0,rollover=0;reg[23:0] timeval=24'h123456;integer count=0,writes=0;
assign iic_scl=1;assign iic_sda=1'bz;assign iic_sda_dg=1;
always @(posedge clk_i)begin
 if(!rstn_i)begin iic_busy<=0;iic_bus_error<=0;rd_data<=0;count<=0;end
 else if(!iic_busy && iic_req)begin
  if(wr_data[7:0]!=8'hd0)$fatal(1,"Wrong RTC address");
  iic_busy<=1;count<=3;iic_bus_error<=bad;
  if(rd_cnt==16)begin rd_data<=0;rd_data[23:0]<={timeval[23:16],timeval[15:8],timeval[7:0]};rd_data[127]<=osf;end
  else if(rd_cnt==1)rd_data<=(rollover?8'h00:timeval[7:0]);
  else begin
   case(writes)
    0:if(wr_data[23:8]!=16'h840e)$fatal(1,"Stop-chain write wrong");
    1:begin if(wr_cnt!=5 || wr_data[15:8]!=0)$fatal(1,"Time write wrong");timeval<={wr_data[39:32],wr_data[31:24],wr_data[23:16]};end
    2:if(wr_data[23:8]!=16'h040e)$fatal(1,"Enable-chain write wrong");
    3:if(wr_data[23:8]!=16'h000f)$fatal(1,"OSF clear wrong");
    default:$fatal(1,"Unexpected writes");
   endcase writes<=writes+1;
  end
 end else if(iic_busy)begin if(count==0)iic_busy<=0;else count<=count-1;end
end
endmodule
