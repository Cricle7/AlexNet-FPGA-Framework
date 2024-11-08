module QuantizedConvReLU2d #(
    parameter INPUT_CHANNELS  = 1,
    parameter OUTPUT_CHANNELS = 32,
    parameter KERNEL_SIZE     = 3,
    parameter INPUT_WIDTH     = 28,
    parameter INPUT_HEIGHT    = 28,
    parameter SCALE           = 16'h3D6A,   // 定点表示的量化缩放因子
    parameter ZERO_POINT      = 8'h00       // 量化零点
)(
    input                               clk,
    input                               rstn,
    input                               start,          // 开始信号
    input  [INPUT_CHANNELS*8-1:0]       quantized_input, // 输入特征图数据
    input  [OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*8-1:0]
                                        quantized_weights, // 量化权重
    input  [OUTPUT_CHANNELS*8-1:0]      quantized_bias,  // 量化偏置
    output                              done,            // 完成信号
    output [OUTPUT_CHANNELS*8-1:0]      quantized_output // 输出特征图数据
);

    // 定义必要的寄存器和线网
    reg [7:0] input_feature_map[0:INPUT_CHANNELS-1]
                               [0:INPUT_HEIGHT-1]
                               [0:INPUT_WIDTH-1];
    reg [7:0] weights[0:OUTPUT_CHANNELS-1]
                     [0:INPUT_CHANNELS-1]
                     [0:KERNEL_SIZE-1]
                     [0:KERNEL_SIZE-1];
    reg [15:0] conv_result[0:OUTPUT_CHANNELS-1];
    reg [OUTPUT_CHANNELS*8-1:0] output_buffer;
    reg [7:0] bias[0:OUTPUT_CHANNELS-1];

    integer oc, ic, i, j;

    // 状态机控制信号
    reg [7:0] row, col;
    reg processing;
    reg done_flag;

    assign done = done_flag;
    assign quantized_output = output_buffer;

    // 初始化权重和偏置
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (oc = 0; oc < OUTPUT_CHANNELS; oc = oc + 1) begin
                bias[oc] <= 0;
                for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
                        for (j = 0; j < KERNEL_SIZE; j = j + 1) begin
                            weights[oc][ic][i][j] <= 0;
                        end
                    end
                end
            end
        end else if (start) begin
            // 在实际设计中，这里应该加载权重和偏置
            // 这里只是示例，没有实际赋值
        end
    end

    // 输入特征图数据加载
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
                    for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                        input_feature_map[ic][i][j] <= 0;
                    end
                end
            end
        end else if (start) begin
            // 在实际设计中，这里应该加载输入特征图数据
            // 这里只是示例，没有实际赋值
        end
    end

    // 卷积计算过程
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            row <= 0;
            col <= 0;
            processing <= 0;
            done_flag <= 0;
            output_buffer <= 0;
        end else if (start) begin
            processing <= 1;
            done_flag <= 0;
        end else if (processing) begin
            if (row < INPUT_HEIGHT - KERNEL_SIZE + 1) begin
                if (col < INPUT_WIDTH - KERNEL_SIZE + 1) begin
                    // 对每个输出通道计算卷积
                    for (oc = 0; oc < OUTPUT_CHANNELS; oc = oc + 1) begin
                        conv_result[oc] = bias[oc]; // 初始化为偏置
                        // 对每个输入通道计算
                        for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                            // 卷积核计算
                            for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
                                for (j = 0; j < KERNEL_SIZE; j = j + 1) begin
                                    conv_result[oc] = conv_result[oc] +
                                        input_feature_map[ic][row + i][col + j] *
                                        weights[oc][ic][i][j];
                                end
                            end
                        end
                        // 应用量化缩放和 ReLU
                        integer scaled_result;
                        scaled_result = ((conv_result[oc] * SCALE) >> 16)
                                        + ZERO_POINT;
                        if (scaled_result < 0)
                            output_buffer[oc*8 +: 8] <= 0;
                        else if (scaled_result > 255)
                            output_buffer[oc*8 +: 8] <= 8'hFF;
                        else
                            output_buffer[oc*8 +: 8] <= scaled_result[7:0];
                    end
                    // 更新列指针
                    col <= col + 1;
                end else begin
                    col <= 0;
                    row <= row + 1;
                end
            end else begin
                processing <= 0;
                done_flag <= 1; // 卷积完成
            end
        end else begin
            done_flag <= 0;
        end
    end

endmodule
