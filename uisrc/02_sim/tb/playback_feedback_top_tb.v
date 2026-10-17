`timescale 1ns/1ps
// Reuse explicit peripheral models, while testing the real top's OSD wiring.
`include "system_response_tb.v"
module playback_feedback_top_tb;
reg clk=0;always #20 clk=~clk;
reg fb_vs=1;
top dut(.clk(clk),.key_col(4'hf),.sd_miso(1'b1),.UART_RX(1'b1));
task tick;begin @(posedge clk);#1;end endtask
task frame;begin @(negedge clk);fb_vs=1;repeat(3)tick;@(negedge clk);fb_vs=0;repeat(3)tick;end endtask
initial begin
 wait(dut.rst_n);repeat(20)tick;
 force dut.osd_vs=fb_vs;force dut.osd_de=0;
 force dut.playback_info={1'b0,1'b1,1'b1,3'd4,2'd3,2'd2};
 force dut.display_valid=1;force dut.auto_enabled=1;force dut.has_multiple=1;
 force dut.scheduler.idle_count=50000000;
 repeat(10)tick;frame;
 if(!dut.feedback.show || dut.feedback.info[6:4]!=4 || dut.feedback.info[1:0]!=2 || dut.feedback.seconds_left!=3 || !dut.feedback.frame_auto)$fatal(1,"Metadata/countdown/top wiring");
 force dut.error_code=8'h46;repeat(10)tick;frame;
 if(dut.feedback.show)$fatal(1,"Footer obscures non-storage diagnostic");
 force dut.error_code=0;force dut.retrying=1;repeat(10)tick;frame;
 if(dut.feedback.show)$fatal(1,"Footer visible during retry");
 force dut.retrying=0;force dut.emergency=1;repeat(10)tick;frame;
 if(dut.feedback.show)$fatal(1,"Footer visible during emergency");
 force dut.emergency=0;force dut.auto_enabled=0;repeat(10)tick;frame;
 if(!dut.feedback.show || dut.feedback.frame_auto)$fatal(1,"Footer did not return to manual");
 $display("PASS PLAYBACK_FEEDBACK_TOP: actual top metadata/real timer/CDC, diagnostic/retry/alarm priority, manual restore");$finish;
end
initial begin #15000000;$fatal(1,"Feedback top timeout");end
endmodule
