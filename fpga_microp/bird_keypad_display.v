module runner(input wire clk, output wire [3:0] grounds1, output wire [6:0] display1, output wire [3:0] rowwrite, input wire [3:0] colread, output wire [3:0] grounds2, output wire [6:0] display2);

//reg [15:0] memory[0:3071];
reg [15:0] memory[0:511];
reg [15:0] display1_data;	// for seven segment
wire [15:0] din, dout;
wire [11:0] addr_out;
reg [15:0] data_in, data_out;
wire mem_wrt;
wire [15:0] keypad_data;
reg [11:0] DEBUG;



// MAP MEMORY VALUES

localparam  MEM_END = 12'h700;
localparam  KEYPAD_ADDR = 12'h710;		
localparam  DISPLAY1_ADDR = 12'h730;

//localparam  DISPLAY2_ADDR = 12'hC30; 

reg [25:0] clk1;

always @(posedge clk)
    clk1<=clk1+1;
	 
	 

bird_CPU cpu(.clk(clk), .data_in(din), .data_out(dout), .addr_out(addr_out), .mem_wrt(mem_wrt), .grounds2(grounds2), .display2(display2));
//bird_CPU cpu(.clk(clk1[25]), .data_in(din), .data_out(dout), .addr_out(addr_out), .mem_wrt(mem_wrt));


//sev_seg_disp_slowed monitor1(.din(addr_out), .grounds(grounds1), .display(display1), .clk(clk1[15]));

sev_seg_disp monitor1(.din(data_out), .grounds(grounds1), .display(display1), .clk(clk));
//sev_seg_disp monitor2(.din(DEBUG), .grounds(grounds2), .display(display2), .clk(clk));

keypad kp(.rowwrite(rowwrite), .colread(colread), .dataout(keypad_data), .readyclr(addr_out==KEYPAD_ADDR), .a0(addr_out[0]), .clk(clk));


