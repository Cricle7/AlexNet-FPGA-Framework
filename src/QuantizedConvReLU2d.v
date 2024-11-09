module QuantizedConvReLU2d #(
    parameter INPUT_CHANNELS  = 1,
    parameter OUTPUT_CHANNELS = 32,
    parameter KERNEL_SIZE     = 3,
    parameter INPUT_WIDTH     = 30, // 包含填充
    parameter INPUT_HEIGHT    = 30, // 包含填充
    parameter SCALE           = 32'd16177215, // 定点表示的缩放因子
    parameter ZERO_POINT      = 8'd0
)(
    input                               clk,
    input                               rstn,
    input                               start,
    output reg                          done,

    // 输入特征图接口
    input       [7:0]                   input_data_in,
    input                               input_data_we,
    input       [$clog2(INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH)-1:0]
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

    // 内部参数
    localparam INPUT_SIZE = INPUT_CHANNELS * INPUT_HEIGHT * INPUT_WIDTH;
    localparam WEIGHT_SIZE = OUTPUT_CHANNELS * INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;

    // RAM 读地址寄存器
    reg [$clog2(INPUT_SIZE)-1:0]   input_data_addr_read;
    reg [$clog2(WEIGHT_SIZE)-1:0]  weight_data_addr_read;
    reg [$clog2(OUTPUT_CHANNELS)-1:0] bias_data_addr_read;

    // 输入特征图 RAM
    reg [7:0] input_feature_map [0:INPUT_SIZE-1];
    reg [7:0] input_data_out;
    always @(posedge clk) begin
        if (input_data_we) begin
            input_feature_map[input_data_addr] <= input_data_in;
        end
        input_data_out <= input_feature_map[input_data_addr_read]; // 同步读取
    end

    // 权重 RAM
    reg [7:0] weights [0:WEIGHT_SIZE-1];
    reg [7:0] weight_data_out;
    always @(posedge clk) begin
        if (weight_data_we) begin
            weights[weight_data_addr] <= weight_data_in;
        end
        weight_data_out <= weights[weight_data_addr_read]; // 同步读取
    end

    // 偏置 RAM
    reg [31:0] biases [0:OUTPUT_CHANNELS-1];
    reg [31:0] bias_data_out;
    always @(posedge clk) begin
        if (bias_data_we) begin
            biases[bias_data_addr] <= bias_data_in;
        end
        bias_data_out <= biases[bias_data_addr_read]; // 同步读取
    end

    // 内部寄存器
    reg [7:0]  row, col;
    reg [7:0]  kernel_row, kernel_col;
    reg [7:0]  output_channel;
    reg [31:0] acc;
    reg        processing;

    // 状态机状态
    reg [2:0] state;
    localparam IDLE      = 3'd0;
    localparam LOAD_BIAS = 3'd1;
    localparam CALC      = 3'd2;
    localparam WAIT      = 3'd3;
    localparam WRITE     = 3'd4;
    localparam OUTPUT    = 3'd5;
    localparam CALC_NEXT = 3'd6;
    localparam DONE      = 3'd7;

    // 缩放结果计算
    wire [31:0] scaled_result_temp;
    assign scaled_result_temp = ((acc * SCALE) >> 26) + ZERO_POINT;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // 初始化寄存器和状态
            state           <= IDLE;
            done            <= 0;
            conv_valid      <= 0;
            conv_result     <= 0;
            processing      <= 0;
            row             <= 0;
            col             <= 0;
            kernel_row      <= 0;
            kernel_col      <= 0;
            output_channel  <= 0;
            acc             <= 0;
            input_data_addr_read  <= 0;
            weight_data_addr_read <= 0;
            bias_data_addr_read   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done       <= 0;
                    conv_valid <= 0;
                    if (start) begin
                        processing      <= 1;
                        row             <= 0;
                        col             <= 0;
                        kernel_row      <= 0;
                        kernel_col      <= 0;
                        output_channel  <= 0;
                        acc             <= 0;
                        // 加载偏置地址
                        bias_data_addr_read <= output_channel;
                        state           <= LOAD_BIAS;
                    end
                end

                LOAD_BIAS: begin
                    // 等待偏置数据准备好
                    state <= WAIT;
                end

                WAIT: begin
                    // 将偏置加载到累加器
                    acc <= bias_data_out;
                    // 设置初始输入和权重读地址
                    input_data_addr_read <= (row + kernel_row) * INPUT_WIDTH + (col + kernel_col);
                    weight_data_addr_read <= output_channel * KERNEL_SIZE * KERNEL_SIZE +
                                             kernel_row * KERNEL_SIZE + kernel_col;
                    state <= CALC;
                end

                CALC: begin
                    // 执行乘累加运算
                    acc <= acc + input_data_out * weight_data_out;
                    // 更新内核索引
                    if (kernel_col < KERNEL_SIZE - 1) begin
                        kernel_col <= kernel_col + 1;
                    end else begin
                        kernel_col <= 0;
                        if (kernel_row < KERNEL_SIZE - 1) begin
                            kernel_row <= kernel_row + 1;
                        end else begin
                            kernel_row <= 0;
                            // 一个位置的卷积计算完成
                            state <= WRITE;
                        end
                    end
                    // 更新下一个数据的读地址
                    input_data_addr_read <= (row + kernel_row) * INPUT_WIDTH + (col + kernel_col);
                    weight_data_addr_read <= output_channel * KERNEL_SIZE * KERNEL_SIZE +
                                             kernel_row * KERNEL_SIZE + kernel_col;
                end

                WRITE: begin
                    // 计算 conv_result
                    if (scaled_result_temp[31] == 1) begin
                        conv_result <= 8'd0;
                    end else if (scaled_result_temp > 8'd255) begin
                        conv_result <= 8'd255;
                    end else begin
                        conv_result <= scaled_result_temp[7:0];
                    end
                    conv_valid <= 1;
                    state <= CALC_NEXT;
                end

                CALC_NEXT: begin
                    conv_valid <= 0; // 拉低 conv_valid
                    // 重置累加器和索引
                    acc <= 0;
                    kernel_row <= 0;
                    kernel_col <= 0;
                    // 更新列和行索引
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
                                // 所有计算完成
                                processing <= 0;
                                done <= 1;
                                state <= DONE;
                            end
                        end
                    end
                    // 更新下一个输出通道的偏置地址
                    bias_data_addr_read <= output_channel;
                    // 准备下一个计算
                    if (state != DONE) begin
                        state <= LOAD_BIAS;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
