module QuantizedConvReLU2d #(
    parameter INPUT_CHANNELS  = 1,
    parameter OUTPUT_CHANNELS = 32,
    parameter KERNEL_SIZE     = 3,
    parameter INPUT_WIDTH     = 30, // 包含填充
    parameter INPUT_HEIGHT    = 30, // 包含填充
    parameter SCALE           = 32'd15829858, // 定点表示的 0.2415242791
    parameter ZERO_POINT      = 8'd0
)(
    input                               clk,
    input                               rstn,
    input                               start,
    output                              done,
    
    // 输入特征图接口
    input       [7:0]                   input_data_in,
    input                               input_data_we,
    input       [$clog2(INPUT_WIDTH*INPUT_HEIGHT)-1:0]
                                        input_data_addr,
    
    // 权重接口
    input       [7:0]                   weight_data_in,
    input                               weight_data_we,
    input       [$clog2(OUTPUT_CHANNELS*INPUT_CHANNELS*
                       KERNEL_SIZE*KERNEL_SIZE)-1:0]
                                        weight_data_addr,
    
    // 偏置接口
    input       [31:0]                  bias_data_in,
    input                               bias_data_we,
    input       [$clog2(OUTPUT_CHANNELS)-1:0]
                                        bias_data_addr,
    
    // 卷积输出
    output reg  [7:0]                   conv_result,
    output reg                          conv_valid
);


// 输入特征图存储器
reg [7:0] input_feature_map [0:INPUT_WIDTH*INPUT_HEIGHT-1];

// 权重存储器
reg [7:0] weights [0:OUTPUT_CHANNELS*INPUT_CHANNELS*
                   KERNEL_SIZE*KERNEL_SIZE-1];

// 偏置存储器
reg [31:0] bias [0:OUTPUT_CHANNELS-1];

// 输入特征图写入
always @(posedge clk) begin
    if (input_data_we) begin
        input_feature_map[input_data_addr] <= input_data_in;
    end
end

// 权重写入
always @(posedge clk) begin
    if (weight_data_we) begin
        weights[weight_data_addr] <= weight_data_in;
    end
end

// 偏置写入
always @(posedge clk) begin
    if (bias_data_we) begin
        bias[bias_data_addr] <= bias_data_in;
    end
end


// 状态机定义
reg [7:0] row, col;
reg [31:0] acc;
reg [31:0] mult_result;
reg [31:0] scaled_result;
reg [7:0]  output_channel;
reg [7:0]  input_channel;
reg [7:0]  kernel_row, kernel_col;
reg        processing;
reg        done_flag;

assign done = done_flag;

integer input_idx, weight_idx;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        // 初始化寄存器
        row             <= 0;
        col             <= 0;
        acc             <= 0;
        output_channel  <= 0;
        input_channel   <= 0;
        kernel_row      <= 0;
        kernel_col      <= 0;
        processing      <= 0;
        done_flag       <= 0;
        conv_valid      <= 0;
        conv_result     <= 0;
    end else if (start) begin
        // 开始卷积计算
        processing      <= 1;
        done_flag       <= 0;
        row             <= 0;
        col             <= 0;
        output_channel  <= 0;
        input_channel   <= 0;
        kernel_row      <= 0;
        kernel_col      <= 0;
        acc             <= bias[0]; // 初始化累加器为偏置
    end else if (processing) begin
        // 卷积计算过程
        if (kernel_row < KERNEL_SIZE) begin
            if (kernel_col < KERNEL_SIZE) begin
                if (input_channel < INPUT_CHANNELS) begin
                    // 计算当前位置的乘积
                    input_idx = (row + kernel_row) * INPUT_WIDTH +
                                (col + kernel_col);
                    weight_idx = output_channel * INPUT_CHANNELS *
                                 KERNEL_SIZE * KERNEL_SIZE +
                                 input_channel * KERNEL_SIZE * KERNEL_SIZE +
                                 kernel_row * KERNEL_SIZE + kernel_col;
                    mult_result <= input_feature_map[input_idx] *
                                   weights[weight_idx];
                    acc <= acc + mult_result;
                    input_channel <= input_channel + 1;
                end else begin
                    input_channel <= 0;
                    if (kernel_col < KERNEL_SIZE - 1) begin
                        kernel_col <= kernel_col + 1;
                    end else begin
                        kernel_col <= 0;
                        kernel_row <= kernel_row + 1;
                    end
                end
            end
        end else begin
            // 应用量化缩放和 ReLU
            scaled_result <= ((acc * SCALE) >> 24) + ZERO_POINT;
            if (scaled_result[31]) begin // 判断符号位
                conv_result <= 8'd0;
            end else if (scaled_result > 8'd255) begin
                conv_result <= 8'd255;
            end else begin
                conv_result <= scaled_result[7:0];
            end
            conv_valid <= 1;
            // 准备下一个位置的计算
            acc <= bias[output_channel];
            if (col < INPUT_WIDTH - KERNEL_SIZE) begin
                col <= col + 1;
            end else begin
                col <= 0;
                if (row < INPUT_HEIGHT - KERNEL_SIZE) begin
                    row <= row + 1;
                end else begin
                    row <= 0;
                    if (output_channel < OUTPUT_CHANNELS - 1) begin
                        output_channel <= output_channel + 1;
                    end else begin
                        // 卷积计算完成
                        processing <= 0;
                        done_flag <= 1;
                    end
                end
            end
            // 重置计数器
            kernel_row <= 0;
            kernel_col <= 0;
            input_channel <= 0;
            conv_valid <= 0;
        end
    end else begin
        done_flag <= 0;
    end
end
endmodule