`timescale 1ns / 1ps
`include "config.h"

module debug_tb;
reg reset;
reg clk;
reg [3:0] touch_btn;
reg [31:0] dip_sw;

wire UART_RX;
wire UART_TX;
wire [2:0] video_red;
wire [2:0] video_green;
wire [1:0] video_blue;
wire video_hsync;
wire video_vsync;
wire video_clk;
wire video_de;
wire [15:0] leds;
wire [7:0] dpy0;
wire [7:0] dpy1;
wire [19:0] base_ram_addr;
wire [3:0] base_ram_be_n;
wire base_ram_ce_n;
wire base_ram_oe_n;
wire base_ram_we_n;
wire [19:0] ext_ram_addr;
wire [3:0] ext_ram_be_n;
wire ext_ram_ce_n;
wire ext_ram_oe_n;
wire ext_ram_we_n;
wire [31:0] base_ram_data;
wire [31:0] ext_ram_data;

initial begin
    clk = 1'b0;
    reset = 1'b1;
    touch_btn = 4'h0;
    dip_sw = 32'h0000_abcd;
    #2000;
    reset = 1'b0;
end

always #10 clk = ~clk;

soc_top #(.SIMULATION(1'b1)) u_soc_top (
    .clk(clk),
    .reset(reset),
    .touch_btn(touch_btn),
    .dip_sw(dip_sw),
    .video_red(video_red),
    .video_green(video_green),
    .video_blue(video_blue),
    .video_hsync(video_hsync),
    .video_vsync(video_vsync),
    .video_clk(video_clk),
    .video_de(video_de),
    .leds(leds),
    .dpy0(dpy0),
    .dpy1(dpy1),
    .base_ram_addr(base_ram_addr),
    .base_ram_be_n(base_ram_be_n),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_be_n(ext_ram_be_n),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),
    .base_ram_data(base_ram_data),
    .ext_ram_data(ext_ram_data),
    .UART_RX(UART_RX),
    .UART_TX(UART_TX)
);

sram_sp #(
    .AW(18),
    .Init_File(`SRAM_Init_File)
) base_sram_sp (
    .ram_addr(base_ram_addr),
    .ram_be_n(base_ram_be_n),
    .ram_ce_n(base_ram_ce_n),
    .ram_oe_n(base_ram_oe_n),
    .ram_we_n(base_ram_we_n),
    .ram_data(base_ram_data)
);

sram_sp #(
    .AW(18),
    .Init_File(`SRAM_Init_File)
) ext_sram_sp (
    .ram_addr(ext_ram_addr),
    .ram_be_n(ext_ram_be_n),
    .ram_ce_n(ext_ram_ce_n),
    .ram_oe_n(ext_ram_oe_n),
    .ram_we_n(ext_ram_we_n),
    .ram_data(ext_ram_data)
);

always @(posedge u_soc_top.cpu_clk) begin
    if (u_soc_top.cpu_resetn) begin
        if ((u_soc_top.debug_wb_pc & 32'h3f) == 32'h0) begin
            $display("%0t pc=%h inst=%h", $time, u_soc_top.debug_wb_pc, u_soc_top.debug_wb_inst);
        end
    end
end

always @(posedge clk) begin
    if (u_soc_top.u_axi_uart_controller.uart0.PSEL &&
        u_soc_top.u_axi_uart_controller.uart0.PENABLE &&
        u_soc_top.u_axi_uart_controller.uart0.PWRITE &&
        u_soc_top.u_axi_uart_controller.uart0.PADDR[7:0] == 8'h0) begin
        $write("%c", u_soc_top.u_axi_uart_controller.uart0.PWDATA[7:0]);
    end
end

initial begin
    #2000000;
    $display("timeout pc=%h inst=%h resetn=%b", u_soc_top.debug_wb_pc, u_soc_top.debug_wb_inst, u_soc_top.cpu_resetn);
    $finish;
end

endmodule
