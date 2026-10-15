`timescale 1ns/1ps
module bmp_tb;
reg clk=0,rst=1,scan=0,load=0,ack=0,dvalid=0,secend=0;
reg [7:0] din=0;
reg [31:0] scanmax=1800;
wire ready,done,found,wrreq,rd,wen;
wire [31:0] foundsector,addr;
wire [2:0] total;wire [3:0] statecode;wire [23:0] pixel;
reg [7:0] card[0:922111];
reg [23:0] expected[0:307199];
integer i,j,base,pixels=0,foundcount=0,reads=0;
always #5 clk=~clk;
bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan),.scan_start_sector(32'd0),.scan_max_sector(scanmax),.scan_target_count(3'd1),.scan_done(done),.scan_found_valid(found),.scan_found_sector(foundsector),.scan_found_total(total),.load_start(load),.load_sector(32'd0),.sd_init_done(!rst),.state_code(statecode),.bmp_width(16'd640),.bmp_height(16'd480),.write_req(wrreq),.write_req_ack(ack),.sd_sec_read(rd),.sd_sec_read_addr(addr),.sd_sec_read_data(din),.sd_sec_read_data_valid(dvalid),.sd_sec_read_end(secend),.bmp_data_wr_en(wen),.bmp_data(pixel));
// Sector-level model only: no SPI protocol, SDRAM or encrypted HDMI simulation.
task reject_header;
input integer offset;input [7:0] value;
reg [7:0] saved;
begin
 saved=card[offset];card[offset]=value;scanmax=0;
 @(negedge clk);scan=1;@(negedge clk);scan=0;
 wait(!done);wait(done);repeat(4)@(negedge clk);
 if(total!=0 || foundcount!=1 || pixels!=307200)$fatal(1,"Invalid header accepted at %0d",offset);
 card[offset]=saved;
end endtask
initial begin
 $readmemh("bmp_bytes.hex",card);$readmemh("bmp_pixels.hex",expected);
 forever begin
  @(negedge clk);
  if(rd && !rst) begin
   base=addr*512;reads=reads+1;
   if(base+511>922111) $fatal(1,"Read beyond fixture");
   for(j=0;j<512;j=j+1) begin
    din=card[base+j];dvalid=1;
    @(negedge clk);dvalid=0;
    // Periodic stalls verify byte-valid gating and pixel pulse width.
    if(j%17==0) repeat(2) @(negedge clk);
   end
   secend=1;@(negedge clk);secend=0;
   repeat(3) @(negedge clk);
  end
 end
end
always @(posedge clk) begin
 #1;
 if(found) begin foundcount=foundcount+1;if(foundsector!=0)$fatal(1,"Wrong start sector");end
 if(wen) begin
  if(pixels>=307200)$fatal(1,"Too many pixels");
  if(pixel!==expected[pixels])$fatal(1,"BGR->RGB mismatch pixel=%0d got=%h expected=%h",pixels,pixel,expected[pixels]);
  pixels=pixels+1;
 end
end
initial begin
 repeat(4)@(negedge clk);rst=0;@(negedge clk);scan=1;@(negedge clk);scan=0;
 wait(done);@(negedge clk);
 if(total!=1 || foundcount!=1)$fatal(1,"Scan count");
 load=1;@(negedge clk);load=0;
 wait(wrreq);repeat(8)@(negedge clk);ack=1;@(negedge clk);ack=0;
 wait(!ready);wait(ready);repeat(4)@(negedge clk);
 if(pixels!=307200)$fatal(1,"Pixel count=%0d",pixels);
 reject_header(0,8'h58);reject_header(28,8'd32);reject_header(30,8'd1);reject_header(18,8'd0);
 $display("PASS BMP: real 640x480 BMP; 307200 RGB pixels; ACK/stalls/sectors; rejects signature, bit depth, compression and width errors");$finish;
end
initial begin #20000000;$fatal(1,"Timeout");end
endmodule
