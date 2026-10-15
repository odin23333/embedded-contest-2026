`timescale 1ns/1ps
module time_uart_tb;
reg clk=0,rst_n=0,rx=1,reply=0,ok=1;wire tx,pulse;wire[23:0] timecode;integer sets=0,i;reg[7:0]reply_data;
always #5 clk=~clk;
time_uart #(.DIV(8)) dut(clk,rst_n,rx,reply,ok,tx,pulse,timecode);
always @(posedge clk)if(pulse)sets=sets+1;
task send;input[7:0]a;integer b;begin
 @(negedge clk);rx=0;repeat(8)@(negedge clk);
 for(b=0;b<8;b=b+1)begin rx=a[b];repeat(8)@(negedge clk);end
 rx=1;repeat(12)@(negedge clk);
end endtask
initial begin
 repeat(5)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);
 send(8'ha5);send(8'h23);send(8'h59);send(8'h58);send(8'ha5^8'h23^8'h59^8'h58);repeat(5)@(negedge clk);
 if(sets!=1 || timecode!=24'h235958)$fatal(1,"Valid serial calibration rejected");
 send(8'ha5);send(8'h24);send(8'h00);send(8'h00);send(8'ha5^8'h24);repeat(5)@(negedge clk);
 if(sets!=1)$fatal(1,"Invalid24h value accepted");
 send(8'ha5);send(8'h12);send(8'h34);send(8'h56);send(8'h00);repeat(5)@(negedge clk);
 if(sets!=1)$fatal(1,"Bad checksum accepted");
 @(negedge clk);reply=1;@(negedge clk);reply=0;
 repeat(11)@(negedge clk);
 for(i=0;i<8;i=i+1)begin reply_data[i]=tx;repeat(8)@(negedge clk);end
 if(reply_data!=8'h4b)$fatal(1,"Serial reply decode failed: %h",reply_data);
 $display("PASS TIME_UART: real115200-style bit framing, valid BCD/checksum calibration, reject invalid hour/checksum, success reply");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
