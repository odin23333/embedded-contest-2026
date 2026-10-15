`timescale 1ns/1ps
// Only independent, persistent status flags; not a coherent data bus or pulse CDC.
module level_sync #(parameter WIDTH=1)(
 input wire clk,rst_n,input wire [WIDTH-1:0] async_levels,
 output reg [WIDTH-1:0] levels
);
reg [WIDTH-1:0] meta;
always @(posedge clk or negedge rst_n)
 if(!rst_n)begin meta<=0;levels<=0;end
 else begin meta<=async_levels;levels<=meta;end
endmodule
