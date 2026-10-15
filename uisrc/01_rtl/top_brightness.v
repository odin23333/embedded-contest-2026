module top_brightness(input clk,input [3:0] key_col,output [3:0] key_row,output [7:0] led,
output HDMI_CLK_P,HDMI_D2_P,HDMI_D1_P,HDMI_D0_P,HDMI_DDC_SCL,inout HDMI_DDC_SDA,
output sd_ncs,sd_dclk,sd_mosi,input sd_miso,input UART_RX,output UART_TX,RTC_SCL,inout RTC_SDA);
top #(.ENABLE_BRIGHTNESS(1)) player(
.clk(clk),
.key_col(key_col),
.key_row(key_row),
.led(led),
.HDMI_CLK_P(HDMI_CLK_P),
.HDMI_D2_P(HDMI_D2_P),
.HDMI_D1_P(HDMI_D1_P),
.HDMI_D0_P(HDMI_D0_P),
.HDMI_DDC_SCL(HDMI_DDC_SCL),
.HDMI_DDC_SDA(HDMI_DDC_SDA),
.sd_ncs(sd_ncs),
.sd_dclk(sd_dclk),
.sd_mosi(sd_mosi),
.sd_miso(sd_miso),.UART_RX(UART_RX),.UART_TX(UART_TX),.RTC_SCL(RTC_SCL),.RTC_SDA(RTC_SDA));
endmodule
