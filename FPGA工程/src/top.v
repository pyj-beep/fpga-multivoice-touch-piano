module top (
    input  wire clk,
    input  wire rst_n,
    output reg  i2s_bclk,
    output reg  i2s_lrck,
    output reg  i2s_din,
    output wire pa_en
);

    // Tang Mega NEO audio amplifier enable is active-low.
    // This matches Sipeed's reference audio project.
    assign pa_en = 1'b0;

    // 50 MHz / (32 system clocks per BCLK * 32 bits per frame)
    // = 48.828125 kHz stereo sample rate.
    reg [3:0]  clk_div;
    reg [4:0]  bit_pos;
    reg [31:0] phase;
    reg [31:0] shift_data;

    localparam [31:0] PHASE_INC = 32'd38702809; // approximately 440 Hz
    localparam signed [15:0] AMP = 16'sh0800;   // low initial volume

    wire [31:0] next_phase = phase + PHASE_INC;
    wire signed [15:0] next_sample = next_phase[31] ? -AMP : AMP;
    wire [31:0] next_stereo = {next_sample, next_sample};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div    <= 4'd0;
            bit_pos    <= 5'd0;
            phase      <= 32'd0;
            shift_data <= {AMP, AMP};
            i2s_bclk   <= 1'b0;
            i2s_lrck   <= 1'b0;
            i2s_din    <= AMP[15];
        end else begin
            clk_div <= clk_div + 1'b1;

            if (clk_div == 4'd15) begin
                clk_div  <= 4'd0;
                i2s_bclk <= ~i2s_bclk;

                // Data is changed on BCLK falling edges and is stable
                // for the following rising edge used by PT8211-S.
                if (i2s_bclk) begin
                    if (bit_pos == 5'd31) begin
                        phase      <= phase + PHASE_INC;
                        shift_data <= next_stereo;
                        bit_pos    <= 5'd0;
                        i2s_lrck   <= 1'b0;
                        i2s_din    <= next_stereo[31];
                    end else begin
                        bit_pos  <= bit_pos + 1'b1;
                        i2s_lrck <= (bit_pos + 1'b1 >= 5'd16);
                        i2s_din  <= shift_data[30 - bit_pos];
                    end
                end
            end
        end
    end
endmodule
