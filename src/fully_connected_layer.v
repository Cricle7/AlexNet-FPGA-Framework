module fully_connected_layer #(
    parameter INPUT_SIZE = 512,
    parameter OUTPUT_SIZE = 3,
    parameter DATA_WIDTH = 8, // Assuming 8-bit data
    parameter ACC_WIDTH = 32  // Accumulator width
)(
    input                               clk,
    input                               rstn,
    input                               en,
    input [INPUT_SIZE*DATA_WIDTH-1:0]   data_in,    // Packed input data
    input [INPUT_SIZE*OUTPUT_SIZE*DATA_WIDTH-1:0] weights, // Packed weights
    input [OUTPUT_SIZE*ACC_WIDTH-1:0]   biases,     // Packed biases
    output reg [OUTPUT_SIZE*DATA_WIDTH-1:0] data_out, // Packed output data
    output reg                          data_valid
);

    // Internal registers
    reg [ACC_WIDTH-1:0] acc [0:OUTPUT_SIZE-1];
    integer i, j;

    // State machine states
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam CALC = 2'd1;
    localparam OUTPUT = 2'd2;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            data_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    data_valid <= 0;
                    if (en) begin
                        // Initialize accumulators with biases
                        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
                            acc[i] <= biases[i*ACC_WIDTH +: ACC_WIDTH];
                        end
                        state <= CALC;
                    end
                end

                CALC: begin
                    // Perform matrix multiplication
                    for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
                        for (j = 0; j < INPUT_SIZE; j = j + 1) begin
                            acc[i] <= acc[i] + data_in[j*DATA_WIDTH +: DATA_WIDTH] * weights[(i*INPUT_SIZE + j)*DATA_WIDTH +: DATA_WIDTH];
                        end
                    end
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    // Apply activation function if needed (e.g., ReLU)
                    for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
                        data_out[i*DATA_WIDTH +: DATA_WIDTH] <= acc[i][DATA_WIDTH-1:0]; // Truncate to DATA_WIDTH
                    end
                    data_valid <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
