module quantize_q0_32(
    input  wire [31:0] pixel_in,   // Q0.32 fixed-point input
    output wire [7:0]  pixel_out   // 8-bit quantized output
);
    // 定义常量
    parameter [63:0] RECIP_SCALE_Q0_64 = 64'd1546188226566; // (1 / 0.11937939375638962) * (2^32)
    parameter [7:0] ZERO_POINT = 8'd0;

    // 乘以缩放因子的倒数
    wire [95:0] scaled_long;
    assign scaled_long = pixel_in * RECIP_SCALE_Q0_64; // Q0.96 格式

    // 取高 64 位，得到 Q0.32 格式
    wire [31:0] scaled_fixed;
    assign scaled_fixed = scaled_long[95:64];

    // 加上零点
    wire [31:0] quantized_long;
    assign quantized_long = scaled_fixed + (ZERO_POINT << 32);

    // 舍入并截断为 8 位
    assign pixel_out = quantized_long[39:32];

endmodule
