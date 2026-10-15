`timescale 1ns/1ps
module frame_write_tb;
reg clk=0,rst=1,req=0;reg [1:0] idx=0;
wire busy,en,ack,finish,clear;wire [20:0] addr;
integer count=0,base=0,expected,frame;
always #4 clk=~clk;
frame_fifo_write #(.BURST_SIZE(256)) dut(
 .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.App_rd_busy(1'b0),
 .O_wr_busy(busy),.App_wr_en(en),.App_wr_addr(addr),.write_req(req),.write_req_ack(ack),.write_finish(finish),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .write_addr_index(idx),.write_len(21'd307200),.fifo_aclr(clear),.rdusedw(10'd512));
// Scoreboard samples the address at the same edge the memory interface accepts it.
always @(posedge clk) if(!rst && en)begin
 expected=base+(479-count/640)*640+count%640;
 if(count>=307200 || addr!==expected[20:0])$fatal(1,"Vertical flip: index=%0d addr=%0d expected=%0d",count,addr,expected);
 count=count+1;
end
initial begin
 repeat(5)@(negedge clk);rst=0;
 for(frame=0;frame<2;frame=frame+1)begin
  count=0;base=frame*307200;idx=frame;req=1;
  wait(ack);@(negedge clk);req=0;
  wait(finish);@(negedge clk);
  if(count!=307200)$fatal(1,"Frame length=%0d",count);
  repeat(5)@(negedge clk);
 end
 $display("PASS FRAME_WRITE: 614400 accepted addresses, BMP bottom-up to top-down, buffers 0/1, frame finish");$finish;
end
initial begin #10000000;$fatal(1,"Timeout");end
endmodule
