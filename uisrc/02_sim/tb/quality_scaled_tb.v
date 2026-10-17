`timescale 1ns/1ps
module quality_scaled_tb;
reg clk=0,rst=1,scan=0,load=0,ack=0,dv=0,ending=0,space=1;reg[7:0] din=0;
wire ready,error,done,found,req,rd,wen;wire[31:0] sector,addr;wire[2:0] total;wire[3:0] code;wire[23:0] pixel;
reg[7:0] card[0:13000000];reg[23:0] expected[0:307199];
reg[1023:0] filename,expname;integer size,i,j,base,pixels=0,cycles=0,reads=0;
always #5 clk=~clk;
always @(negedge clk)begin cycles=cycles+1;space=(cycles%11!=0 && cycles%11!=1);end
bmp_scaled_read dut(clk,rst,ready,error,scan,32'd0,32'd0,3'd1,done,found,sector,total,load,32'd0,!rst,code,16'd640,16'd480,req,ack,rd,addr,din,dv,ending,wen,pixel,space);
initial begin
 filename="scaled_fixture_bytes.hex";expname="scaled_fixture_expected.hex";size=512;
 i=$value$plusargs("CARD=%s",filename);i=$value$plusargs("EXPECT=%s",expname);i=$value$plusargs("SIZE=%d",size);
 $readmemh(filename,card,0,size-1);$readmemh(expname,expected);
 forever begin
  @(negedge clk);
  if(rd && !rst)begin
   base=addr*512;reads=reads+1;if(base+511>=size)$fatal(1,"Reads beyond source");
   for(j=0;j<512;j=j+1)begin din=card[base+j];dv=1;@(negedge clk);dv=0;if(j%37==0)@(negedge clk);end
   ending=1;@(negedge clk);ending=0;repeat(3)@(negedge clk);
  end
 end
end
always @(posedge clk)begin #1;
 if(wen)begin
  if(!space)$fatal(1,"Ignores FIFO backpressure");
  if(pixels>=307200 || pixel!==expected[pixels])$fatal(1,"Pixel mismatch %0d got=%h expected=%h",pixels,pixel,expected[pixels]);
  pixels=pixels+1;
 end
end
initial begin
 repeat(5)@(negedge clk);rst=0;scan=1;@(negedge clk);scan=0;wait(done);if(total!=1)$fatal(1,"Valid dimensions not found");
 @(negedge clk);load=1;@(negedge clk);load=0;wait(req);repeat(7)@(negedge clk);ack=1;@(negedge clk);ack=0;
 wait(ready);repeat(4)@(negedge clk);if(error || pixels!=307200)$fatal(1,"Error or wrong output count %0d",pixels);
 $display("PASS QUALITY_BMP: exact 307200 RGB pixels, center Q0.8 bilinear aspect-fit/black bars, padding, sectors, FIFO stalls, reads=%0d",reads);$finish;
end
initial begin #1000000000;$fatal(1,"Timeout");end
endmodule
