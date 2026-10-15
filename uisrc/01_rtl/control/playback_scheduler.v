`timescale 1ns/1ps
// All ports are in ctrl_clk. Backend must assert busy after accepting a request.
module playback_scheduler #(parameter integer AUTO_CYCLES=500000000)(
 input wire clk,rst_n,pause,auto_enabled,next_event,
 input wire display_valid,has_multiple,load_busy,load_ready,
 output wire next_valid,output wire pending_request
);
localparam CW=(AUTO_CYCLES<=1)?1:$clog2(AUTO_CYCLES);
reg [CW-1:0] idle_count;
reg pending;
reg pending_auto;
assign pending_request=pending;
assign next_valid=pending && (!pending_auto || auto_enabled) && !pause && display_valid && has_multiple && !load_busy;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin idle_count<=0;pending<=0;pending_auto<=0;end
 else if(pause || !display_valid || !has_multiple)begin idle_count<=0;pending<=0;pending_auto<=0;end
 else begin
  if(pending_auto && !auto_enabled)begin pending<=0;pending_auto<=0;end
  if(next_valid && load_ready)begin pending<=0;pending_auto<=0;end
  // Coalesce additional presses while a request is pending (no multi-page queue).
  if(next_event && (!pending || (pending_auto && !(next_valid && load_ready))))begin pending<=1;pending_auto<=0;end
  if(!auto_enabled || load_busy || pending || next_event)idle_count<=0;
  else if(idle_count==AUTO_CYCLES-1)begin idle_count<=0;pending<=1;pending_auto<=1;end
  else idle_count<=idle_count+1'b1;
 end
end
endmodule
