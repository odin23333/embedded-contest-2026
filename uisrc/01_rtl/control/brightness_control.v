`timescale 1ns/1ps
// KEY5 cycles 100 -> 75 -> 50 -> 25 -> 100 percent once per press.
// Emergency/fault pauses changes; preference survives emergency, reset=100%.
module brightness_control(input clk,rst_n,press,pause,output reg [1:0] level);
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)level<=3;
 else if(press && !pause)level<=level-1'b1;
end
endmodule
