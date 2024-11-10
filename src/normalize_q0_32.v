module normalize_q0_32(
    input  wire [7:0]  pixel_in,   // 8-bit input pixel
    output wire [31:0] pixel_out   // Q0.32 fixed-point output
);
    // 定义常量（Q0.32 格式）
    parameter [31:0] MEAN_Q0_32 = 32'd2088533110;       // 0.485 * 2^32
    parameter [63:0] INV_STD_Q0_64 = 64'd18468359334436893710; // (1 / 0.229) * (2^32)^2

    // 将像素值转换为 Q0.32 格式
    wire [31:0] pixel_fixed;
    assign pixel_fixed = (pixel_in * 32'd4294967296) / 8'd255;

    // 计算差值
    wire signed [32:0] diff;
    assign diff = {1'b0, pixel_fixed} - {1'b0, MEAN_Q0_32};

    // 乘以标准差的倒数
    wire signed [95:0] normalized_long;
    assign normalized_long = diff * INV_STD_Q0_64; // Q0.96 格式

    // 取高 64 位，得到 Q0.32 格式的归一化结果
    assign pixel_out = normalized_long[95:64];

endmodule
