`timescale 1ns/1ps
// status={display_valid,load_busy,muted,auto_enabled,emergency}.
// frame_start is a one-cycle pulse in vertical blanking, before the first pixel.
module status_osd(
 input wire clk,rst_n,frame_start,
 input wire [5:0] status,
 input wire [9:0] x,y,input wire hs,vs,de,input wire [23:0] rgb,
 output reg out_hs,out_vs,out_de,output reg [23:0] out_rgb
);
reg [5:0] frame_status;
reg [23:0] color;
reg [55:0] word;
reg [7:0] letter;
reg [34:0] glyph;
integer local_x,k,row,col;
function [34:0] font;
input [7:0] c;
begin
case(c)
 "A":font={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
 "D":font={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
 "E":font={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
 "F":font={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
 "G":font={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
 "I":font={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
 "L":font={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
 "M":font={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
 "N":font={5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001};
 "O":font={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
 "P":font={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
 "R":font={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
 "S":font={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
 "T":font={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
 "U":font={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
 "W":font={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b11011,5'b10001};
 "Y":font={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
 default:font=35'd0;
endcase
end endfunction
always @* begin
 color=rgb;local_x=0;word=56'd0;letter=0;glyph=0;row=0;col=0;
 if(de && y<24 && x<640)begin
  if(x<160)begin local_x=x;word=frame_status[0]?"ALARM  ":"NORMAL ";color=frame_status[0]?24'hb91c1c:24'h166534;end
  else if(x<320)begin local_x=x-160;
   word=frame_status[0]?"PAUSED ":(frame_status[1]?"AUTO   ":"MANUAL ");
   color=(frame_status[1]&&!frame_status[0])?24'h1d4ed8:24'h334155;
  end
  else if(x<480)begin local_x=x-320;word=frame_status[2]?"MUTED  ":"SOUND  ";color=frame_status[2]?24'h475569:24'h854d0e;end
  else begin local_x=x-480;
   word=frame_status[5]?"FAULT  ":(frame_status[3]?"LOADING":(frame_status[4]?"READY  ":"WAIT   "));
   color=frame_status[5]?24'hb91c1c:(frame_status[3]?24'h92400e:(frame_status[4]?24'h155e75:24'h334155));
  end
  if(local_x==159 || y==23)color=24'h0f172a;
  if(y>=5 && y<19)begin
   row=(y-5)>>1;
   for(k=0;k<7;k=k+1)begin
    if(local_x>=8+12*k && local_x<18+12*k)begin
     letter=word>>(8*(6-k));glyph=font(letter);col=(local_x-8-12*k)>>1;
     if(glyph[34-row*5-col])color=24'hffffff;
    end
   end
  end
 end
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin frame_status<=0;out_hs<=0;out_vs<=0;out_de<=0;out_rgb<=0;end
 else begin
  if(frame_start)frame_status<=status;
  out_hs<=hs;out_vs<=vs;out_de<=de;out_rgb<=color;
 end
end
endmodule
