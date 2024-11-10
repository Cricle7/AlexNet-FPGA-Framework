module testbench_iris_net;
    reg clk;
    reg rstn;
    reg en;
    reg [7:0] pixel_in;
    reg pixel_valid;
    wire [7:0] result_out;
    wire result_valid;

    // Instantiate the top-level module
    iris_net_top uut (
        .clk(clk),
        .rstn(rstn),
        .en(en),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .result_out(result_out),
        .result_valid(result_valid)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

    // Image data storage
    reg [7:0] image_data [0:1599]; // For a 40x40 image

    integer i;

    initial begin
        // Initialize signals
        rstn = 0;
        en = 0;
        pixel_valid = 0;
        pixel_in = 0;

        // Reset sequence
        #20;
        rstn = 1;
        en = 1;

        // Load image data from a file
        $readmemh("input_image.hex", image_data);

        // Feed image data to the network
        for (i = 0; i < 1600; i = i + 1) begin
            @(posedge clk);
            pixel_in <= image_data[i];
            pixel_valid <= 1;
        end

        // Wait for the result
        pixel_valid <= 0;
        wait (result_valid);
        $display("Recognition result: %d", result_out);

        $finish;
    end

endmodule
