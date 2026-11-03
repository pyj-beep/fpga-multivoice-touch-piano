module audio_drive(
    input wire clk_audio,input wire rst_n,input wire [15:0] idata,
    output wire req,output wire hp_bck,output wire hp_ws,output wire hp_din
);
    reg [4:0] b_cnt; reg req_r,req_r1; reg [15:0] idata_r; reg hp_ws_r,hp_din_r;
    assign hp_bck=clk_audio; assign hp_ws=hp_ws_r; assign hp_din=hp_din_r; assign req=req_r;
    always @(posedge clk_audio or negedge rst_n) if(!rst_n)b_cnt<=0;else b_cnt<=b_cnt+1'b1;
    always @(posedge clk_audio or negedge rst_n) if(!rst_n)req_r<=0;else req_r<=(b_cnt==0)||(b_cnt==16);
    always @(posedge clk_audio or negedge rst_n) begin
        if(!rst_n)begin req_r1<=0;idata_r<=0;end
        else begin req_r1<=req_r;idata_r<=req_r1?idata:idata_r<<1;end
    end
    always @(posedge clk_audio or negedge rst_n) if(!rst_n)hp_din_r<=0;else hp_din_r<=idata_r[15];
    always @(posedge clk_audio or negedge rst_n)
        if(!rst_n)hp_ws_r<=0;else hp_ws_r<=(b_cnt==3)?0:((b_cnt==19)?1:hp_ws_r);
endmodule
