// A writer, B reader

module dual_port_dist_ram #(

) (
    input  logic                              clk,

    // Port A
    input  logic                              ena,
    input  logic [1:0] wea,   // 1 write-enable bit per byte
    input  logic [16:0]             addra,
    input  logic [11:0]             dina,

    // Port B
    input  logic                              enb,
    input  logic [16:0]             addrb,
    output logic [11:0]             doutb
);

    localparam DATA_WIDTH = 12;
    localparam ADDR_WIDTH = 17;
    localparam DEPTH = 76800;

    logic [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // Port A Operations
    always_ff @(posedge clk) begin
        if (ena) begin
            if(wea[0]) 
                ram[addra][7:0] <= dina[7:0];
            
            if(wea[1])
                ram[addra][11:8] <= dina[11:8];
        end
    end

    // Port B Operations
    always_ff @(posedge clk) begin
        if (enb) begin
            // Output read data
            doutb <= ram[addrb];
        end
    end

endmodule