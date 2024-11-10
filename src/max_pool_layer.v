module max_pool_layer #(
    parameter INPUT_CHANNELS = 32,
    parameter INPUT_WIDTH = 40,
    parameter INPUT_HEIGHT = 40,
    parameter POOL_SIZE = 2,
    parameter STRIDE = 2,
    parameter OUTPUT_WIDTH = INPUT_WIDTH / STRIDE,
    parameter OUTPUT_HEIGHT = INPUT_HEIGHT / STRIDE,
    parameter DATA_WIDTH = 8 // Assuming 8-bit data
)(
    input                               clk,
    input                               rstn,
    input                               en,
    input [INPUT_CHANNELS*DATA_WIDTH-1:0] data_in, // Packed input data for one pixel
    input                               data_valid,
    output reg [INPUT_CHANNELS*DATA_WIDTH-1:0] data_out, // Packed output data
    output reg                          data_ready
);

    // Internal registers and wires
    reg [DATA_WIDTH-1:0] window [0:INPUT_CHANNELS-1][0:POOL_SIZE*POOL_SIZE-1];
    integer c, i;

    // State machine states
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam LOAD = 2'd1;
    localparam CALC = 2'd2;
    localparam OUTPUT = 2'd3;

    // Counters
    reg [$clog2(POOL_SIZE)-1:0] pool_row, pool_col;
    reg [$clog2(OUTPUT_WIDTH)-1:0] out_row, out_col;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            data_ready <= 0;
            out_row <= 0;
            out_col <= 0;
            pool_row <= 0;
            pool_col <= 0;
        end else begin
            case (state)
                IDLE: begin
                    data_ready <= 0;
                    if (en && data_valid) begin
                        // Load first window position
                        for (c = 0; c < INPUT_CHANNELS; c = c + 1) begin
                            window[c][0] <= data_in[c*DATA_WIDTH +: DATA_WIDTH];
                        end
                        pool_col <= 0;
                        pool_row <= 0;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        // Load the rest of the window
                        for (c = 0; c < INPUT_CHANNELS; c = c + 1) begin
                            window[c][pool_row * POOL_SIZE + pool_col] <= data_in[c*DATA_WIDTH +: DATA_WIDTH];
                        end
                        if (pool_col < POOL_SIZE - 1) begin
                            pool_col <= pool_col + 1;
                        end else begin
                            pool_col <= 0;
                            if (pool_row < POOL_SIZE - 1) begin
                                pool_row <= pool_row + 1;
                            end else begin
                                pool_row <= 0;
                                state <= CALC;
                            end
                        end
                    end
                end

                CALC: begin
                    // Perform max pooling
                    for (c = 0; c < INPUT_CHANNELS; c = c + 1) begin
                        data_out[c*DATA_WIDTH +: DATA_WIDTH] <= max_pool(window[c]);
                    end
                    data_ready <= 1;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    data_ready <= 0;
                    if (out_col < OUTPUT_WIDTH - 1) begin
                        out_col <= out_col + 1;
                    end else begin
                        out_col <= 0;
                        if (out_row < OUTPUT_HEIGHT - 1) begin
                            out_row <= out_row + 1;
                        end else begin
                            out_row <= 0;
                            state <= IDLE; // Processing complete
                        end
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Function to calculate max value in the pooling window
    function [DATA_WIDTH-1:0] max_pool;
        input [DATA_WIDTH-1:0] pool_window [0:POOL_SIZE*POOL_SIZE-1];
        integer idx;
        reg [DATA_WIDTH-1:0] max_val;
        begin
            max_val = pool_window[0];
            for (idx = 1; idx < POOL_SIZE*POOL_SIZE; idx = idx + 1) begin
                if (pool_window[idx] > max_val) begin
                    max_val = pool_window[idx];
                end
            end
            max_pool = max_val;
        end
    endfunction

endmodule
