`timescale 1ns/1ps
module axis_buffer_tb;
reg clk=0,rst_n=0,iv=0,iu=0,il=0,ready=0;reg [23:0] data=0;
wire ov,ou,ol,overflow;wire [23:0] od;wire [5:0] count;
axis_stream_buffer dut(clk,rst_n,iv,iu,il,data,ready,ov,ou,ol,od,overflow,count);
reg [25:0] expected [0:8191];reg [25:0] held;reg was_stalled=0;
integer wr=0,rd=0,i,accepted=0;reg allow_overflow=0,drop_ref=0;
always #20 clk=~clk;
always @(posedge clk)begin
 if(!rst_n)begin wr=0;rd=0;was_stalled=0;drop_ref=0;end
 else begin
  if(was_stalled && {ou,ol,od}!==held)$fatal(1,"Payload/markers changed while VALID was stalled");
  if(ov && ready)begin
   if(rd>=wr || {ou,ol,od}!==expected[rd])$fatal(1,"AXIS ordering/marker failure at %0d",rd);
   rd=rd+1;accepted=accepted+1;
  end
  if(iv && (count<32 || (ov&&ready)) && (!drop_ref || iu))begin
   if(iu)drop_ref=0;expected[wr]={iu,il,data};wr=wr+1;end
  if(iv && count==32 && !(ov&&ready))drop_ref=1;
  was_stalled=ov&&!ready;held={ou,ol,od};
  if(overflow && !allow_overflow)$fatal(1,"Unexpected overflow");
 end
end
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
initial begin
 cycles(3);rst_n=1;
 for(i=0;i<2048;i=i+1)begin
  @(negedge clk);iv=(i%80)<64;data=i;iu=(i%320)==0;il=(i%80)==63;
  ready=(i%80)!=10 && (i%80)!=11 && (i%80)!=12 && (i%80)!=13;
 end
 @(negedge clk);iv=0;ready=1;cycles(40);
 if(rd!=wr || count!=0)$fatal(1,"Drain lost words");
 allow_overflow=1;ready=0;
 for(i=0;i<32;i=i+1)begin iv=1;data=24'h100000+i;iu=(i==0);il=(i==35);cycles(1);end
 // Exercise full simultaneous pop/push before inducing a dropped frame.
 ready=1;data=24'h123456;iu=0;cycles(1);
 ready=0;data=24'habcdef;cycles(1);
 if(!overflow || count!=32)$fatal(1,"Overflow did not latch");
 ready=1;iv=0;cycles(40);
 if(rd!=wr || count!=0)$fatal(1,"Drain failure");
 iv=1;iu=0;data=24'hdead00;cycles(3);iv=0;cycles(2);
 if(ov || count!=0)$fatal(1,"Accepted tail of damaged frame");
 iv=1;iu=1;il=0;data=24'h555555;cycles(1);iu=0;il=1;data=24'haaaaaa;cycles(1);iv=0;cycles(4);
 if(rd!=wr || count!=0 || !overflow)$fatal(1,"Next-SOF recovery/diagnostic failure");
 rst_n=0;cycles(2);if(overflow || ov || count!=0)$fatal(1,"Reset did not clear FIFO/fault");
 $display("PASS AXIS_BUFFER: ordering/SOF/EOL, stable stalled payload, bounded pauses, full pop/push, sticky overflow, discard-to-next-SOF recovery and reset; %0d accepted",accepted);$finish;
end
endmodule
