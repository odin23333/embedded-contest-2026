`timescale 1ns/1ps
module buffer_retirement_tb;
reg clk=0,rst=1,req=0;always #5 clk=~clk;
reg[1:0] page=0;wire en,ack,busy,done,retired;wire[20:0] addr;
reg[16:0] pipe=0;integer sent=0,received=0;reg switch_test=0;
always @(posedge clk)begin
 if(rst)pipe<=0;else pipe<={pipe[15:0],en};
 if(!rst)begin
  if(en)sent=sent+1;
  if(pipe[16])received=received+1;
  if(switch_test && received<8 && (ack || retired))$fatal(1,"Old DDR returns not drained before retirement");
 end
end
frame_fifo_read #(.BURST_SIZE(8)) read_frame(.rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.Sdr_rd_en(pipe[16]),.App_wr_busy(1'b0),.O_rd_busy(busy),
 .App_rd_en(en),.App_rd_addr(addr),.read_req(req),.read_req_ack(ack),.read_finish(done),.read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(page),.read_len(21'd16),.fifo_aclr(),.wrusedw(10'd0));
buffer_retirement guard(clk,rst,ack,addr,clk,~rst,page,retired);
initial begin
 repeat(5)@(negedge clk);rst=0;
 if(retired)$fatal(1,"Retired without any reader ACK");
 req=1;wait(ack);@(negedge clk);req=0;wait(retired);wait(sent==4);
 @(negedge clk);page=1;req=1;switch_test=1;
 repeat(3)@(negedge clk);if(retired)$fatal(1,"Still reports old page reusable");
 wait(ack);if(received<8)$fatal(1,"New frame acknowledged before old returns");
 @(negedge clk);req=0;wait(retired);if(addr<307200)$fatal(1,"Sampled old address tail at ACK edge");
 wait(done);if(received!=sent)$fatal(1,"Missing returns");
 rst=1;repeat(3)@(negedge clk);if(retired)$fatal(1,"Reset retains retirement");
 $display("PASS BUFFER_RETIREMENT: real DDR reader delayed returns, request during old burst, accepted new page only, reset");$finish;
end
initial begin #100000;$fatal(1,"Timeout");end
endmodule
