`timescale 1ns/1ps
// Short press is emitted on debounced release. Long press is emitted once.
module key_gesture #(parameter integer DEBOUNCE_CYCLES=2000000,
                     parameter integer LONG_CYCLES=100000000)(
 input wire clk,rst_n,key_n, output reg short_pulse,long_pulse
);
wire pressed,unused_press;
reg was_pressed,long_sent;
localparam CW=(LONG_CYCLES<=1)?1:$clog2(LONG_CYCLES);
reg [CW-1:0] held;
button_filter #(.STABLE_CYCLES(DEBOUNCE_CYCLES)) filter(clk,rst_n,key_n,pressed,unused_press);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin was_pressed<=0;long_sent<=0;held<=0;short_pulse<=0;long_pulse<=0;end
 else begin
  was_pressed<=pressed;short_pulse<=0;long_pulse<=0;
  if(pressed) begin
   if(!long_sent) begin
    if(held==LONG_CYCLES-1) begin long_pulse<=1;long_sent<=1;end
    else held<=held+1'b1;
   end
  end else begin
   if(was_pressed && !long_sent)short_pulse<=1;
   held<=0;long_sent<=0;
  end
 end
end
endmodule
