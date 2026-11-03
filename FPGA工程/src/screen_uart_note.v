// LT7689 screen UART receiver: 115200 baud, 8-N-1.
// Touch frame: 5A A5 07 41 FF FF 00 NOTE CRC_H CRC_L.
module screen_uart_note #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD = 115_200
)(
    input wire clk,
    input wire rst_n,
    input wire uart_rx,
    output reg note_gate,
    output reg [31:0] phase_inc,
    output reg [4:0] note_index,
    output reg [1:0] harmony_mode
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam integer HALF_BIT = CLKS_PER_BIT / 2;
    localparam integer NOTE_HOLD = CLK_HZ / 3;

    reg rx_meta, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rx_meta <= 1'b1; rx_sync <= 1'b1; end
        else begin rx_meta <= uart_rx; rx_sync <= rx_meta; end
    end

    reg rx_busy;
    reg [15:0] rx_count;
    reg [3:0] rx_bit;
    reg [7:0] rx_shift, rx_byte;
    reg rx_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_busy <= 0; rx_count <= 0; rx_bit <= 0;
            rx_shift <= 0; rx_byte <= 0; rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            if (!rx_busy) begin
                if (!rx_sync) begin
                    rx_busy <= 1; rx_count <= HALF_BIT; rx_bit <= 0;
                end
            end else if (rx_count != 0) begin
                rx_count <= rx_count - 1'b1;
            end else if (rx_bit == 0) begin
                if (!rx_sync) begin rx_bit <= 1; rx_count <= CLKS_PER_BIT - 1; end
                else rx_busy <= 0;
            end else if (rx_bit <= 8) begin
                rx_shift[rx_bit-1] <= rx_sync;
                rx_bit <= rx_bit + 1'b1;
                rx_count <= CLKS_PER_BIT - 1;
            end else begin
                if (rx_sync) begin rx_byte <= rx_shift; rx_valid <= 1; end
                rx_busy <= 0;
            end
        end
    end

    reg [3:0] frame_pos;
    reg [7:0] command, addr_hi, addr_lo, data_hi;
    reg note_event;
    reg [7:0] note_value;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_pos <= 0; command <= 0; addr_hi <= 0; addr_lo <= 0;
            data_hi <= 0; note_event <= 0; note_value <= 0;
        end else begin
            note_event <= 0;
            if (rx_valid) begin
                case (frame_pos)
                    0: if (rx_byte == 8'h5A) frame_pos <= 1;
                    1: begin
                        if (rx_byte == 8'hA5) frame_pos <= 2;
                        else if (rx_byte != 8'h5A) frame_pos <= 0;
                    end
                    2: begin
                        if (rx_byte == 8'h07) frame_pos <= 3;
                        else frame_pos <= 0;
                    end
                    3: begin command <= rx_byte; frame_pos <= 4; end
                    4: begin addr_hi <= rx_byte; frame_pos <= 5; end
                    5: begin addr_lo <= rx_byte; frame_pos <= 6; end
                    6: begin data_hi <= rx_byte; frame_pos <= 7; end
                    7: begin
                        if (command == 8'h41 && addr_hi == 8'hFF &&
                            addr_lo == 8'hFF && data_hi == 0 &&
                            (rx_byte <= 8'd23 ||
                             (rx_byte >= 8'h40 && rx_byte <= 8'h43))) begin
                            note_value <= rx_byte;
                            note_event <= 1;
                        end
                        frame_pos <= 8;
                    end
                    8: frame_pos <= 9;
                    default: frame_pos <= 0;
                endcase
            end
        end
    end

    reg [24:0] hold_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_count <= 0; note_gate <= 0; note_index <= 0;
            phase_inc <= 32'd23012828; harmony_mode <= 0;
        end else if (note_event) begin
            if (note_value >= 8'h40) begin
                harmony_mode <= note_value[1:0];
            end else begin
                note_index <= note_value[4:0];
                note_gate <= 1;
                hold_count <= NOTE_HOLD;
                case (note_value)
                    0: phase_inc <= 32'd23012828;
                    1: phase_inc <= 32'd24381242;
                    2: phase_inc <= 32'd25831026;
                    3: phase_inc <= 32'd27367019;
                    4: phase_inc <= 32'd28994347;
                    5: phase_inc <= 32'd30718440;
                    6: phase_inc <= 32'd32545054;
                    7: phase_inc <= 32'd34480283;
                    8: phase_inc <= 32'd36530588;
                    9: phase_inc <= 32'd38702809;
                    10: phase_inc <= 32'd41004198;
                    11: phase_inc <= 32'd43442435;
                    12: phase_inc <= 32'd46025656;
                    13: phase_inc <= 32'd48762484;
                    14: phase_inc <= 32'd51662052;
                    15: phase_inc <= 32'd54734038;
                    16: phase_inc <= 32'd57988694;
                    17: phase_inc <= 32'd61436880;
                    18: phase_inc <= 32'd65090108;
                    19: phase_inc <= 32'd68960566;
                    20: phase_inc <= 32'd73061176;
                    21: phase_inc <= 32'd77405618;
                    22: phase_inc <= 32'd82008396;
                    23: phase_inc <= 32'd86884870;
                    default: phase_inc <= 32'd23012828;
                endcase
            end
        end else if (hold_count != 0) begin
            hold_count <= hold_count - 1'b1;
        end else note_gate <= 0;
    end
endmodule
