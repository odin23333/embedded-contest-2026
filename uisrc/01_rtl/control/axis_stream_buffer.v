`timescale 1ns/1ps
// Video cannot be stalled at the pixel input. Buffer bounded downstream stalls.
// Overflow is sticky until reset; the lost pixel pulse is explicitly reported.
module axis_stream_buffer #(parameter DEPTH=32)(
 input clk,rst_n,input in_valid,in_user,in_last,input [23:0] in_data,
 input out_ready,output out_valid,out_user,out_last,output [23:0] out_data,
 output reg overflow,output reg [$clog2(DEPTH):0] count);
localparam AW=$clog2(DEPTH);
reg [25:0] mem [0:DEPTH-1];reg [AW-1:0] wr,rd;
wire pop=out_ready && out_valid;
reg drop_frame;
wire room=(count<DEPTH) || pop;
wire push=in_valid && room && (!drop_frame || in_user);
assign out_valid=(count!=0);
assign {out_user,out_last,out_data}=mem[rd];
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin wr<=0;rd<=0;count<=0;overflow<=0;drop_frame<=0;end
 else begin
  if(in_valid && !room)begin overflow<=1;drop_frame<=1;end
  if(push && in_user)drop_frame<=0;
  if(push)begin mem[wr]<={in_user,in_last,in_data};wr<=wr+1'b1;end
  if(pop)rd<=rd+1'b1;
  case({push,pop})
   2'b10:count<=count+1'b1;
   2'b01:count<=count-1'b1;
   default:count<=count;
  endcase
 end
end
endmodule
