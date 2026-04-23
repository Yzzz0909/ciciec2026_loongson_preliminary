module int_ctrl (
    input             clk,
    input             resetn,
    input      [3:0]  touch_btn,
    input             timer_int,
    input      [31:0] int_en,
    input      [31:0] int_edge,
    input      [31:0] int_pol,
    input      [31:0] int_clr,
    input      [31:0] int_set,
    output reg [31:0] int_state,
    output            int_req
);

reg  [5:0] intr_src_d;
reg  [5:0] intr_src_q;
reg  [5:0] intr_level_d;
reg  [5:0] intr_level_q;

always @(*) begin
    intr_level_d[0] = int_pol[0] ? touch_btn[0] : ~touch_btn[0];
    intr_level_d[1] = int_pol[1] ? touch_btn[1] : ~touch_btn[1];
    intr_level_d[2] = int_pol[2] ? touch_btn[2] : ~touch_btn[2];
    intr_level_d[3] = int_pol[3] ? touch_btn[3] : ~touch_btn[3];
    intr_level_d[4] = int_pol[4] ? timer_int    : ~timer_int;
    intr_level_d[5] = 1'b0;
end

always @(*) begin
    intr_src_d[0] = int_pol[0] ? ( touch_btn[0] & ~intr_level_q[0]) : (~touch_btn[0] &  intr_level_q[0]);
    intr_src_d[1] = int_pol[1] ? ( touch_btn[1] & ~intr_level_q[1]) : (~touch_btn[1] &  intr_level_q[1]);
    intr_src_d[2] = int_pol[2] ? ( touch_btn[2] & ~intr_level_q[2]) : (~touch_btn[2] &  intr_level_q[2]);
    intr_src_d[3] = int_pol[3] ? ( touch_btn[3] & ~intr_level_q[3]) : (~touch_btn[3] &  intr_level_q[3]);
    intr_src_d[4] = int_pol[4] ? ( timer_int    & ~intr_level_q[4]) : (~timer_int    &  intr_level_q[4]);
    intr_src_d[5] = 1'b0;
end

always @(posedge clk) begin
    if(!resetn) begin
        intr_level_q <= 6'h0;
        intr_src_q   <= 6'h0;
    end
    else begin
        intr_level_q <= intr_level_d;
        intr_src_q   <= intr_src_d;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        int_state <= 32'h0;
    end
    else begin
        int_state[5:0] <= int_state[5:0] & ~int_clr[5:0];
        int_state[5:0] <= int_state[5:0] | int_set[5:0];

        if(int_edge[0]) int_state[0] <= (int_state[0] & ~int_clr[0]) | int_set[0] | intr_src_q[0];
        else            int_state[0] <= intr_level_d[0];
        if(int_edge[1]) int_state[1] <= (int_state[1] & ~int_clr[1]) | int_set[1] | intr_src_q[1];
        else            int_state[1] <= intr_level_d[1];
        if(int_edge[2]) int_state[2] <= (int_state[2] & ~int_clr[2]) | int_set[2] | intr_src_q[2];
        else            int_state[2] <= intr_level_d[2];
        if(int_edge[3]) int_state[3] <= (int_state[3] & ~int_clr[3]) | int_set[3] | intr_src_q[3];
        else            int_state[3] <= intr_level_d[3];
        if(int_edge[4]) int_state[4] <= (int_state[4] & ~int_clr[4]) | int_set[4] | intr_src_q[4];
        else            int_state[4] <= intr_level_d[4];
        if(int_edge[5]) int_state[5] <= (int_state[5] & ~int_clr[5]) | int_set[5] | intr_src_q[5];
        else            int_state[5] <= intr_level_d[5];
    end
end

assign int_req = |(int_state[5:0] & int_en[5:0]);

endmodule
