module button_timbre_control(
    input wire clk, input wire rst_n, input wire frame_tick,
    input wire [2:0] keys_n,
    output wire timbre, output wire suppress_notes,
    output reg chord_mode
);
    // Keep the preferred piano timbre. A roughly one-second hold on KEY0
    // toggles automatic major-triad mode; short presses still play normally.
    assign timbre = 1'b0;
    assign suppress_notes = 1'b0;

    reg [15:0] key0_hold;
    reg key0_latched;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chord_mode <= 1'b0;
            key0_hold <= 0;
            key0_latched <= 1'b0;
        end else if (frame_tick) begin
            if (!keys_n[0]) begin
                if (key0_hold < 16'd48000)
                    key0_hold <= key0_hold + 1'b1;
                else if (!key0_latched) begin
                    chord_mode <= ~chord_mode;
                    key0_latched <= 1'b1;
                end
            end else begin
                key0_hold <= 0;
                key0_latched <= 1'b0;
            end
        end
    end
endmodule
