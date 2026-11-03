module top(
    input wire clk,input wire key_c,input wire key_e,input wire key_g,
    input wire [37:0] j13_probe,
    output wire i2s_bclk,output wire i2s_lrck,output wire i2s_din,
    output wire pa_en,output wire WS2812
);
    reg [15:0] por_count=0; wire rst_n=&por_count;
    always @(posedge clk) if(!rst_n) por_count<=por_count+1'b1;
    reg [3:0] div_count; reg audio_clk;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)begin div_count<=0;audio_clk<=0;end
        else if(div_count==15)begin div_count<=0;audio_clk<=~audio_clk;end
        else div_count<=div_count+1'b1;

    reg [2:0] key_meta,key_sync;
    always @(posedge audio_clk or negedge rst_n)
        if(!rst_n)begin key_meta<=3'b111;key_sync<=3'b111;end
        else begin key_meta<={key_g,key_e,key_c};key_sync<=key_meta;end

    wire sample_req; reg channel; wire frame_tick=sample_req&&channel;
    reg [3:0] env_div; wire env_tick=frame_tick&&(env_div==15);
    always @(posedge audio_clk or negedge rst_n)
        if(!rst_n)begin channel<=0;env_div<=0;end
        else begin if(sample_req)channel<=~channel;if(frame_tick)env_div<=env_div+1'b1;end

    wire timbre,suppress_notes,dock_chord_mode;
    button_timbre_control control(audio_clk,rst_n,frame_tick,key_sync,
                                  timbre,suppress_notes,dock_chord_mode);
    wire g0=!key_sync[0]&&!suppress_notes;
    wire g1=!key_sync[1]&&!suppress_notes;
    wire g2=!key_sync[2]&&!suppress_notes;
    wire g3=!(|key_sync)&&!suppress_notes;
    wire screen_gate; wire [31:0] screen_phase_inc;
    wire [4:0] screen_note; wire [1:0] screen_mode;
    // J13 pin 2 is j13_probe[1] (SDRAM0_D1 / package ball E13).
    screen_uart_note screen_notes(clk,rst_n,j13_probe[1],
                                  screen_gate,screen_phase_inc,screen_note,screen_mode);
    wire signed [15:0] v0,v1,v2,v3,vs,vst,vsf;
    wire a0,a1,a2,a3,as,ast,asf;
    wire signed [15:0] h0,h1,h2; wire ah0,ah1,ah2;
    synth_voice_dual u0(audio_clk,rst_n,frame_tick,env_tick,g0,timbre,32'd19351405,v0,a0);
    synth_voice_dual u1(audio_clk,rst_n,frame_tick,env_tick,g1,timbre,32'd28994350,v1,a1);
    synth_voice_dual u2(audio_clk,rst_n,frame_tick,env_tick,g2,timbre,32'd38702809,v2,a2);
    synth_voice_dual u3(audio_clk,rst_n,frame_tick,env_tick,g3,timbre,32'd57988699,v3,a3);
    synth_voice_dual uscreen(audio_clk,rst_n,frame_tick,env_tick,screen_gate,timbre,screen_phase_inc,vs,as);
    // The major chord uses an open, high third.  The minor chord keeps its
    // third close to the root so the two modes have clearly different colour.
    wire [49:0] screen_major_mult = screen_phase_inc * 18'd165140;
    wire [49:0] screen_minor_mult = screen_phase_inc * 18'd77936;
    wire [48:0] screen_fifth_mult = screen_phase_inc * 17'd98193;
    wire [31:0] screen_major_phase = screen_major_mult >> 16;
    wire [31:0] screen_minor_phase = screen_minor_mult >> 16;
    wire [31:0] screen_third_phase =
        (screen_mode == 2'd2) ? screen_minor_phase : screen_major_phase;
    wire [31:0] screen_fifth_phase = screen_fifth_mult >> 16;
    synth_voice_dual uscreen_third(audio_clk,rst_n,frame_tick,env_tick,
                                  screen_gate & ((screen_mode == 2'd1) |
                                                 (screen_mode == 2'd2)),
                                  1'b0,
                                  screen_third_phase,vst,ast);
    synth_voice_dual uscreen_fifth(audio_clk,rst_n,frame_tick,env_tick,
                                  screen_gate & (screen_mode != 2'd0),1'b0,
                                  screen_fifth_phase,vsf,asf);
    // Quiet perfect-fifth harmony for each playable key (3/2 frequency).
    synth_voice_dual harm0(audio_clk,rst_n,frame_tick,env_tick,g0,timbre,32'd29027108,h0,ah0);
    synth_voice_dual harm1(audio_clk,rst_n,frame_tick,env_tick,g1,timbre,32'd43491525,h1,ah1);
    synth_voice_dual harm2(audio_clk,rst_n,frame_tick,env_tick,g2,timbre,32'd58054214,h2,ah2);
    wire signed [18:0] screen_root = {{3{vs[15]}},vs};
    wire signed [18:0] screen_third = {{3{vst[15]}},vst};
    wire signed [18:0] screen_fifth = {{3{vsf[15]}},vsf};
    wire signed [18:0] screen_mix =
        (screen_mode == 2'd0) ? screen_root :
        (screen_mode == 2'd3) ?
            ((screen_root >>> 1) + (screen_root >>> 3) +
             (screen_fifth >>> 2)) :
        (screen_mode == 2'd1) ?
            // Major: bright open voicing, with a prominent high major third.
            ((screen_root >>> 2) + (screen_root >>> 3) +
             (screen_third >>> 2) + (screen_third >>> 3) +
             (screen_fifth >>> 2)) :
            // Minor: close minor third and a root-heavy, darker balance.
            ((screen_root >>> 1) + (screen_root >>> 3) +
             (screen_third >>> 2) +
             (screen_fifth >>> 3));
    wire signed [18:0] mix={{3{v0[15]}},v0}+{{3{v1[15]}},v1}+
                           {{3{v2[15]}},v2}+{{3{v3[15]}},v3}+
                           screen_mix+
                           ({{3{h0[15]}},h0}>>>1)+
                           ({{3{h1[15]}},h1}>>>1)+
                           ({{3{h2[15]}},h2}>>>1);
    wire signed [19:0] mix_ext = {{1{mix[18]}},mix};
    wire signed [19:0] master_mix = mix_ext + (mix_ext >>> 1);
    wire any_active = a0|a1|a2|a3|as|ast|asf|ah0|ah1|ah2;
    reg signed [19:0] previous_mix;
    wire signed [20:0] smooth_sum =
        {{1{master_mix[19]}},master_mix} +
        {{1{previous_mix[19]}},previous_mix};
    wire signed [20:0] smooth_mix = smooth_sum >>> 1;
    reg signed [20:0] previous_smooth;
    wire signed [21:0] filtered_sum =
        {{1{smooth_mix[20]}},smooth_mix} +
        {{1{previous_smooth[20]}},previous_smooth};
    wire signed [21:0] filtered_mix = filtered_sum >>> 1;
    reg [15:0] sample_data;
    always @(posedge audio_clk or negedge rst_n)
        if(!rst_n) begin
            sample_data<=0; previous_mix<=0; previous_smooth<=0;
        end
        else if(frame_tick) begin
            if(!any_active) begin
                sample_data<=0;
                previous_mix<=0;
                previous_smooth<=0;
            end else begin
                previous_mix<=master_mix;
                previous_smooth<=smooth_mix;
                if(filtered_mix > 22'sd32767) sample_data<=16'h7fff;
                else if(filtered_mix < -22'sd32768) sample_data<=16'h8000;
                else sample_data<=filtered_mix[15:0];
            end
        end
    assign pa_en=any_active?1'b0:1'b1;
    audio_drive audio(audio_clk,rst_n,sample_data,sample_req,i2s_bclk,i2s_lrck,i2s_din);
    ws2812_status status(clk,rst_n,timbre,WS2812);
endmodule
