module top (
    input wire clk, input wire rst_n, input wire key_note,
    output wire i2s_bclk, output wire i2s_lrck,
    output wire i2s_din, output wire pa_en
);

    reg [3:0] div_count;
    reg audio_clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin div_count <= 0; audio_clk <= 0; end
        else if (div_count == 15) begin div_count <= 0; audio_clk <= ~audio_clk; end
        else div_count <= div_count + 1'b1;
    end

    wire sample_req;
    reg [31:0] phase;
    reg [15:0] sample_data;
    reg channel;
    reg key_meta, key_sync;
    reg [14:0] envelope;
    // PA_EN is active-low. Mute the analog amplifier after the release
    // envelope reaches zero to remove idle headphone hiss.
    assign pa_en = (key_sync && envelope == 0) ? 1'b1 : 1'b0;
    // Official demo target: approximately 400 Hz.
    wire [31:0] next_phase = phase + 32'd35184372;
    always @(posedge audio_clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0; sample_data <= 0; channel <= 0;
            key_meta <= 1; key_sync <= 1; envelope <= 0;
        end
        else if (sample_req) begin
            key_meta <= key_note;
            key_sync <= key_meta;
            channel <= ~channel;
            if (channel) begin
                phase <= next_phase;
                if (!key_sync && envelope < 15'h0400)
                    envelope <= envelope + 15'd8;
                else if (key_sync && envelope > 15'd7)
                    envelope <= envelope - 15'd8;
                else if (key_sync)
                    envelope <= 0;
                sample_data <= next_phase[31] ? (~{1'b0,envelope} + 1'b1)
                                              :  {1'b0,envelope};
            end
        end
    end

    audio_drive u_audio_drive(audio_clk, rst_n, sample_data, sample_req,
                              i2s_bclk, i2s_lrck, i2s_din);
endmodule

module audio_drive(
    input wire clk_audio, input wire rst_n, input wire [15:0] idata,
    output wire req, output wire hp_bck, output wire hp_ws, output wire hp_din
);
    reg [4:0] b_cnt;
    reg req_r, req_r1;
    reg [15:0] idata_r;
    reg hp_ws_r, hp_din_r;
    assign hp_bck=clk_audio; assign hp_ws=hp_ws_r; assign hp_din=hp_din_r; assign req=req_r;

    always @(posedge clk_audio or negedge rst_n)
        if(!rst_n) b_cnt<=0; else b_cnt<=b_cnt+1'b1;
    always @(posedge clk_audio or negedge rst_n)
        if(!rst_n) req_r<=0; else req_r<=(b_cnt==0)||(b_cnt==16);
    always @(posedge clk_audio or negedge rst_n) begin
        if(!rst_n) begin req_r1<=0; idata_r<=0; end
        else begin req_r1<=req_r; idata_r<=req_r1?idata:idata_r<<1; end
    end
    always @(posedge clk_audio or negedge rst_n)
        if(!rst_n) hp_din_r<=0; else hp_din_r<=idata_r[15];
    always @(posedge clk_audio or negedge rst_n)
        if(!rst_n) hp_ws_r<=0;
        else hp_ws_r<=(b_cnt==3)?1'b0:((b_cnt==19)?1'b1:hp_ws_r);
endmodule
