module tb_QuantizedConvReLU2d;
// 参数定义（保持不变）
parameter INPUT_CHANNELS  = 64;
parameter OUTPUT_CHANNELS = 128;
parameter KERNEL_SIZE     = 3;
parameter INPUT_WIDTH     = 30; // 输入尺寸28，加上填充1*2
parameter INPUT_HEIGHT    = 30;
parameter real SCALE_FLOAT = 0.1675153225660324;
parameter SCALE           = 32'd16177215; // 0.1675153225660324 * (1 << 26)
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

// 卷积输出
wire [7:0] conv_result;
wire       conv_valid;

// 实例化被测模块（保持不变）
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
    .processing        (processing),
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

// 测试数据存储器（保持不变）
reg [7:0] input_data_mem [0:INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH-1];
reg [7:0] weights_mem [0:OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE-1];
reg [31:0] biases_mem [0:OUTPUT_CHANNELS-1];
reg [7:0] expected_output_mem [0:OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)-1];
reg [7:0] dut_output_mem [0:OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)-1];

// 过程块中使用的变量
integer i;
integer output_index;
integer errors;
integer logfile;
integer run_count;

// 时钟生成（保持不变）
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz 时钟
end

// 从文件中读取数据（保持不变）
initial begin
    $readmemh("input_data.txt", input_data_mem);
    $readmemh("weights.txt", weights_mem);
    $readmemh("biases.txt", biases_mem);
    $readmemh("expected_output.txt", expected_output_mem);
end

// 测试过程
initial begin
    // 打开日志文件
    logfile = $fopen("simulation_output.log", "w");

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

    for (i = 0; i < OUTPUT_CHANNELS*INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
        @(posedge clk);
        weight_data_we = 1;
        weight_data_addr = i;
        weight_data_in = weights_mem[i];
    end
    @(posedge clk);
    weight_data_we = 0;

    // 加载偏置数据（只需加载一次）
    for (i = 0; i < OUTPUT_CHANNELS; i = i + 1) begin
        @(posedge clk);
        bias_data_we = 1;
        bias_data_addr = i;
        bias_data_in = biases_mem[i];
    end
    @(posedge clk);
    bias_data_we = 0;

    // 运行卷积三次
    for (run_count = 0; run_count < 3; run_count = run_count + 1) begin
        $fdisplay(logfile, "Starting convolution run %d", run_count + 1);

        // 加载输入数据（每次运行都需要重新加载）
        for (i = 0; i < INPUT_CHANNELS*INPUT_HEIGHT*INPUT_WIDTH; i = i + 1) begin
            @(posedge clk);
            input_data_we = 1;
            input_data_addr = i;
            input_data_in = input_data_mem[i];
        end
        @(posedge clk);
        input_data_we = 0;

        // 启动卷积
        #10;
        start = 1;
        @(posedge clk);
        start = 0;

        // 捕获输出结果
        fork
            // 线程1：捕获 conv_valid 信号并存储输出
            begin
                while (output_index < OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2)) begin
                    @(posedge clk);
                    if (conv_valid) begin
                        dut_output_mem[output_index] = conv_result;
                        output_index = output_index + 1;
                    end
                end
            end

            output_index = 0;
            // 线程2：等待卷积完成
            begin
                wait (done);
                $fdisplay(logfile, "Convolution run %d completed.", run_count + 1);
                // 等待 done 信号拉低
                @(negedge done);
            end
        join

        // 比较结果
        errors = 0;
        for (i = 0; i < OUTPUT_CHANNELS*(INPUT_HEIGHT-2)*(INPUT_WIDTH-2); i = i + 1) begin
            if (dut_output_mem[i] !== expected_output_mem[i]) begin
                $fdisplay(logfile, "Mismatch at index %d: Expected %h, Got %h", i, expected_output_mem[i], dut_output_mem[i]);
                errors = errors + 1;
            end
        end

        if (errors == 0) begin
            $fdisplay(logfile, "Run %d passed. All outputs match.", run_count + 1);
        end else begin
            $fdisplay(logfile, "Run %d failed. %d mismatches found.", run_count + 1, errors);
        end

        // 等待一段时间，确保 DUT 准备好下一次运行
        #20;
    end

    $fclose(logfile);
    $stop;
end

endmodule
