`timescale 1ns/1ns
module i2c_enable_tb;
reg clk=0;always #20 clk=~clk;
reg rst=1,req=0,ack=0;reg[7:0] wc=3,rc=0;reg[39:0] wd=40'h0004_0ed0;
tri1 sd0,sd1;assign sd0=ack?0:1'bz;assign sd1=ack?0:1'bz;
wire sc0,sc1,b0,b1,e0,e1,d0,d1;wire[127:0] rd0,rd1;
uii2c_reference #(.WMEN_LEN(5),.RMEN_LEN(16),.CLK_DIV(19)) refbus(clk,rst,sc0,sd0,wd,wc,rd0,rc,req,b0,e0,d0);
uii2c #(.WMEN_LEN(5),.RMEN_LEN(16),.CLK_DIV(19)) newbus(clk,rst,sc1,sd1,wd,wc,rd1,rc,req,b1,e1,d1);
integer quiet=0,checks=0;reg prev=0,seen_error=0;
always @(negedge clk)begin
 if(refbus.scl_clk!=prev)quiet=0;else quiet=quiet+1;
 prev=refbus.scl_clk;
 if(rst && quiet>=3)begin
 checks=checks+1;if(e1)seen_error=1;
 if({sc0,sd0,b0,e0,rd0}!=={sc1,sd1,b1,e1,rd1})$fatal(1,"Main-clock adaptation differs from reference");
 end
end
task transaction;begin
 req=1;wait(b0&&b1);req=0;wait(!b0&&!b1);repeat(100)@(negedge clk);
end endtask
initial begin
 rst=0;repeat(100)@(negedge clk);rst=1;repeat(100)@(negedge clk);
 transaction();if(!seen_error)$fatal(1,"Missing NACK diagnostic");
 ack=1;wc=5;wd=40'h12595900d0;transaction();if(e1)$fatal(1,"Write ACK rejected");
 wc=2;rc=16;wd=40'h00000000d0;transaction();if(e1||rd1!==0)$fatal(1,"Readback mismatch");
 if(checks<1000)$fatal(1,"Insufficient bus checks");
 $display("PASS i2c_enable_tb: NACK/write/read waveforms match vendor reference, %0d checks",checks);$finish;
end
initial begin #20000000;$fatal(1,"Timeout");end
endmodule
