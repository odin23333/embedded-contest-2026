`timescale 1ns/1ps
// KEY6 retries only the image/card/DDR subsystem. HDMI, RTC and alarm keep running.
// No automatic reset loop: a failed retry remains visible until the next key press.
module error_recovery #(parameter RESET_CYCLES=1024)(
 input clk,rst_n,retry_key,fault,input [7:0] cause,input image_ready,
 output image_rst_n,output reg retrying,output reg [7:0] error_code);
localparam CW=(RESET_CYCLES<2)?1:$clog2(RESET_CYCLES);
reg [CW-1:0] count;reg holding;
assign image_rst_n=rst_n && !holding;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin holding<=0;count<=0;retrying<=0;error_code<=0;end
 else if(holding)begin
  if(count==RESET_CYCLES-1)begin holding<=0;count<=0;end
  else count<=count+1'b1;
 end else if(retry_key)begin holding<=1;count<=0;retrying<=1;end
 else if(fault)begin
  if(error_code==0 || retrying)error_code<=cause;
  retrying<=0;
 end else if(image_ready)begin retrying<=0;error_code<=0;end
end
endmodule

// Frame-latched banner. Existing picture/status pass through unchanged otherwise.
module error_osd(input clk,rst_n,input [7:0] error_code,input retrying,emergency,
 input vs,de,input [23:0] rgb,output reg [23:0] out_rgb);
reg vs_prev,de_prev,show,retry;reg [7:0] code;reg [9:0] x,y;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin vs_prev<=0;de_prev<=0;x<=0;y<=0;show<=0;retry<=0;code<=0;end
 else begin
  vs_prev<=vs;de_prev<=de;
  if(vs_prev && !vs)begin x<=0;y<=0;show<=!emergency && (error_code!=0 || retrying);retry<=retrying;code<=error_code;end
  else if(de)x<=x+1'b1;
  else begin x<=0;if(de_prev)y<=y+1'b1;end
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
function [7:0] hexchar;input [3:0] n;begin hexchar=n<10?8'h30+n:8'h41+n-10;end endfunction
reg [319:0] text;reg [7:0] letter;reg [34:0] glyph;integer k,row,col;
always @*begin
 out_rgb=rgb;text=0;letter=0;glyph=0;row=0;col=0;
 if(show && de && x>=8 && x<632 && y>=28 && y<70)begin
  out_rgb=retry?24'h164e63:24'h7f1d1d;
  if(y<49)begin
   case(code)
    8'h81,8'h41:text="    CHECK CARD / INSERT THEN RETRY      ";
    8'h02,8'h03:text="    CARD READ FAILED / REINSERT CARD    ";
    8'h10,8'h11,8'h12,8'h13:text="    USE FAT32 / CHECK PARTITION         ";
    8'h14,8'h15,8'h16:text="    FAT DIRECTORY OR CHAIN DAMAGED      ";
    8'h17:text="    NO BMP / CHECK MLK_TEST FOLDER      ";
    8'h20,8'h21,8'h22,8'h23,8'h24,8'h25,8'h26:text="    BMP FILE OR CLUSTER CHAIN DAMAGED   ";
    8'h30:text="    USE BMP24 BI_RGB / SIZE 1 TO 2048   ";
    8'h43,8'h44:text="    DDR NOT READY / RETRY OR RESET      ";
    8'h46:text="    VIDEO QUEUE OVERFLOW / RETRY        ";
    default:text="    LOAD TIMEOUT / CHECK CARD AND BMP   ";
   endcase
   text[319:296]={"E",hexchar(code[7:4]),hexchar(code[3:0])};
   if(retry)text="RETRYING CARD AND IMAGE - PLEASE WAIT   ";
  end else text="KEY6 RETRY    KEY16 FULL RESET          ";
  if((y>=32 && y<46) || (y>=52 && y<66))begin
   row=(y<49?(y-32):(y-52))>>1;
   for(k=0;k<40;k=k+1)if(x>=16+12*k && x<26+12*k)begin
    letter=text>>(8*(39-k));glyph=font(letter);col=(x-16-12*k)>>1;
    if(glyph[34-row*5-col])out_rgb=24'hffffff;
   end
  end
 end
end
endmodule
