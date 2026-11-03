module top (
    input wire clk,
    input wire key_c, input wire key_e, input wire key_g,
    output wire i2s_bclk, output wire i2s_lrck,
    output wire i2s_din, output wire pa_en
);
    reg [15:0] por_count = 0;
    wire rst_n = &por_count;
    always @(posedge clk) if (!rst_n) por_count <= por_count + 1'b1;

    reg [3:0] div_count;
    reg audio_clk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin div_count<=0; audio_clk<=0; end
        else if (div_count==15) begin div_count<=0; audio_clk<=~audio_clk; end
        else div_count<=div_count+1'b1;
    end

    reg [2:0] key_meta, key_sync;
    always @(posedge audio_clk or negedge rst_n) begin
        if (!rst_n) begin key_meta<=3'b111; key_sync<=3'b111; end
        else begin key_meta<={key_g,key_e,key_c}; key_sync<=key_meta; end
    end
    wire gate_a3 = !key_sync[0];
    wire gate_e4 = !key_sync[1];
    wire gate_a4 = !key_sync[2];
    wire gate_e5 = !(|key_sync); // fourth voice when all three keys are held

    wire sample_req;
    reg channel;
    wire frame_tick = sample_req && channel;
    reg [3:0] env_div;
    wire env_tick = frame_tick && (env_div==15);
    always @(posedge audio_clk or negedge rst_n)
        if (!rst_n) begin channel<=0; env_div<=0; end
        else begin
            if (sample_req) channel<=~channel;
            if (frame_tick) env_div<=env_div+1'b1;
        end

    wire signed [15:0] voice_a3, voice_e4, voice_a4, voice_e5;
    wire active_a3, active_e4, active_a4, active_e5;
    synth_voice v0(audio_clk,rst_n,frame_tick,env_tick,gate_a3,32'd19351405,voice_a3,active_a3);
    synth_voice v1(audio_clk,rst_n,frame_tick,env_tick,gate_e4,32'd28994350,voice_e4,active_e4);
    synth_voice v2(audio_clk,rst_n,frame_tick,env_tick,gate_a4,32'd38702809,voice_a4,active_a4);
    synth_voice v3(audio_clk,rst_n,frame_tick,env_tick,gate_e5,32'd57988699,voice_e5,active_e5);

    wire signed [18:0] mix = {{3{voice_a3[15]}},voice_a3}
                           + {{3{voice_e4[15]}},voice_e4}
                           + {{3{voice_a4[15]}},voice_a4}
                           + {{3{voice_e5[15]}},voice_e5};
    reg [15:0] sample_data;
    always @(posedge audio_clk or negedge rst_n)
        if (!rst_n) sample_data<=0;
        else if (frame_tick) sample_data<=mix[15:0];

    assign pa_en = (active_a3|active_e4|active_a4|active_e5) ? 1'b0 : 1'b1;
    audio_drive u_audio_drive(audio_clk,rst_n,sample_data,sample_req,
                              i2s_bclk,i2s_lrck,i2s_din);
endmodule

module synth_voice(
    input wire clk, input wire rst_n, input wire sample_tick, input wire env_tick,
    input wire gate, input wire [31:0] phase_inc,
    output wire signed [15:0] audio, output wire active
);
    reg [31:0] phase;
    reg [7:0] env;
    reg [1:0] state;
    wire signed [15:0] sine;
    wire signed [8:0] env_signed = $signed({1'b0,env});
    wire signed [24:0] product = sine * env_signed;
    assign audio = product >>> 15;
    assign active = (env != 0) | gate;
    sine_rom rom(phase[31:24],sine);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin phase<=0; env<=0; state<=0; end
        else begin
            if (sample_tick) phase<=phase+phase_inc;
            if (env_tick) begin
                case (state)
                    0: if (gate) state<=1;
                    1: begin // Attack
                        if (!gate) state<=3;
                        else if (env>=8'd119) begin env<=8'd127; state<=2; end
                        else env<=env+8'd8;
                    end
                    2: begin // Decay then Sustain at 80/127
                        if (!gate) state<=3;
                        else if (env>8'd80) env<=env-8'd1;
                    end
                    3: begin // Release
                        if (gate) state<=1;
                        else if (env>8'd2) env<=env-8'd2;
                        else begin env<=0; state<=0; end
                    end
                endcase
            end
        end
    end
endmodule

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
