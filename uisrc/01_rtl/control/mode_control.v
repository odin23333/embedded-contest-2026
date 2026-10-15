`timescale 1ns/1ps
module mode_control(
 input wire clk,rst_n,next_pulse,auto_pulse,emergency_pulse,mute_pulse,
 output reg emergency,muted,auto_enabled,next_event
);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n)begin emergency<=0;muted<=0;auto_enabled<=0;next_event<=0;end
 else begin
  next_event<=0;
  if(mute_pulse)muted<=~muted;
  // Emergency transition wins over simultaneous manual/auto events.
  if(emergency_pulse)emergency<=~emergency;
  else if(!emergency)begin
   if(auto_pulse)auto_enabled<=~auto_enabled;
   if(next_pulse)next_event<=1;
  end
 end
end
endmodule
