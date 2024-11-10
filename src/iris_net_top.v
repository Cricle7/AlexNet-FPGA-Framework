module iris_net_top(
    input clk,
    input rstn,
    input en,
    input [7:0] pixel_in,    // 8-bit input pixel stream
    input pixel_valid,
    output [7:0] result_out, // Output result
    output result_valid
);
    // Intermediate signals
    wire [7:0] quantized_pixel;
    wire quant_valid;

    // Instantiate normalization and quantization modules
    // Assume these modules are defined elsewhere
    normalize_q0_32 normalize_inst (
        .pixel_in(pixel_in),
        .pixel_out(quantized_pixel)
    );

    // Convolutional Layer 1
    wire [32*8-1:0] conv1_out; // Assuming DATA_WIDTH = 8
    wire conv1_valid;
    QuantizedConvReLU2d #(
        .INPUT_CHANNELS(1),
        .OUTPUT_CHANNELS(32),
        .KERNEL_SIZE(3),
        .INPUT_WIDTH(40),
        .INPUT_HEIGHT(40),
        .SCALE(32'd16177215),
        .ZERO_POINT(8'd0)
    ) conv1 (
        .clk(clk),
        .rstn(rstn),
        .start(en),
        .done(),
        .processing(),
        .input_data_in(quantized_pixel),
        .input_data_we(pixel_valid),
        .input_data_addr(),
        .weight_data_in(), // Load weights appropriately
        .weight_data_we(),
        .weight_data_addr(),
        .bias_data_in(),   // Load biases appropriately
        .bias_data_we(),
        .bias_data_addr(),
        .conv_result(),
        .conv_valid(conv1_valid)
    );

    // Max Pooling Layer 1
    wire [32*8-1:0] pool1_out;
    wire pool1_valid;
    max_pool_layer #(
        .INPUT_CHANNELS(32),
        .INPUT_WIDTH(40),
        .INPUT_HEIGHT(40),
        .POOL_SIZE(2),
        .STRIDE(2)
    ) pool1 (
        .clk(clk),
        .rstn(rstn),
        .en(conv1_valid),
        .data_in(conv1_out),
        .data_valid(conv1_valid),
        .data_out(pool1_out),
        .data_ready(pool1_valid)
    );

    // Repeat for Convolutional Layers 2 and 3
    // ...

    // Flatten the output of the last pooling layer
    wire [3200*8-1:0] flattened_features;
    // Implement flattening logic here

    // Fully Connected Layer 1
    wire [512*8-1:0] fc1_out;
    wire fc1_valid;
    fully_connected_layer #(
        .INPUT_SIZE(3200),
        .OUTPUT_SIZE(512)
    ) fc1 (
        .clk(clk),
        .rstn(rstn),
        .en(pool3_valid),
        .data_in(flattened_features),
        .weights(weights_fc1), // Provide weights
        .biases(biases_fc1),   // Provide biases
        .data_out(fc1_out),
        .data_valid(fc1_valid)
    );

    // Apply ReLU activation to fc1_out if needed

    // Fully Connected Layer 2
    wire [3*8-1:0] fc2_out;
    wire fc2_valid;
    fully_connected_layer #(
        .INPUT_SIZE(512),
        .OUTPUT_SIZE(3)
    ) fc2 (
        .clk(clk),
        .rstn(rstn),
        .en(fc1_valid),
        .data_in(fc1_out),
        .weights(weights_fc2),
        .biases(biases_fc2),
        .data_out(fc2_out),
        .data_valid(fc2_valid)
    );

    // Output assignment
    assign result_out = fc2_out[7:0];  // Adjust as per your data width
    assign result_valid = fc2_valid;

endmodule
