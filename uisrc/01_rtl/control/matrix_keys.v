`timescale 1ns/1ps
// One active-low row at a time, other rows high impedance to avoid key shorts.
// Frame=1 ms at 100 MHz. Reject multi-key frames (matrix has no isolation diodes).
module matrix_keys #(parameter SLOT=25000, STABLE=20)(
 input clk,rst_n,input [3:0] cols,output [3:0] rows,
 output reg [15:0] down,output reg [15:0] pressed);
localparam CW=$clog2(SLOT);reg [CW-1:0] ticks;reg [1:0] row;
reg [3:0] col_meta,col_sync;reg [15:0] frame,candidate;
reg [7:0] count;reg [15:0] sample;integer k;
genvar g;generate for(g=0;g<4;g=g+1)begin:drive
 assign rows[g]=(row==g)?1'b0:1'bz;
end endgenerate
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin ticks<=0;row<=0;col_meta<=15;col_sync<=15;frame<=0;candidate<=0;count<=0;down<=0;pressed<=0;end
 else begin
  col_meta<=cols;col_sync<=col_meta;pressed<=0;
  if(ticks==SLOT-1)begin
   ticks<=0;row<=row+1'b1;frame[row*4+:4]<=~col_sync;
   if(row==3)begin
    sample={~col_sync,frame[11:0]};
    if((sample & (sample-1'b1))!=0)sample=0;
    if(sample!=candidate)begin candidate<=sample;count<=0;end
    else if(count<STABLE-1)count<=count+1'b1;
    else if(down!=candidate)begin down<=candidate;pressed<=candidate & ~down;end
   end
  end else ticks<=ticks+1'b1;
 end
end
endmodule
