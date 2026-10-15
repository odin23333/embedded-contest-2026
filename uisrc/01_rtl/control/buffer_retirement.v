`timescale 1ns/1ps
// Release the previous display buffer only after the DDR reader has accepted
// a request for the newly displayed page and drained its preceding burst.
module buffer_retirement #(parameter ADDR_BITS=21,parameter PAGE1_BASE=307200)(
 input mem_clk,mem_rst,read_ack,input [ADDR_BITS-1:0] read_addr,
 input ctrl_clk,ctrl_rst_n,input [1:0] displayed_page,output retired);
reg ack_prev,page_valid;reg [1:0] page;wire [2:0] observed;
always @(posedge mem_clk or posedge mem_rst)begin
 if(mem_rst)begin ack_prev<=0;page_valid<=0;page<=0;end
 else begin
  ack_prev<=read_ack;
  // At the falling ACK edge the address latch is final and the next burst
  // has not issued yet. Sampling while ACK rises can capture the old tail.
  if(ack_prev && !read_ack)begin page_valid<=1;page<=(read_addr>=PAGE1_BASE)?1:0;end
 end
end
level_sync #(.WIDTH(3)) sync(ctrl_clk,ctrl_rst_n,{page_valid,page},observed);
assign retired=observed[2] && observed[1:0]==displayed_page;
endmodule
