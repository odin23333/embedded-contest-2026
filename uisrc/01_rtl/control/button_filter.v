`timescale 1ns/1ps
// Two-flop synchronizer + stable-level debounce. A held key emits one pulse.
module button_filter #(parameter integer STABLE_CYCLES = 1000000)(
    input wire clk, input wire rst_n, input wire key_n,
    output reg pressed, output reg press_pulse
);
localparam integer CW = (STABLE_CYCLES <= 1) ? 1 : $clog2(STABLE_CYCLES);
reg sync1, sync2;
reg [CW-1:0] count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin sync1 <= 1; sync2 <= 1; end
    else begin sync1 <= key_n; sync2 <= sync1; end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin pressed <= 0; press_pulse <= 0; count <= 0; end
    else begin
        press_pulse <= 0;
        if ((!sync2) == pressed) count <= 0;
        else if (count == STABLE_CYCLES-1) begin
            pressed <= !sync2;
            press_pulse <= !sync2;
            count <= 0;
        end else count <= count + 1'b1;
    end
end
endmodule
