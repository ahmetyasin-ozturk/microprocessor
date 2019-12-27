

module design2(grounds, display, clk);

output reg [3:0] grounds;
reg [3:0] grounds_before;
output reg [6:0] display;
input clk; 

reg [3:0] number[0:20];

reg [4:0] id_counter;
reg [4:0] last_counter_datas [4:0];
reg [3:0] data [3:0] ; //number to be printed on display
reg [1:0] count;       //which data byte to display.
reg [25:0] clk1;
reg [25:0] clk2;

wire a,b,c;
reg foo;

initial begin
    data[0]=4'ha;
    data[1]=4'ha;
    data[2]=4'ha;
    data[3]=4'ha;
	 id_counter = 0;
    count = 2'b0;
    grounds=4'b0001;
    clk1=0;
	 number[0] = 4'h1;
	 number[1] = 4'h5;
	 number[2] = 4'h0;		// 1501
	 number[3] = 4'h1;
	 
	 number[4] = 4'h1;
	 number[5] = 4'h6;		// 1606
	 number[6] = 4'h0;
	 number[7] = 4'h6;
	 
	 number[8] = 4'h8;
	 number[9] = 4'h1;		// 8150
	 number[10] = 4'h5;
	 number[11] = 4'h0;
	 
	 number[12] = 4'h1;
	 number[13] = 4'h1;		// 1160
	 number[14] = 4'h6;
	 number[15] = 4'h0;
	 
	 number[16] = 4'h0;
	 number[17] = 4'h7;
	 number[18] = 4'h1;
	 number[19] = 4'h5;
	 number[20] = 4'h0;

end

always @(a or b or c)
begin
if(a)
	foo = b^c;
else
	foo = b|c;
end

always @(posedge clk2[25])
begin
	
	
	data[0]=number[id_counter];
	data[1]=number[id_counter+1];
	data[2]=number[id_counter+2];
	data[3]=number[id_counter+3];
	id_counter = id_counter+1;
	if(id_counter == 18)
	begin
		id_counter = 0;
	end
	
end


always @(posedge clk)
begin
	 clk1<=clk1+1;
end

always @(posedge clk1[15]) //25 slow //19 wavy //15 perfect
begin
    grounds<={grounds[2:0],grounds[3]};
	 count<=count+1;
end

always @(posedge clk)
begin
    clk2<=clk2+1;
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



endmodule
