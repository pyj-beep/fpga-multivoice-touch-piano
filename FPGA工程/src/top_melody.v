module top (
    input wire clk,
    input wire key_c,
    input wire key_e,
    input wire key_g,
    output wire i2s_bclk,
    output wire i2s_lrck,
    output wire i2s_din,
    output wire pa_en
);
    // Short internal power-on reset so all three physical keys can be notes.
    reg [15:0] por_count = 16'd0;
    wire rst_n = &por_count;
    always @(posedge clk)
        if (!rst_n) por_count <= por_count + 1'b1;

    reg [3:0] div_count;
    reg audio_clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin div_count <= 0; audio_clk <= 0; end
        else if (div_count == 15) begin div_count <= 0; audio_clk <= ~audio_clk; end
        else div_count <= div_count + 1'b1;
    end

    reg [2:0] key_meta, key_sync;
    always @(posedge audio_clk or negedge rst_n) begin
        if (!rst_n) begin key_meta <= 3'b111; key_sync <= 3'b111; end
        else begin key_meta <= {key_g,key_e,key_c}; key_sync <= key_meta; end
    end
    wire gate = ~(&key_sync);
    wire [31:0] phase_inc = !key_sync[0] ? 32'd23012831 : // C4
                            !key_sync[1] ? 32'd28994350 : // E4
                            !key_sync[2] ? 32'd34480280 : // G4
                                           32'd23012831;

    wire sample_req;
    reg channel;
    reg [31:0] phase;
    reg [14:0] envelope;
    reg [15:0] sample_data;
    wire signed [15:0] sine_sample;
    wire signed [30:0] scaled_sample = sine_sample * $signed({1'b0,envelope});
    sine_rom u_sine_rom(phase[31:24], sine_sample);

    assign pa_en = (!gate && envelope == 0) ? 1'b1 : 1'b0;

    always @(posedge audio_clk or negedge rst_n) begin
        if (!rst_n) begin
            channel <= 0; phase <= 0; envelope <= 0; sample_data <= 0;
        end else if (sample_req) begin
            channel <= ~channel;
            if (channel) begin
                if (gate) begin
                    phase <= phase + phase_inc;
                    if (envelope < 15'h0400) envelope <= envelope + 15'd8;
                end else if (envelope > 15'd7) begin
                    envelope <= envelope - 15'd8;
                end else begin
                    envelope <= 0;
                end
                sample_data <= scaled_sample >>> 15;
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
