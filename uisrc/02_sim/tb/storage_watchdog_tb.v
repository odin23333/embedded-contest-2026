`timescale 1ns/1ps
module storage_watchdog_tb;
reg clk=0,rst_n=0,active=0,progress=0,ddr_ready=1,hard_error=0;wire fault;
storage_watchdog #(.TIMEOUT_CYCLES(8)) dut(clk,rst_n,active,progress,ddr_ready,hard_error,fault);
wire trusted,lost;
memory_health health(clk,rst_n,ddr_ready,trusted,lost);
always #20 clk=~clk;
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task reset;begin rst_n=0;cycles(2);rst_n=1;end endtask
integer i;
initial begin
 reset;cycles(20);if(fault)$fatal(1,"Inactive storage faulted");
 active=1;
 for(i=0;i<30;i=i+1)begin progress=0;cycles(5);progress=1;cycles(1);if(fault)$fatal(1,"Live progress faulted");end
 progress=0;cycles(7);if(fault)$fatal(1,"Timeout early");cycles(1);if(!fault)$fatal(1,"Timeout missing");
 progress=1;cycles(10);if(!fault)$fatal(1,"Fault was not sticky");
 reset;active=0;ddr_ready=0;cycles(8);if(!fault)$fatal(1,"Missing DDR was masked");
 reset;ddr_ready=1;hard_error=1;cycles(1);if(!fault)$fatal(1,"Parse error did not fault");
 hard_error=0;reset;cycles(10);if(fault)$fatal(1,"Reset/recovery failed");
 ddr_ready=1;reset;cycles(2);if(!trusted || lost)$fatal(1,"Initial memory ready failed");
 ddr_ready=0;cycles(2);if(trusted || !lost)$fatal(1,"Memory loss not latched");
 ddr_ready=1;cycles(2);if(trusted || !lost)$fatal(1,"Old memory contents trusted after loss");
 reset;cycles(2);if(!trusted || lost)$fatal(1,"Memory reset recovery failed");
 $display("PASS STORAGE_WATCHDOG: exact timeout, byte progress, inactive idle, missing DDR, parse error, sticky fault, DDR-content trust loss and reset");$finish;
end
endmodule
