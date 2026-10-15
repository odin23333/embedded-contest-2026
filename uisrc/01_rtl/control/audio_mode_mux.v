module audio_mode_mux(input mclk,rst_n,input [1:0] status,input normal_data,alarm_data,output dout);
reg [1:0] sample_status;reg [7:0] frame_count;
always @(posedge mclk or negedge rst_n)
 if(!rst_n)begin sample_status<=0;frame_count<=0;end
 else begin frame_count<=frame_count+1'b1;if(frame_count==255)sample_status<=status;end
assign dout=sample_status[1]?1'b0:(sample_status[0]?alarm_data:normal_data);
endmodule
