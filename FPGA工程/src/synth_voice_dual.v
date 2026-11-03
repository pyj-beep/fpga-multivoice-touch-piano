module synth_voice_dual(
    input wire clk, input wire rst_n, input wire sample_tick, input wire env_tick,
    input wire gate, input wire timbre, input wire [31:0] phase_inc,
    output wire signed [15:0] audio, output wire active
);
    reg [31:0] phase;
    reg [31:0] octave_phase;
    reg [31:0] third_phase;
    reg [7:0] env;
    reg [7:0] harmonic2_env;
    reg [7:0] harmonic3_env;
    reg [5:0] hammer_env;
    reg [1:0] state;
    reg [3:0] decay_div;
    reg gate_d;
    reg [15:0] noise_lfsr;
    wire signed [15:0] sine;
    wire signed [15:0] octave_sine;
    wire signed [15:0] third_sine;
    wire signed [15:0] bright_wave = sine;
    wire signed [8:0] env_signed = $signed({1'b0,env});
    wire signed [8:0] h2_env_signed = $signed({1'b0,harmonic2_env});
    wire signed [8:0] h3_env_signed = $signed({1'b0,harmonic3_env});
    wire signed [24:0] rock_product = bright_wave * env_signed;
    wire signed [24:0] fundamental_product = sine * env_signed;
    wire signed [24:0] harmonic2_product = octave_sine * h2_env_signed;
    wire signed [24:0] harmonic3_product = third_sine * h3_env_signed;
    wire signed [15:0] rock_audio = rock_product >>> 11;
    wire signed [15:0] fundamental_audio = fundamental_product >>> 11;
    wire signed [15:0] harmonic2_audio = harmonic2_product >>> 12;
    wire signed [15:0] harmonic3_audio = harmonic3_product >>> 13;
    // Shift-only stepped decay avoids another multiplier in every voice.
    wire signed [16:0] hammer_wave_sum =
        ({{1{octave_sine[15]}},octave_sine} >>> 1) +
        ({{1{third_sine[15]}},third_sine} >>> 1);
    wire signed [15:0] hammer_wave = hammer_wave_sum[15:0];
    wire signed [15:0] hammer_audio = hammer_env[5] ? (hammer_wave >>> 5) :
                                        hammer_env[4] ? (hammer_wave >>> 6) :
                                        hammer_env[3] ? (hammer_wave >>> 7) :
                                        hammer_env[2] ? (hammer_wave >>> 8) : 16'sd0;
    wire signed [18:0] piano_audio = {{3{fundamental_audio[15]}},fundamental_audio}+
                                     {{3{harmonic2_audio[15]}},harmonic2_audio}+
                                     {{3{harmonic3_audio[15]}},harmonic3_audio}+
                                     {{3{hammer_audio[15]}},hammer_audio};
    assign audio = timbre ? piano_audio[15:0] : rock_audio;
    assign active = (env != 0) | gate;
    sine_rom rom(phase[31:24],sine);
    sine_rom octave_rom(octave_phase[31:24],octave_sine);
    sine_rom third_rom(third_phase[31:24],third_sine);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin phase<=0; octave_phase<=0; third_phase<=0;
            env<=0; harmonic2_env<=0; harmonic3_env<=0; hammer_env<=0;
            state<=0; decay_div<=0; gate_d<=0; noise_lfsr<=16'h1ACE; end
        else begin
            gate_d<=gate;
            if(gate && !gate_d) begin
                harmonic2_env<=8'd104;
                harmonic3_env<=8'd72;
                hammer_env<=6'd63;
            end
            if (sample_tick) begin
                phase<=phase+phase_inc;
                octave_phase<=octave_phase+(phase_inc<<1);
                third_phase<=third_phase+phase_inc+(phase_inc<<1);
                noise_lfsr<={noise_lfsr[14:0],noise_lfsr[15]^noise_lfsr[13]^noise_lfsr[12]^noise_lfsr[10]};
            end
            if (env_tick) begin
                decay_div<=decay_div+1'b1;
                if(timbre) begin
                    if(hammer_env!=0) hammer_env<=hammer_env-1'b1;
                    if(gate) begin
                        if(harmonic2_env!=0 && decay_div[2:0]==0)
                            harmonic2_env<=harmonic2_env-1'b1;
                        if(harmonic3_env!=0 && decay_div[1:0]==0)
                            harmonic3_env<=harmonic3_env-1'b1;
                    end else begin
                        if(harmonic2_env>8'd4) harmonic2_env<=harmonic2_env-8'd4;
                        else harmonic2_env<=0;
                        if(harmonic3_env>8'd6) harmonic3_env<=harmonic3_env-8'd6;
                        else harmonic3_env<=0;
                    end
                end
                case(state)
                    0: if(gate) state<=1;
                    1: begin
                        if(!gate) state<=3;
                        else if(timbre) begin
                            if(env>=8'd95) begin env<=8'd127; state<=2; end
                            else env<=env+8'd32;
                        end else begin
                            if(env>=8'd119) begin env<=8'd127; state<=2; end
                            else env<=env+8'd8;
                        end
                    end
                    2: begin
                        if(!gate) state<=3;
                        else if(timbre && env>8'd24 && decay_div==0) env<=env-8'd1;
                        else if(!timbre && env>8'd80) env<=env-8'd1;
                    end
                    3: begin
                        if(gate) state<=1;
                        else if(env>(timbre?8'd4:8'd2))
                            env<=env-(timbre?8'd4:8'd2);
                        else begin env<=0; state<=0; end
                    end
                endcase
            end
        end
    end
endmodule
