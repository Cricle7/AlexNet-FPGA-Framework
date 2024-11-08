module QuantizedConvReLU2d_tb;

    // 参数定义
    parameter INPUT_CHANNELS  = 1;
    parameter OUTPUT_CHANNELS = 32;
    parameter KERNEL_SIZE     = 3;
    parameter INPUT_WIDTH     = 30; // 包含填充
    parameter INPUT_HEIGHT    = 30; // 包含填充
    parameter SCALE           = 32'd16177215; // 0.2415242791 乘以 2^26
    parameter ZERO_POINT      = 8'd0;

    // 时钟和复位
    reg clk;
    reg rstn;

    // 控制信号
    reg start;
    wire done;

    // 数据接口信号
    reg [7:0] input_data_in;
    reg       input_data_we;
    reg [$clog2(INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH)-1:0] input_data_addr;

    reg [7:0] weight_data_in;
    reg       weight_data_we;
    reg [$clog2(OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE)-1:0] weight_data_addr;

    reg [31:0] bias_data_in;
    reg        bias_data_we;
    reg [$clog2(OUTPUT_CHANNELS)-1:0] bias_data_addr;

    // 输出信号
    wire [7:0] conv_result;
    wire       conv_valid;

    // 实例化被测模块
    QuantizedConvReLU2d #(
        .INPUT_CHANNELS  (INPUT_CHANNELS),
        .OUTPUT_CHANNELS (OUTPUT_CHANNELS),
        .KERNEL_SIZE     (KERNEL_SIZE),
        .INPUT_WIDTH     (INPUT_WIDTH),
        .INPUT_HEIGHT    (INPUT_HEIGHT),
        .SCALE           (SCALE),
        .ZERO_POINT      (ZERO_POINT)
    ) uut (
        .clk               (clk),
        .rstn              (rstn),
        .start             (start),
        .done              (done),
        .input_data_in     (input_data_in),
        .input_data_we     (input_data_we),
        .input_data_addr   (input_data_addr),
        .weight_data_in    (weight_data_in),
        .weight_data_we    (weight_data_we),
        .weight_data_addr  (weight_data_addr),
        .bias_data_in      (bias_data_in),
        .bias_data_we      (bias_data_we),
        .bias_data_addr    (bias_data_addr),
        .conv_result       (conv_result),
        .conv_valid        (conv_valid)
    );

    // 测试数据存储器（在模块级别声明）
    reg [7:0] input_data_mem [0:INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH-1];
    reg [7:0] weights_mem [0:OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE-1];
    reg [31:0] biases_mem [0:OUTPUT_CHANNELS-1];
    reg [7:0] expected_output_mem [0:OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)-1];
    reg [7:0] dut_output_mem [0:OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)-1];

    // 过程块中使用的变量
    integer i;
    integer output_index;
    integer errors;

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz 时钟
    end

    // 从文件中读取数据
    initial begin
        $readmemh("input_data.txt", input_data_mem);
        $readmemh("weights.txt", weights_mem);
        $readmemh("biases.txt", biases_mem);
        $readmemh("expected_output.txt", expected_output_mem);
    end

    // 测试过程
    initial begin
        // 初始化信号
        rstn = 0;
        start = 0;
        input_data_we = 0;
        weight_data_we = 0;
        bias_data_we = 0;
        output_index = 0;
        errors = 0;
        #20;
        rstn = 1;
        #10;

        // 加载输入数据
        for (i = 0; i < INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH; i = i + 1) begin
            @(posedge clk);
            input_data_we = 1;
            input_data_addr = i;
            input_data_in = input_data_mem[i];
        end
        input_data_we = 0;

        // 加载权重数据
        for (i = 0; i < OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            @(posedge clk);
            weight_data_we = 1;
            weight_data_addr = i;
            weight_data_in = weights_mem[i];
        end
        weight_data_we = 0;

        // 加载偏置数据
        for (i = 0; i < OUTPUT_CHANNELS; i = i + 1) begin
            @(posedge clk);
            bias_data_we = 1;
            bias_data_addr = i;
            bias_data_in = biases_mem[i];
        end
        bias_data_we = 0;

        // 开始卷积
        #10;
        start = 1;
        @(posedge clk);
        start = 0;

        // 等待卷积完成
        wait (done);
        $display("Convolution completed.");

        // 捕获输出结果
        output_index = 0;
        @(posedge clk); // 等待一个时钟周期
        while (output_index < OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)) begin
            @(posedge clk);
            if (conv_valid) begin
                dut_output_mem[output_index] = conv_result;
                output_index = output_index + 1;
            end
        end

        // 比较结果
        errors = 0;
        for (i = 0; i < OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2); i = i + 1) begin
            if (dut_output_mem[i] !== expected_output_mem[i]) begin
                $display("Mismatch at index %d: Expected %h, Got %h", i, expected_output_mem[i], dut_output_mem[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $display("Test passed. All outputs match.");
        end else begin
            $display("Test failed. %d mismatches found.", errors);
        end

        $stop;
    end

endmodule
