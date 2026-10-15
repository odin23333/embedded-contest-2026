`timescale 1ns/1ps
// Fade the old DDR image only after its replacement has finished loading.
// Hold at black until the frame-boundary buffer commit is observed, then fade in.
module image_fade(input clk,rst_n,frame_tick,valid,cancel,pending_ready,
 input [1:0] buffer_index,input [23:0] rgb,
 output commit_permit,output [23:0] faded_rgb,output [4:0] gain);
localparam IDLE=0,OUT=1,BLACK=2,IN=3;
reg [1:0] state,last_buffer;reg [4:0] level;
assign gain=level;
assign commit_permit=(state==BLACK);
wire [12:0] r=rgb[23:16]*level,g=rgb[15:8]*level,b=rgb[7:0]*level;
assign faded_rgb={r[11:4],g[11:4],b[11:4]};
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin state<=IDLE;last_buffer<=0;level<=16;end
 else if(frame_tick)begin
  if(cancel || !valid)begin state<=IDLE;level<=16;last_buffer<=buffer_index;end
  else case(state)
   IDLE:begin level<=16;last_buffer<=buffer_index;if(pending_ready)state<=OUT;end
   OUT:begin
    if(!pending_ready)begin state<=IDLE;level<=16;end
    else if(level==1)begin level<=0;state<=BLACK;end
    else level<=level-1'b1;
   end
   BLACK:begin
    if(buffer_index!=last_buffer)begin last_buffer<=buffer_index;level<=1;state<=IN;end
    else if(!pending_ready)begin state<=IDLE;level<=16;end
   end
   IN:begin if(level==15)begin level<=16;state<=IDLE;end else level<=level+1'b1;end
   default:begin state<=IDLE;level<=16;end
  endcase
 end
end
endmodule
