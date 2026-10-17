`timescale 1ns/1ps
module quality_fifo_tb;
reg wc=0,mc=0,rst=1,req=0,send=0,we=0,mem_busy=0;always #20 wc=~wc;always #5 mc=~mc;
wire ack,done,space,wen;wire[20:0] wa;wire[31:0] wd;wire[3:0] mask;
integer produced=0,accepted=0,written=0,round=0;
reg[31:0] data=0;
frame_read_write #(.BURST_SIZE(128),.WRITE_V_FLIP(0)) dut(
 .rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(mem_busy),
 .App_rd_en(),.App_rd_addr(),.Sdr_rd_en(1'b0),.Sdr_rd_dout(32'd0),
 .read_clk(wc),.read_req(1'b0),.read_req_ack(),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(21'd512),.read_en(1'b0),.read_data(),
 .App_wr_en(wen),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(mask),
 .write_clk(wc),.write_req(req),.write_req_ack(ack),.write_finish(done),.write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd512),.write_en(we),.write_data(data),.write_ready(space));
always @(posedge wc)begin
 if(!rst)begin
  if(we && dut.write_buf.wr_en_s && !dut.write_buf.wr_rst)accepted=accepted+1;
  we<=0;
  if(send && space && produced<512)begin data<=32'h40000000+round*1024+produced;we<=1;produced=produced+1;end
 end
end
always @(posedge mc)if(!rst && wen)begin
 if(wd!==(32'h40000000+round*1024+written))$fatal(1,"FIFO data order round=%0d word=%0d got=%h",round,written,wd);
 written=written+1;
end
initial begin
 for(round=0;round<8;round=round+1)begin
  rst=1;req=0;send=0;we=0;mem_busy=(round==0);
  repeat(5)@(negedge wc);#(round+1);produced=0;accepted=0;written=0;rst=0;
  @(posedge wc);#1;req=1;wait(ack);@(posedge wc);#1;req=0;send=1;
  if(round==0)begin
   wait(!space && produced>128);repeat(12)@(negedge wc);
   if(produced>390 || accepted>390)$fatal(1,"Registered ready overruns watermark headroom produced=%0d accepted=%0d",produced,accepted);
   mem_busy=0;
  end
  wait(produced==512);wait(done);repeat(10)@(negedge wc);send=0;
  if(accepted!=512 || written!=512)$fatal(1,"FIFO release loss round=%0d produced=%0d accepted=%0d written=%0d",round,produced,accepted,written);
 end
 $display("PASS QUALITY_FIFO: 8 reset phases and stalled-DDR watermark/backpressure, actual vendor FIFO, all4096 ordered words, fastest producer after ACK");$finish;
end
initial begin #1000000;$fatal(1,"Timeout");end
endmodule
