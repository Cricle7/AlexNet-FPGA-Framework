`timescale 100ps/10ps

module tb_uart ();

  // Inputs
  reg w_pixel_clk;
  reg w_pixel_rst;
  reg uart_rx_i;
  reg w_vsync;

  // Outputs
  wire uart_tx_o;
  wire [7:0] target_pos_out1;
  wire [7:0] target_pos_out2;

  // Internal registers
  reg [1:0] r_w_vsync;

  // Instantiate the Unit Under Test (UUT)
  uart_top u_uart_top (
    .clk(w_pixel_clk),
    .reset(w_pixel_rst),
    .uart_rx(uart_rx_i),
    .uart_tx(uart_tx_o),
    .r_vsync_i(r_w_vsync),
    .target_pos_out1(target_pos_out1),
    .target_pos_out2(target_pos_out2)
  );

  // Clock generation
  initial begin
    w_pixel_clk = 0;
    forever #5 w_pixel_clk = ~w_pixel_clk; // 10ns clock period (100 MHz)
  end

  // Reset sequence
  initial begin
    w_pixel_rst = 1;
    #20 w_pixel_rst = 0; // Release reset after 20ns
  end

  // VSYNC signal generation
  always @(posedge w_pixel_clk) begin
    r_w_vsync <= {r_w_vsync[0], w_vsync};
  end

  // Test stimulus
  initial begin
    // Initialize Inputs
    w_vsync = 1;
    uart_rx_i = 1;  // Idle state for UART RX

    #50; // Wait for reset

    // Generate a VSYNC pulse
    w_vsync = 0;
    #50;
    w_vsync = 1;
    
    // Send a UART RX signal (example data)
    #100 uart_rx_i = 0; // Start bit
    #100 uart_rx_i = 1; // Data bits
    #100 uart_rx_i = 1;
    #100 uart_rx_i = 0;
    #100 uart_rx_i = 1;
    #100 uart_rx_i = 0;
    #100 uart_rx_i = 1;
    #100 uart_rx_i = 0;
    #100 uart_rx_i = 1; // Stop bit
    #100 uart_rx_i = 1; // Idle

    // Additional test cases can be added here
    #500;
    $stop; // End of simulation
  end


endmodule
