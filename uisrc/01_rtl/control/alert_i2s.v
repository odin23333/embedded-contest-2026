`timescale 1ns/1ps
// Reference-compatible serial slots: 64 BCLKs/channel, 128/stereo frame.
// MCLK/2 is BCLK, MCLK/256 is sample rate. LRCK changes one bit before MSB.
module alert_i2s #(parameter integer HALF_BEEP_FRAMES=12000,
 parameter [31:0] PHASE_INC=32'd89478485,
 parameter signed [23:0] AMPLITUDE=24'sd500000)(
 input wire mclk,rst_n,emergency,muted,
 output reg bclk,lrck,dout,
 output reg flash_on // shared envelope; mute silences audio without disabling visual warning
);
reg [5:0] bit_count;
reg [63:0] shift;
reg [23:0] sample;
reg [31:0] phase;
localparam CW=(HALF_BEEP_FRAMES<=1)?1:$clog2(HALF_BEEP_FRAMES);
reg [CW-1:0] beep_count;
reg silent_half;
wire [23:0] next_sample=(!emergency || muted || silent_half)?24'd0:
                        (phase[31] ? -AMPLITUDE : AMPLITUDE);
always @(posedge mclk or negedge rst_n)begin
 if(!rst_n)begin bclk<=0;lrck<=0;dout<=0;bit_count<=0;shift<=0;sample<=0;
  phase<=0;beep_count<=0;silent_half<=0;flash_on<=0;end
 else begin
  bclk<=~bclk;
  if(bclk)begin
   dout<=shift[63];shift<={shift[62:0],1'b0};
   if(bit_count==63)begin
    bit_count<=0;lrck<=~lrck;
    if(!lrck)shift<={sample,40'd0};
    else begin
     flash_on<=emergency && !silent_half;
     sample<=next_sample;shift<={next_sample,40'd0};
     if(!emergency)begin phase<=0;beep_count<=0;silent_half<=0;end
     else begin
      phase<=phase+PHASE_INC;
      if(beep_count==HALF_BEEP_FRAMES-1)begin beep_count<=0;silent_half<=~silent_half;end
      else beep_count<=beep_count+1'b1;
     end
    end
   end else bit_count<=bit_count+1'b1;
  end
 end
end
endmodule
