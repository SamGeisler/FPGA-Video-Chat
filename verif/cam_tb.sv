`timescale 1ns / 1ps

module cam_tb();

logic clk_100, reset;

logic capture;

logic c_PLK, c_VS, c_HS, c_SCL, c_XLK, c_RET, c_PWDN;
logic [7:0] c_D;



cam_top cti(.c_SDA(), .c_PLK, .c_VS, .c_HS, .c_SCL, .c_XLK, .c_RET, .c_PWDN, 
            .c_D, .clk_100, .reset, .capture,
            .hdmi_clk_n(), .hdmi_clk_p(), .hdmi_tx_n(), .hdmi_tx_p());


always begin
    clk_100 = 1;
    #5
    clk_100 = 0;
    #5;
end

always begin
    c_PLK =1;
    #12.5
    c_PLK = 0;
    #12.5;
end

int i;
int j;

initial begin
    reset = 1;
    #20
    reset = 0;
    #20
    capture = 1;
    c_VS = 0;
    c_HS = 0;
    c_D = 0;

    #20

    capture = 0;

    #30
    c_VS = 1;
    #30
    c_VS = 0;
    #30 
    
    for(i = 0; i < 480; i = i + 1) begin
        c_HS = 1;
        for(j = 0; j < 640; j = j + 1) begin
            @(posedge c_PLK)
            #10
            c_D = c_D + 1;
        end
        c_HS = 0;
        #20;
    end

    capture = 1;
    #50
    capture = 0;




    #100000000;
end

endmodule