`timescale 1ns/1ps
// BCD HH:MM:SS. Frame snapshot prevents mixed digits during a second rollover.
module timestamp_osd(input clk,rst_n,frame_start,visible,time_valid,input [23:0] time_bcd,
 input [9:0] x,y,input de,input [23:0] rgb,output reg [23:0] out_rgb);
reg [23:0] frame_time;reg frame_visible,frame_time_valid;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin frame_time<=0;frame_visible<=0;frame_time_valid<=0;end
 else if(frame_start)begin frame_time<=time_bcd;frame_visible<=visible;frame_time_valid<=time_valid;end
end
function [34:0] font;
 input [7:0] c;begin case(c)
 "0":font={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
 "1":font={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
 "2":font={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
 "3":font={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
 "4":font={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
 "5":font={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
 "6":font={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
 "7":font={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
 "8":font={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
 "9":font={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
 "U":font={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
 "P":font={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
 ":":font={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
 "-":font={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
 default:font=0;endcase end
endfunction
reg [63:0] text;reg [7:0] letter;reg [34:0] glyph;integer k,row,col;
always @*begin
 out_rgb=rgb;letter=0;glyph=0;row=0;col=0;
 text={(8'h30+{4'd0,frame_time[23:20]}),(8'h30+{4'd0,frame_time[19:16]}),":",
 (8'h30+{4'd0,frame_time[15:12]}),(8'h30+{4'd0,frame_time[11:8]}),":",
 (8'h30+{4'd0,frame_time[7:4]}),(8'h30+{4'd0,frame_time[3:0]})};
 if(!frame_time_valid)text="--:--:--";
 if(de && frame_visible && x>=516 && x<628 && y>=440 && y<468)begin
  out_rgb=24'h0f172a;
  if(x==516 || x==627 || y==440 || y==467)out_rgb=24'h38bdf8;
  if(y>=447 && y<461)begin
   row=(y-447)>>1;
   for(k=0;k<8;k=k+1)if(x>=524+k*12 && x<534+k*12)begin
    letter=text>>(8*(7-k));glyph=font(letter);col=(x-524-k*12)>>1;
    if(glyph[34-row*5-col])out_rgb=24'hffffff;
   end
  end
 end
end
endmodule
