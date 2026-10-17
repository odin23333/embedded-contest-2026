`timescale 1ns/1ps
// Bottom playback panel, frame snapshots and one registered RGB/sync stage.
// metadata={switch_request,load_busy,complete,total[2:0],next[1:0],current[1:0]}.
module playback_osd(input clk,rst_n,input [9:0] metadata,input [2:0] countdown,
 input auto_enabled,request_pending,valid,alarm,fault,retrying,input [4:0] fade_gain,
 input hs,vs,de,input [23:0] rgb,
 output reg out_hs,out_vs,out_de,output reg [23:0] out_rgb);
reg vs_prev,de_prev,show,frame_auto,frame_request;reg [9:0] x,y,info;
reg [2:0] seconds_left;reg [4:0] gain;
reg [5:0] char_index;reg [3:0] char_pixel;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin vs_prev<=0;de_prev<=0;x<=0;y<=0;show<=0;frame_auto<=0;frame_request<=0;info<=0;seconds_left<=0;gain<=16;char_index<=0;char_pixel<=0;end
 else begin
  vs_prev<=vs;de_prev<=de;
  if(vs_prev && !vs)begin
   x<=0;y<=0;char_index<=0;char_pixel<=0;show<=valid && metadata[6:4]!=0 && !alarm && !fault && !retrying;
   info<=metadata;frame_auto<=auto_enabled;frame_request<=request_pending;seconds_left<=countdown;gain<=fade_gain;
  end else if(de)begin
   x<=x+1'b1;
   if(x<16)begin char_index<=0;char_pixel<=0;end
   else if(char_pixel==11)begin char_index<=char_index+1'b1;char_pixel<=0;end
   else char_pixel<=char_pixel+1'b1;
  end else begin x<=0;char_index<=0;char_pixel<=0;if(de_prev)y<=y+1'b1;end
 end
end
function [34:0] font;input [7:0] c;begin case(c)
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
 ":":font={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
 "-":font={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
 "B":font={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
 "C":font={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
 "H":font={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
 "K":font={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
 "V":font={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
 "X":font={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
 "Q":font={5'b01110,5'b10001,5'b10001,5'b10001,5'b10101,5'b10010,5'b01101};
 "_":font={5'b00000,5'b00000,5'b00000,5'b00000,5'b00000,5'b00000,5'b11111};
 "/":font={5'b00001,5'b00010,5'b00010,5'b00100,5'b01000,5'b01000,5'b10000};
 default:font=0;endcase end endfunction
reg [319:0] text;reg [7:0] letter;reg [34:0] glyph;reg [23:0] color;
reg [2:0] row,col;reg [5:0] glyph_bit;
wire [9:0] text_y=(y<415)?(y-10'd398):(y-10'd418);
always @*begin
 color=rgb;text=0;letter=0;glyph=0;row=0;col=0;glyph_bit=0;
 if(show && de && x>=8 && x<632 && y>=394 && y<436)begin
  color=24'h0f172a;
  if(y==394 || y==435)color=24'h1e3a5f;
  if(y<415)begin
   text="PIC 1/4  NEXT 2/4  CACHE WAIT           ";
   text[287:280]=8'h31+{6'd0,info[1:0]};
   text[271:264]=8'h30+{5'd0,info[6:4]};
   text[207:200]=8'h31+{6'd0,info[3:2]};
   text[191:184]=8'h30+{5'd0,info[6:4]};
   if(info[6:4]<2)begin text[207:200]="-";text[191:184]="-";end
   if(info[8] && info[7])text[119:80]="READY";
   else if(info[8])text[119:80]="LOAD ";
   if(info[6:4]<2)text[119:80]="N/A  ";
  end else begin
   text="MANUAL    KEY1 NEXT  KEY2 AUTO          ";
   if(frame_auto)begin
    text="AUTO 05S  KEY1 NEXT  KEY2 STOP          ";
    text[271:264]=8'h30+{5'd0,seconds_left};
   end
   if(gain<16 || ((frame_request||info[9]) && info[7]))text="SWITCHING IMAGE - PLEASE WAIT           ";
   else if(frame_request || info[9])text="WAIT NEXT IMAGE - REQUEST QUEUED        ";
   else if(frame_auto && seconds_left==0)text="AUTO WAIT - IMAGE BUSY                  ";
  end
  if((y>=398 && y<412) || (y>=418 && y<432))begin
   row=text_y[3:1];col=char_pixel[3:1];
   if(x>=16 && char_index<40 && char_pixel<10)begin
    letter=text>>{(6'd39-char_index),3'b000};glyph=font(letter);
    glyph_bit=6'd34-({3'd0,row}<<2)-{3'd0,row}-{3'd0,col};
    if(glyph[glyph_bit])color=24'he2e8f0;
   end
  end
 end
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin out_hs<=0;out_vs<=0;out_de<=0;out_rgb<=0;end
 else begin out_hs<=hs;out_vs<=vs;out_de<=de;out_rgb<=color;end
end
endmodule
