`timescale 1ns/1ps
module bmp_pixel_bounds_tb;
reg clk=0,rst=1,scan=0,load=0,ack=0,dv=0,ending=0;reg [7:0] din=0;
wire ready,error,done,found,req,rd,wen;wire [31:0] sector,addr;wire [2:0] total;wire [3:0] code;wire [23:0] pixel;
reg [7:0] card[0:511];integer i,pixels=0;
always #5 clk=~clk;
bmp_read dut(clk,rst,ready,error,scan,32'd0,32'd0,3'd1,done,found,sector,total,
 load,32'd0,!rst,code,16'd4,16'd1,req,ack,rd,addr,din,dv,ending,wen,pixel);
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task send_sector;begin wait(rd);for(i=0;i<512;i=i+1)begin @(negedge clk);din=card[i];dv=1;end
 @(negedge clk);dv=0;ending=1;@(negedge clk);ending=0;cycles(4);end endtask
always @(posedge clk)begin #1;if(wen)begin
 if(pixels>=4 || pixel!==24'h112233)$fatal(1,"Tail bytes published as pixels");pixels=pixels+1;
end end
initial begin
 for(i=0;i<512;i=i+1)card[i]=0;
 card[0]="B";card[1]="M";card[2]=72;card[10]=54;card[14]=40;card[18]=4;card[22]=1;card[26]=1;card[28]=24;
 for(i=54;i<66;i=i+3)begin card[i]=8'h33;card[i+1]=8'h22;card[i+2]=8'h11;end
 for(i=66;i<72;i=i+1)card[i]=8'hff;
 cycles(4);rst=0;load=1;cycles(1);load=0;send_sector;
 wait(req);ack=1;cycles(1);ack=0;send_sector;
 if(!ready || error || pixels!=4)$fatal(1,"Pixel boundary/ready failure");
 $display("PASS BMP_PIXEL_BOUNDS: valid BMP with trailing bytes emits exactly width*height pixels, correct BGR/RGB and complete-sector termination");$finish;
end
initial begin #50000;$fatal(1,"Timeout");end
endmodule
