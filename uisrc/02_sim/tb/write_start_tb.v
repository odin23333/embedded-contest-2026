`timescale 1ns/1ps
module write_start_tb;
reg wc=0,mc=0,rst=1,req=0,send=0,we=0;always #20 wc=~wc;always #5 mc=~mc;
wire ack,done,space,wen;wire[20:0] wa;wire[31:0] wd;wire[3:0] mask;
integer produced=0,accepted=0,written=0;
reg[31:0] data=0;
frame_read_write #(.BURST_SIZE(128),.WRITE_V_FLIP(0)) dut(
 .rst(rst),.mem_clk(mc),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_en(),.App_rd_addr(),.Sdr_rd_en(1'b0),.Sdr_rd_dout(32'd0),
 .read_clk(wc),.read_req(1'b0),.read_req_ack(),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(21'd512),.read_en(1'b0),.read_data(),
 .App_wr_en(wen),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(mask),
 .write_clk(wc),.write_req(req),.write_req_ack(ack),.write_finish(done),.write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd512),.write_en(we),.write_data(data),.write_ready(space));
always @(posedge wc)begin
 if(!rst)begin
  if(we && dut.write_buf.wr_en_s && !dut.write_buf.wr_rst)accepted=accepted+1;
  we<=0;
  if(send && space && produced<512)begin data<=produced;we<=1;produced=produced+1;end
 end
end
always @(posedge mc)if(!rst && wen)written=written+1;
initial begin
 repeat(5)@(negedge wc);rst=0;req=1;wait(ack);@(negedge wc);req=0;send=1;
 wait(produced==512);repeat(100)@(negedge wc);
 if(accepted!=512 || written!=512)$fatal(1,"FIFO reset release loses initial pixels: produced=%0d accepted=%0d written=%0d",produced,accepted,written);
 $display("PASS WRITE_START: actual vendor FIFO synchronous reset release, fast black-bar producer, all512 words accepted and DDR bursts complete");$finish;
end
initial begin #1000000;$fatal(1,"Timeout");end
endmodule