always @*  
begin
		if ( (12'h000<=addr_out)&&(addr_out<MEM_END) )begin
			data_in = memory[addr_out];
			//DEBUG = 12'heee;
			end
      else if ( (KEYPAD_ADDR==addr_out) )begin
			data_in = keypad_data;
			//DEBUG = 12'haaa;
			end
		else begin
			data_in = 16'hffff;	// for debugging
			//DEBUG = 12'hccc;
			end
end

assign din = data_in;
assign dout = data_out;

//multiplexer for cpu output
always @(posedge clk)
begin
//DEBUG = 12'h999;
	if(mem_wrt)begin
		if ( (12'h000<=addr_out)&&(addr_out<MEM_END) )begin
			memory[addr_out] <= data_out;
			DEBUG <= 12'hbbb;end
		else if (DISPLAY1_ADDR == addr_out)begin
			display1_data <= data_out;
			DEBUG <= 12'heee;end
	end
	else begin
		DEBUG <= 12'h111;end
end

initial begin
 
     $readmemh("RAM", memory);  //must be exactly 3k locations	 /// changed to 512  
	  clk1 = 0;
	  display1_data = 16'hcccc;
	  DEBUG =  12'h222;
end 
endmodule


module bird_CPU(input wire clk, input wire [15:0] data_in, output reg [15:0] data_out, output reg [11:0] addr_out, output wire mem_wrt, output wire [3:0] grounds2, output wire [6:0] display2);


reg [3:0] state;
reg [3:0] next_state;

reg [15:0] regbank[0:7];
wire[15:0] aluin1, aluin2;
reg ZF;
reg [15:0] pc, aluout, ir;
wire zfout;

reg [11:0] debugger;

localparam  FETCH = 4'b0000;
localparam  LDI = 4'b0001;
localparam  LD = 4'b0010;
localparam  ST = 4'b0011;
localparam  JZ = 4'b0100;
localparam  JMP = 4'b0101;
localparam  ALUIMM = 4'b0110;
localparam  ALU = 4'b0111;
localparam  PSH = 4'b1000;
localparam  POP1 = 4'b1001;
localparam  CALL = 4'b1010;
localparam  RET1 = 4'b1011;
localparam  POP2 = 4'b1100;
localparam  RET2 = 4'b1101;


	
 always @(posedge clk)
    case(state)
    
        FETCH: 
        begin
            //state<=data_in[15:12];
            ir<=data_in[11:0];
            pc<=pc+1;
        end

        LDI:
        begin
            //state<=FETCH;
            regbank[ ir[2:0] ] <= data_in;
            pc<=pc+1;
        end

        LD:
        begin
            regbank[ ir[2:0] ] <= data_in;
        end
        ST:
        begin
            data_out<=regbank[ir[5:3]];
        end
  
        JMP:
        begin
            pc<=ir+pc;
        end
        ALU:
        begin
            regbank[ ir[2:0] ] <= aluout;   
            ZF<=zfout; 
        end
        PSH:
        begin
            data_out <= regbank[ir[5:3]];
            regbank[7] <= regbank[7] - 1;  
        end
        POP1:
        begin
            regbank[7] <= regbank[7] + 1;
        end
        POP2:
        begin
            regbank[ir[2:0]]<=data_in;
        end
        CALL:
        begin
            data_out<=pc;
            pc<=pc+ir;
            regbank[7] <= regbank[7] - 1;
        end
        RET1:
        begin
            regbank[7] <= regbank[7] + 1;
        end
        RET2:
        begin
            pc<=data_in;
        end
    endcase
	 
always@*
	case(state)
	
		FETCH:	
		begin
			next_state = data_in[15:12];
		end
		
		JZ:		
		begin
			if(ZF)
				next_state = JMP;
			else
				next_state = FETCH;
		end
		
		POP1:
		begin
			next_state = POP2;
		end
		
		RET1:
		begin
			next_state = RET2;
		end
		
		default	next_state = FETCH;
	endcase
		
		
always @(posedge clk)
	state <= next_state;
	 
	 

	 
always @*
		case(state)
		
			LD:
			begin
				addr_out = regbank[ir[8:6]][11:0];
			end
			
			ST:
			begin
				addr_out = regbank[ir[8:6]][11:0];
				//mem_wrt = 1;
				debugger = 12'haaa;
			end
			
			POP2:
			begin
				addr_out = regbank[7][11:0];
			end
			
			RET2:
			begin
				addr_out = regbank[7][11:0];
			end
			
			default:
			begin	
			addr_out = pc;
			//mem_wrt = 0;
			//debugger = 12'hccc;
			end
		endcase	 
	 
assign mem_wrt = ((state == ST) || (state == PSH));
//assign mem_wrt = (state == ST) ? 1'b1 : 1'b0;
//assign mem_wrt = ((state == ST));
assign zero_result = ~|aluout;
assign aluin2 = regbank[ir[5:3]];
assign aluin1 = regbank[ir[8:6]];
 
 always@*
		case(ir[11:9])
			
			3'h0:	aluout = aluin1 + aluin2;
			3'h1:	aluout = aluin1 - aluin2;
			3'h2: aluout = aluin1 & aluin2;
			3'h3: aluout = aluin1 | aluin2;
			3'h4: aluout = aluin1 ^ aluin2;
			3'h5: aluout = 0;
			3'h6: aluout = 0;
			3'h7:
			begin
				case(ir[8:6])
					
					3'h0: aluout = ~aluin1;
					3'h1: aluout = aluin1;
					3'h2: aluout = aluin1 + 16'h0001;
					3'h3: aluout = aluin1 - 16'h0001;
					default: aluout = 0;
				endcase
			end
			
		endcase
 
 //sev_seg_disp monitor2(.din(regbank[1]), .grounds(grounds2), .display(display2), .clk(clk));
 sev_seg_disp_slowed monitor2(.din(regbank[2]), .grounds(grounds2), .display(display2), .clk(clk));
 //sev_seg_disp monitor2(.din(data_out), .grounds(grounds2), .display(display2), .clk(clk));

 
 initial begin
     state = FETCH;
	  
	  //regbank[7] = SP_ADDR;			// IT WILL BE WRITTEN ON PROGRAM, NO NEED I GUESS

	    
 end 
 
 endmodule
 
 
module sev_seg_disp_slowed( din, grounds, display, clk);

input wire [15:0] din;
output reg [3:0] grounds;
output reg [6:0] display;
input clk; 

reg [3:0] data [3:0] ; //number to be printed on display
reg [1:0] count;       //which data byte to display.


always @(posedge clk)begin
	grounds<={grounds[2:0],grounds[3]};
   count<=count+1;
end

always @(*)
    case(data[count])
        0:display=~(7'b1111110); 	//	starts with a, ends with g
        1:display=~(7'b0110000);		 
        2:display=~(7'b1101101);
        3:display=~(7'b1111001);
        4:display=~(7'b0110011);
        5:display=~(7'b1011011);
        6:display=~(7'b1011111);
        7:display=~(7'b1110000);
        8:display=~(7'b1111111);
        9:display=~(7'b1111011);
        'ha:display=~(7'b1110111);
        'hb:display=~(7'b0011111);
        'hc:display=~(7'b1001110);
        'hd:display=~(7'b0111101);
        'he:display=~(7'b1001111);
        'hf:display=~(7'b1000111);
        default display=~(7'b1111111);
    endcase

  always @*
    begin
    data[0]=din[15:12];
    data[1]=din[11:8];
    data[2]=din[7:4];
    data[3]=din[3:0];
    end

initial begin
    data[0]=4'h1;
    data[1]=4'h9;
    data[2]=4'ha;
    data[3]=4'hc;
    count = 2'b0;
    grounds=4'b0001;
end

endmodule


module sev_seg_disp( din, grounds, display, clk);

input wire [15:0] din;
output reg [3:0] grounds;
output reg [6:0] display;
input clk; 

reg [3:0] data [3:0] ; //number to be printed on display
reg [1:0] count;       //which data byte to display.
reg [25:0] clk1;

always @(posedge clk1[15]) //25 slow //19 wavy //15 perfect
begin
    grounds<={grounds[2:0],grounds[3]};
    count<=count+1;
end

always @(posedge clk)
    clk1<=clk1+1;

always @(*)
    case(data[count])
        0:display=~(7'b1111110); 	//	starts with a, ends with g
        1:display=~(7'b0110000);		 
        2:display=~(7'b1101101);
        3:display=~(7'b1111001);
        4:display=~(7'b0110011);
        5:display=~(7'b1011011);
        6:display=~(7'b1011111);
        7:display=~(7'b1110000);
        8:display=~(7'b1111111);
        9:display=~(7'b1111011);
        'ha:display=~(7'b1110111);
        'hb:display=~(7'b0011111);
        'hc:display=~(7'b1001110);
        'hd:display=~(7'b0111101);
        'he:display=~(7'b1001111);
        'hf:display=~(7'b1000111);
        default display=~(7'b1111111);
    endcase

  always @*
    begin
    data[0]=din[15:12];
    data[1]=din[11:8];
    data[2]=din[7:4];
    data[3]=din[3:0];
    end

initial begin
    data[0]=4'h1;
    data[1]=4'h9;
    data[2]=4'ha;
    data[3]=4'hc;
    count = 2'b0;
    grounds=4'b0001;
    clk1=0;
end

endmodule




module keypad(rowwrite, colread, dataout, readyclr, a0, clk);
	output reg [3:0] rowwrite;
	input wire [3:0] colread;
	output reg [15:0] dataout;
	input wire readyclr;
	input wire a0;
	input wire clk;
	
	reg [3:0] keyread;
	reg rowpressed;
	reg [3:0] rows;
	wire keypadpressed;
	reg [41:0] stable;
	wire stablefor21scans;
	reg [25:0] clk1;
	reg [15:0] data;
	reg [1:0] readytemp_acc;
	reg ready;
	
	always @(posedge clk)
		clk1 <= clk1+1;
		
	
	always @(posedge clk1[14])
		rowwrite <= {rowwrite[2:0], rowwrite[3]};
		
	always @(*)
	begin
		// check first row pressed
		if(rowwrite == 4'b1110 && colread == 4'b1110)
		begin
			keyread = 4'h1;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1110 && colread == 4'b1101)
		begin
			keyread = 4'h2;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1110 && colread == 4'b1011)
		begin
			keyread = 4'h3;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1110 && colread == 4'b0111)
		begin
			keyread = 4'ha;
			rowpressed = 1'b1;
		end
		
		// check second row pressed
		else if(rowwrite == 4'b1101 && colread == 4'b1110)
		begin
			keyread = 4'h4;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1101 && colread == 4'b1101)
		begin
			keyread = 4'h5;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1101 && colread == 4'b1011)
		begin
			keyread = 4'h6;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1101 && colread == 4'b0111)
		begin
			keyread = 4'hb;
			rowpressed = 1'b1;
		end
		
		// check third row pressed
		else if(rowwrite == 4'b1011 && colread == 4'b1110)
		begin
			keyread = 4'h7;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1011 && colread == 4'b1101)
		begin
			keyread = 4'h8;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1011 && colread == 4'b1011)
		begin
			keyread = 4'h9;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b1011 && colread == 4'b0111)
		begin
			keyread = 4'hc;
			rowpressed = 1'b1;
		end
		
		// check fourth row pressed
		else if(rowwrite == 4'b0111 && colread == 4'b1110)
		begin
			keyread = 4'he;	// star, e = *
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b0111 && colread == 4'b1101)
		begin
			keyread = 4'h0;
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b0111 && colread == 4'b1011)
		begin
			keyread = 4'hf;	// hashtag, f = #
			rowpressed = 1'b1;
		end
		
		else if(rowwrite == 4'b0111 && colread == 4'b0111)
		begin
			keyread = 4'hd;
			rowpressed = 1'b1;
		end
		
		// if key not pressed
		else
		begin
			keyread = 4'hf; // default value
			rowpressed = 1'b0;
		end
	end
	
	always @(posedge clk1[14])
	begin
		rows <= {rows[2:0], rowpressed};
		if (rowpressed == 1'b1)
			data <= keyread;
	end
	
	assign keypadpressed =| rows;	// to realize if any of the rows pressed
	
	always @(posedge clk1[14])
		stable <= {stable[40:0], keypadpressed};	//for bouncing
		
	assign stablefor21scans = &stable;
	
	/*always @(posedge clk)
	begin
		readytemp_acc <= {readytemp_acc[0], stablefor21scans};
	end*/
	
	always @(posedge clk)
	begin
		readytemp_acc <= {readytemp_acc[0], stablefor21scans};
		if(!readytemp_acc[1] && readytemp_acc[0])
			ready <= 1;
		else if(readyclr)
			ready <= 0;
	end
	
	always @(*)
	begin
		if(!a0)
			dataout <= {12'b0, data};
		else
			dataout <= {13'b0, ready, 2'b0};
	end
	
	initial begin
		rowwrite = 4'b0111;
		ready = 1'b0;
	end
	
endmodule	

 