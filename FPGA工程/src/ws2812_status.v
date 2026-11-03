module ws2812_status(input wire clk,input wire rst_n,input wire timbre,output wire dout);
    wire [7:0] red=timbre ? 8'd0 : 8'd72;
    wire [7:0] green=8'd0;
    wire [7:0] blue=timbre ? 8'd72 : 8'd0;
    wire frame_end;
    WS2812 #(.clk_freq(50_000_000),.fps(30),.used_led(1),
             .independent_led_ctrl("false")) official_driver(
        .sys_clk(clk),.rst_n(rst_n),.Do(dout),.pixel_addr(8'd0),
        .pixel_Red(red),.pixel_Green(green),.pixel_Blue(blue),
        .pixel_valid(1'b1),.TE(frame_end));
endmodule
