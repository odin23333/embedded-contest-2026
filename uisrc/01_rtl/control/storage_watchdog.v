`timescale 1ns/1ps
// Sticky storage fault, cleared by user reset. Progress is actual bytes/events,
// not a busy level. Emergency control/video/audio remain independent of fault.
module storage_watchdog #(parameter TIMEOUT_CYCLES=125000000)(
 input clk,rst_n,active,progress,ddr_ready,hard_error,output reg fault);
localparam CW=(TIMEOUT_CYCLES<=1)?1:$clog2(TIMEOUT_CYCLES);
reg [CW-1:0] idle_count;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin idle_count<=0;fault<=0;end
 else if(hard_error)fault<=1;
 else if(!fault)begin
  if(ddr_ready && (!active || progress))idle_count<=0;
  else if(idle_count==TIMEOUT_CYCLES-1)fault<=1;
  else idle_count<=idle_count+1'b1;
 end
end
endmodule

// Once initialized DDR loses ready, its old contents are not trusted again
// until a complete user reset/reload. Initial boot wait is not a loss event.
module memory_health(input clk,rst_n,ready,output trusted,output reg lost);
reg seen_ready;
assign trusted=ready && !lost;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin seen_ready<=0;lost<=0;end
 else if(ready)seen_ready<=1;
 else if(seen_ready)lost<=1;
end
endmodule
