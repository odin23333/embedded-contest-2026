`timescale 1ns/1ps
module bmp_fault_tb;
reg clk=0,rst=1,scan=0,load=0,ack=0,dv=0,ending=0;reg [7:0] din=0;
wire ready,done,found,req,rd,wen,error;wire [31:0] sector,addr;wire [2:0] total;wire [3:0] code;wire [23:0] pixel;
reg [7:0] valid_header[0:511],header[0:511];integer i,k,invalids=0;
always #5 clk=~clk;
bmp_read dut(clk,rst,ready,error,scan,32'd0,32'd0,3'd1,done,found,sector,total,
 load,32'd0,!rst,code,16'd640,16'd480,req,ack,rd,addr,din,dv,ending,wen,pixel);
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task reset;
begin rst=1;scan=0;load=0;dv=0;ending=0;ack=0;cycles(3);rst=0;cycles(2);for(i=0;i<512;i=i+1)header[i]=valid_header[i];end endtask
task send_sector;input integer bytes;
begin wait(rd);for(i=0;i<bytes;i=i+1)begin @(negedge clk);din=header[i];dv=1;end
 @(negedge clk);dv=0;ending=1;@(negedge clk);ending=0;cycles(4);end endtask
initial begin
 $readmemh("bmp_header.hex",valid_header);
 for(k=0;k<8;k=k+1)begin
  reset;
  case(k)
   0:header[21]=1; // Full 32-bit width must match, not only low 16 bits.
   1:header[25]=1;
   2:header[26]=0;
   3:header[14]=12;
   4:header[10]=0;
   5:header[2]=0; // file length is 54 bytes shorter than required pixels.
   6:begin header[10]=255;header[11]=255;header[12]=255;header[13]=255;end
   7:header[28]=32;
  endcase
  scan=1;cycles(1);scan=0;send_sector(512);
  if(!done || total!=0 || error || req || wen)$fatal(1,"Invalid scan/header failure %0d",k);
  load=1;cycles(1);load=0;send_sector(512);
  if(!ready || !error || req || wen)$fatal(1,"Invalid load not rejected %0d",k);
  invalids=invalids+1;
 end
 reset;scan=1;cycles(1);scan=0;send_sector(31);
 if(!error || total!=0)$fatal(1,"Short sector accepted");
 reset;load=1;cycles(1);load=0;send_sector(512);
 wait(req);ack=1;cycles(1);ack=0;send_sector(60);
 if(!ready || !error)$fatal(1,"Short payload sector not aborted");
 $display("PASS BMP_FAULTS: %0d malformed headers rejected during scan/load; truncated header/payload sectors reported; reset recovery",invalids);$finish;
end
initial begin #500000;$fatal(1,"Timeout");end
endmodule
