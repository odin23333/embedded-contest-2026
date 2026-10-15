`timescale 1ns/1ps
// Fixed on-chip emergency text. Independent of TF card and DDR.
module alarm_screen #(parameter FLASH_ENABLED=0)(input [9:0] x,y,input alarm,input [23:0] normal_rgb,output reg [23:0] rgb,input flash_on);
function [63:0] title_row;input [3:0] row;begin case(row)
4'd0:title_row=64'h0c000c0030003ffc;
4'd1:title_row=64'h6dfc1ff033fc0000;
4'd2:title_row=64'h6c8c306033040000;
4'd3:title_row=64'h6c787ffcfffc0000;
4'd4:title_row=64'h6df800043304ffff;
4'd5:title_row=64'h0f1e3ffc33fc0180;
4'd6:title_row=64'h0e3000043b041898;
4'd7:title_row=64'h1fc03ffc38001098;
4'd8:title_row=64'h03180104f7ff308c;
4'd9:title_row=64'h1ffc6d84b0206086;
4'd10:title_row=64'h3f826c9633204082;
4'd11:title_row=64'h08904c13333e4182;
4'd12:title_row=64'h389e4c1333200f80;
4'd13:title_row=64'h678607f034e00000;
4'd14:title_row=64'h00000000ec7f0000;
4'd15:title_row=64'h0000000000000000;
default:title_row=0;endcase end endfunction
wire [63:0] title_bits=title_row((y-80)>>2);
wire title_pixel=(x>=192 && x<448 && y>=80 && y<144) && title_bits[63-((x-192)>>2)];
function [79:0] calm_row;input [3:0] row;begin case(row)
4'd0:calm_row=80'h60601000302000600060;
4'd1:calm_row=80'h37ff13fc302040e01840;
4'd2:calm_row=80'h1060320433fe60b07efc;
4'd3:calm_row=80'h07fe2204fc2031d81988;
4'd4:calm_row=80'h006062043020326c7e18;
4'd5:calm_row=80'hffff63fc37ff0c2619fe;
4'd6:calm_row=80'h3000e26430000803fe36;
4'd7:calm_row=80'h33fea060380837fe0036;
4'd8:calm_row=80'h32062fff7808300c7fff;
4'd9:calm_row=80'h33fe20f0f7ff20084636;
4'd10:calm_row=80'h3ffe2168300c60187e36;
4'd11:calm_row=80'h3a0626663108623047fe;
4'd12:calm_row=80'h32062c63308841e07e36;
4'd13:calm_row=80'h223c2060300840704630;
4'd14:calm_row=80'h00000000e07800184630;
4'd15:calm_row=80'h00000000000000005ce0;
default:calm_row=0;endcase end endfunction
wire [79:0] calm_bits=calm_row((y-190)>>1);
wire calm_pixel=(x>=240 && x<400 && y>=190 && y<222) && calm_bits[79-((x-240)>>1)];
function [95:0] guide_row;input [3:0] row;begin case(row)
4'd0:guide_row=96'h001e1860fffe300033000004;
4'd1:guide_row=96'h7df81860330633fc33067f84;
4'd2:guide_row=96'h6d8018603326301c333c0184;
4'd3:guide_row=96'h4d80186033263030ffe30084;
4'd4:guide_row=96'h4d8018603326fce033033f84;
4'd5:guide_row=96'h4d801860ff26318031fe2184;
4'd6:guide_row=96'h4dff1c60332633fe30002004;
4'd7:guide_row=96'h4d881670336630927bfe6004;
4'd8:guide_row=96'h4d88135033763192f3067f84;
4'd9:guide_row=96'h4d8831d033703d3233fe0084;
4'd10:guide_row=96'h7d8830983c737b2233060084;
4'd11:guide_row=96'h61082188f8b3c64233060184;
4'd12:guide_row=96'h0308630c0133088633fe0184;
4'd13:guide_row=96'h02084606061e013ce3061f04;
4'd14:guide_row=96'h060884020400000000000004;
4'd15:guide_row=96'h000000000000000000000000;
default:guide_row=0;endcase end endfunction
wire [95:0] guide_bits=guide_row((y-260)>>1);
wire guide_pixel=(x>=224 && x<416 && y>=260 && y<292) && guide_bits[95-((x-224)>>1)];
function [271:0] keys_row;input [3:0] row;begin case(row)
4'd0:keys_row=272'h18600fe0181007c00000601e7ffe00000000000018600fe0181000c0000000600180;
4'd1:keys_row=272'h18600fc00c300ce0000023fc600600000000000018600fc00c3000c0000018407ffe;
4'd2:keys_row=272'h18c00c000c20006000003200600600000000000018c00c000c2001c000007efc0c30;
4'd3:keys_row=272'h19800c00066000600000120067e600000000000019800c0006600340000019880c30;
4'd4:keys_row=272'h1b000c00066000c0000003fe64260000000000001b000c000660024000007e18ffff;
4'd5:keys_row=272'h1e000fe003c007800000f20664260000000000001e000fe003c00640000019fe0000;
4'd6:keys_row=272'h1e000fc003c000c00000328464260000000000001e000fc003c00c400000fe363ffc;
4'd7:keys_row=272'h1b000c0001800060000032cc64260000000000001b000c000180184000000036300c;
4'd8:keys_row=272'h19800c00018000600000367867e600000000000019800c0001801ff000007fff300c;
4'd9:keys_row=272'h18c00c000180006000003638642600000000000018c00c00018000e0000046363ffc;
4'd10:keys_row=272'h18600fe001800ce00000347c600600000000000018600fe00180004000007e36300c;
4'd11:keys_row=272'h18300fe001800f8000003dc6600600000000000018300fe001800040000047fe300c;
4'd12:keys_row=272'h000000000000000000007b027ffe000000000000000000000000000000007e363ffc;
4'd13:keys_row=272'h00000000000000000000d8006006000000000000000000000000000000004630300c;
4'd14:keys_row=272'h000000000000000000008fff00000000000000000000000000000000000046300000;
4'd15:keys_row=272'h0000000000000000000000000000000000000000000000000000000000005ce00000;
default:keys_row=0;endcase end endfunction
wire [271:0] keys_bits=keys_row((y-365)>>0);
wire keys_pixel=(x>=184 && x<456 && y>=365 && y<381) && keys_bits[271-((x-184)>>0)];
always @* begin
rgb=normal_rgb;
if(alarm)begin
rgb=(FLASH_ENABLED && !flash_on)?24'h260b0b:24'hb91c1c;
if(x<12 || x>=628 || y>=468)rgb=(FLASH_ENABLED && !flash_on)?24'h78350f:24'hfbbf24;
if(x>=40 && x<600 && y>=48 && y<440)rgb=(FLASH_ENABLED && !flash_on)?24'h140505:24'h7f1d1d;
if(y>=158 && y<162 && x>=160 && x<480)rgb=(FLASH_ENABLED && !flash_on)?24'h78350f:24'hfbbf24;
if(!FLASH_ENABLED)begin
 rgb=24'h7f1d1d;
 if(x<12 || x>=628 || y>=468)rgb=24'hfbbf24;
 if(x>=40 && x<600 && y>=48 && y<440)rgb=24'h450a0a;
 if(y>=158 && y<162 && x>=160 && x<480)rgb=24'hfbbf24;
end
if(title_pixel || calm_pixel || guide_pixel || keys_pixel)rgb=24'hffffff;
end
end
endmodule
