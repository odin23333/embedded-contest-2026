`timescale 1ns/1ps
// Pixel-domain fixed-point scaling, no extra pixel latency and no multipliers.
module brightness_rgb(input [23:0] rgb,input [1:0] level,output [23:0] scaled);
function [7:0] scale;
input [7:0] value;input [1:0] gain;reg [9:0] triple;
begin
 triple={2'b0,value}+{1'b0,value,1'b0};
 case(gain)
  3:scale=value;
  2:scale=triple[9:2];
  1:scale={1'b0,value[7:1]};
  default:scale={2'b0,value[7:2]};
 endcase
end endfunction
assign scaled={scale(rgb[23:16],level),scale(rgb[15:8],level),scale(rgb[7:0],level)};
endmodule
