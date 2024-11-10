module image_processor(
    input  wire         clk,
    input  wire         rstn,
    input  wire [7:0]   pixel_in,    // 8-bit input pixel stream
    input  wire         pixel_valid, // Indicates when pixel_in is valid
    output wire [7:0]   pixel_out,   // 8-bit quantized pixel stream
    output wire         pixel_ready  // Indicates when pixel_out is valid
);
    // 中间信号
    wire [31:0] normalized_pixel;
    wire [7:0]  quantized_pixel;

    // 实例化归一化模块
    normalize_q0_32 normalize_inst (
        .pixel_in(pixel_in),
        .pixel_out(normalized_pixel)
    );

    // 实例化量化模块
    quantize_q0_32 quantize_inst (
        .pixel_in(normalized_pixel),
        .pixel_out(quantized_pixel)
    );

    // 实例化反量化模块（如果需要）
    // dequantize_q0_32 dequantize_inst (
    //     .pixel_in(quantized_pixel),
    //     .pixel_out(dequantized_pixel)
    // );

    // 输出分配
    assign pixel_out = quantized_pixel;
    assign pixel_ready = pixel_valid; // 简单起见，假设处理是即时的

endmodule
