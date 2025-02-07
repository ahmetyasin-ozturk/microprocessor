
module main(input wire clk, output wire [3:0] grounds1, output wire [6:0] display1, output wire [3:0] rowwrite, input wire [3:0] colread);

reg [15:0] memory[0:3071];
reg [15:0] display1_data;	// for seven segment
wire [15:0] din, dout;
wire [11:0] addr_out;
reg [15:0] data_in, data_out;
wire mem_wrt;
wire [15:0] keypad_data;

// MAP MEMORY VALUES
localparam  MEM_END = 12'hC00;
localparam  KEYPAD_ADDR = 12'hC10;		
localparam  DISPLAY1_ADDR = 12'hC20;		
localparam  DISPLAY2_ADDR = 12'hC30; 

bird_CPU cpu(.clk(clk), .data_in(din), .data_out(dout), .addr_out(addr_out), .mem_wrt(mem_wrt));

sev_seg_disp monitor1(.din(display1_data), .grounds(grounds1), .display(display1), .clk(clk));

keypad kp(.rowwrite(rowwrite), .colread(colread), .dataout(keypad_data), .readyclr(addr_out==KEYPAD_ADDR), .a0(addr_out[0]), .clk(clk));

always @*  
begin
		if ( (12'h000<=addr_out) && (addr_out<=MEM_END) )
			data_in = memory[addr_out];
      else if ( (KEYPAD_ADDR<=addr_out) && (addr_out<=KEYPAD_ADDR+1) )
			data_in = keypad_data;
		else
			data_in = 16'hffff;	// for debugging 
end

assign din = data_in;
assign dout = data_out;

//multiplexer for cpu output
always @(posedge clk)
begin
	if(mem_wrt)
		if ( (12'h000<=addr_out) && (addr_out<=MEM_END) )
			memory[addr_out] <= data_out;
		else if (DISPLAY1_ADDR == addr_out)
			display1_data <= data_out;
end	

initial begin
 
     $readmemh("RAM", memory);  //must be exactly 3k locations	  
	    
end 
endmodule