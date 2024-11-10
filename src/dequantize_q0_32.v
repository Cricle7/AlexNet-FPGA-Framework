module dequantize_q0_32(
    input  wire [7:0]  pixel_in,   // 8-bit quantized input
    output wire [31:0] pixel_out   // Q0.32 fixed-point output
);
    // 定义常量
    parameter [31:0] SCALE_Q0_32 = 32'd5123321069; // 0.11937939375638962 * 2^32
    parameter [7:0] ZERO_POINT = 8'd0;

    // 减去零点
    wire [31:0] adjusted_pixel;
    assign adjusted_pixel = (pixel_in - ZERO_POINT) << 32; // Q0.32 格式

    // 乘以缩放因子
    wire [63:0] dequantized_long;
    assign dequantized_long = adjusted_pixel * SCALE_Q0_32; // Q0.64 格式

    // 取高 32 位，得到 Q0.32 格式
    assign pixel_out = dequantized_long[63:32];

endmodule
