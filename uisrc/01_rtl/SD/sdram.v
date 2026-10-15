module sdram(input Clk,Clk_sft,Clk90,Rst,output Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,
 input App_wr_en,input [20:0] App_wr_addr,input [3:0] App_wr_dm,input [31:0] App_wr_din,
 input App_rd_en,input [20:0] App_rd_addr,output Sdr_rd_en,output [31:0] Sdr_rd_dout);
wire clk0=Clk,clk90=Clk90,clk180=Clk_sft;
wire sdr_init_done,sdr_init_ref_vld,sdr_busy,sdr_rd_en;
wire [31:0] sdr_rd_dout;
wire app_wr_en=App_wr_en,app_rd_en=App_rd_en;
wire [22:0] app_wr_addr={1'b0,App_wr_addr,1'b0},app_rd_addr={1'b0,App_rd_addr,1'b0};
wire [1:0] app_wr_dm={App_wr_dm[3]|App_wr_dm[2],App_wr_dm[1]|App_wr_dm[0]};
wire [31:0] app_wr_din=App_wr_din;
wire CLK,CLKN,CKE,CS_N,RAS_N,CAS_N,WE_N;
wire [1:0] BA,DM,DQS;wire [11:0] ADDR;wire [15:0] DQ;
assign Sdr_init_done=sdr_init_done;assign Sdr_init_ref_vld=sdr_init_ref_vld;
assign Sdr_busy=sdr_busy;assign Sdr_rd_en=sdr_rd_en;assign Sdr_rd_dout=sdr_rd_dout;
// Periodic refresh request held until controller enters refresh, not a single lost pulse.
reg [9:0] refresh_count;reg refresh_request;
always @(posedge Clk)begin
 if(Rst || !sdr_init_done)begin refresh_count<=0;refresh_request<=0;end
 else if(sdr_init_ref_vld)begin refresh_count<=0;refresh_request<=0;end
 else if(refresh_count==1023)refresh_request<=1;
 else if(!refresh_request)refresh_count<=refresh_count+1'b1;
end
ddr1_as_ram#
( 
.self_refresh_open(1'b0)
)
u_ddr_ctrl
( 
 .Clk0            (clk0            )
,.Clk90           (clk90           )
,.Clk180          (clk180          )
,.Rst             (Rst             )
,.Sdr_init_done   (sdr_init_done   )
,.Sdr_init_ref_vld(sdr_init_ref_vld)
,.Sdr_busy        (sdr_busy        )
,.App_ref_req     (refresh_request )
,.App_wr_en       (app_wr_en       ) 
,.App_wr_addr     (app_wr_addr     )
,.App_wr_dm       (app_wr_dm       )
,.App_wr_din      (app_wr_din      )
,.App_rd_en       (app_rd_en       )
,.App_rd_addr     (app_rd_addr     )
,.Sdr_rd_en	      (sdr_rd_en       )
,.Sdr_rd_dout     (sdr_rd_dout     )
,.CLK             (CLK             )
,.CLKN            (CLKN            )
,.CKE             (CKE             )
,.CS_N            (CS_N            )
,.RAS_N           (RAS_N           )
,.CAS_N           (CAS_N           )
,.WE_N            (WE_N            )
,.BA              (BA              )
,.ADDR            (ADDR            )
,.DM              (DM              )
,.DQ              (DQ              )
,.DQS             (DQS             )
);


EG_PHY_DDR_8M_16 u_ddr_sdram(
	.clk             (CLK             ),
	.clk_n           (CLKN            ),
	.ras_n           (RAS_N           ),
	.cas_n           (CAS_N           ),
	.we_n            (WE_N            ),
	.cs_n            (CS_N            ),
	.addr            (ADDR            ),
	.ba              (BA              ),
	.dq              (DQ              ),
	.ldqs            (DQS[0]          ),
	.udqs            (DQS[1]          ),
	.ldm             (DM[0]           ),
	.udm             (DM[1]           ),
	.cke             (CKE             )
);



endmodule
