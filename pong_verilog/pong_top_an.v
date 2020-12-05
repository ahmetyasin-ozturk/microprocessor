4
(
	input wire clk,
	input wire [1:0] btn,
	output wire hsync, vsync,
	output wire [2:0] rgb
);


	// signal declaration
	wire [9:0] pixel_x, pixel_y;
	wire video_on, pixel_tick;
	reg [2:0] rgb_reg;
	wire [2:0] rgb_next;
	wire reset;
	// body
	// instantiate vga svnc circuit
	/*vga_sync vsync_unit(.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(pixel_tick), 
								.pixel_x(pixel_x), .pixel_y(pixel_y));*/
								
	vga_sync vsync_unit(.clk(clk), .reset(1'b0), .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(pixel_tick), 
								.pixel_x(pixel_x), .pixel_y(pixel_y));
	
	// instantiate graphic generator
	pong_graph_animate animated(.clk(clk), .reset_reg(reset), .btn(btn), .video_on(video_on), 
										.pix_x(pixel_x), .pix_y(pixel_y), .graph_rgb(rgb_next));
										
										
	// rgb buffer
	always @(posedge clk)
		if (pixel_tick)
			rgb_reg <= rgb_next;

	// output
	assign rgb = rgb_reg;
	
endmodule


module vga_sync
(
input wire clk, 
input wire reset,
output wire hsync, vsync, video_on, p_tick,
output wire [9:0] pixel_x, pixel_y
);


// constant declaration
// VGA 640_by_480 sync parameters
localparam HD = 640; // horizontal display area
localparam HF = 48; // h. front (left) border
localparam HB = 16; // h. back (right) border
localparam HR = 96; // h. retrace
localparam VD = 480; // vertical display area
localparam VF = 10; // v. front (top) border
localparam VB = 20; // v. back (bottom) border
localparam VR = 2; // v. retrace

// mod_2 counter
reg mod2_reg;
wire mod2_next;

// sync counters
reg [9:0] h_count_reg, h_count_next;
reg [9:0] v_count_reg, v_count_next;

// outpzit buffer
reg v_sync_reg, h_sync_reg;
wire v_sync_next, h_sync_next;

// status signal
wire h_end, v_end, pixel_tick;


// body
// registers
//always @(posedge clk, posedge reset)
always @(posedge clk)
	if (reset)
	begin 
		mod2_reg <= 1'b0;
		v_count_reg <= 0;
		h_count_reg <= 0;
		v_sync_reg <= 1'b0;
		h_sync_reg <= 1'b0;
	end
	else
	begin
		mod2_reg <= mod2_next;
		v_count_reg <= v_count_next;
		h_count_reg <= h_count_next;
		v_sync_reg <= v_sync_next;
		h_sync_reg <= h_sync_next;
	end 
	
// mod_2 circuit to generate 25 MHz enable tick
assign mod2_next = ~mod2_reg;
assign pixel_tick = mod2_reg;

// status signals
// end of horizontal counter (799)
assign h_end = (h_count_reg==(HD+HF+HB+HR-1));
// end of vertical counter (524)
assign v_end = (v_count_reg==(VD+VF+VB+VR-1));

// next_state logic of mod_800 horizontal sync counter
always @*
	if (pixel_tick) // 25 MHz pulse
		if (h_end)
			h_count_next = 0;
		else
			h_count_next = h_count_reg + 1;
	else
		h_count_next = h_count_reg;

// next_state logic of mod_525 vertical sync counter
always @*
	if (pixel_tick & h_end)
		if (v_end)
			v_count_next = 0;
		else
			v_count_next = v_count_reg + 1;
	else
		v_count_next = v_count_reg;


// horizontal and vertical sync, buffered to avoid glitch
// h_svnc_next asserted between 656 and 751
assign h_sync_next = (h_count_reg>=(HD+HB) && h_count_reg<=(HD+HB+HR-1));
// vh_sync_next asserted between 490 and 491
assign v_sync_next = (v_count_reg>=(VD+VB) && v_count_reg<=(VD+VB+VR-1)); 
// video on/off
assign video_on = (h_count_reg<HD) && (v_count_reg<VD);

// output
assign hsync = h_sync_reg;
assign vsync = v_sync_reg;
assign pixel_x = h_count_reg;
assign pixel_y = v_count_reg;
assign p_tick = pixel_tick;

endmodule 

	
module pong_graph_animate
(
input wire clk,
input wire video_on,
input wire [1:0] btn,
input wire [9:0] pix_x, pix_y, 
output reg [2:0] graph_rgb,
output reg reset_reg);

initial begin
	reset_reg <= 0;
	bar_y_reg <= 240 - BAR_Y_SIZE/2;
	ball_x_reg <= 320;
	ball_y_reg <= 240;
	counter <= 0;
	second_completed <= 0;
	half_min <= 0;
	x_delta_reg <= x_1;
	y_delta_reg <= y_1;
end

reg [25:0] second_completed;
reg [4:0] half_min;
//assign reset = reset_reg;
reg [1:0] counter;

reg [17:0] x_1 = 2;	//45
reg [17:0] y_1 = 2;
	
reg [17:0] x_2 = -2;	//135
reg [17:0] y_2 = 2;

reg [17:0] x_3 = -2;	//225
reg [17:0] y_3 = -2;

reg [17:0] x_4 = 2;	//315
reg [17:0] y_4 = -2;

// constant and signal declaration
// x, y coordinates (0,O) to (639,479)
localparam MAX_X = 640;
localparam MAX_Y = 480;
wire refr_tick;

// vertical stripe as a wall

// wall left , right boundary
localparam WALL_X_L = 0;
localparam WALL_X_R = 2;
// right vertical bar
//
// bar left , right boundary
localparam BAR_X_L = 600;
localparam BAR_X_R = 603;
// bar top, bottom boundary
wire [9:0] bar_y_t , bar_y_b;
reg [8:0] BAR_Y_SIZE = 280;
localparam bar_size_def = 280;
// register to track top boundary (x position is fixed)
reg [9:0] bar_y_reg, bar_y_next;
// bar moving velocity when a button is pressed
localparam BAR_V = 4;

// square ball
localparam BALL_SIZE = 8;
// ball left , right boundary
wire [9:0] ball_x_l , ball_x_r;
// ball top, bottom boundary
wire [9:0] ball_y_t , ball_y_b;
// reg to track left , top position
reg [9:0] ball_x_reg , ball_y_reg;
wire [9:0] ball_x_next , ball_y_next;
// reg to track ball speed
reg [9 :0] x_delta_reg , x_delta_next;
reg [9:0] y_delta_reg, y_delta_next;
// ball velocity can be pos or neg)
localparam BALL_V_P = 2;
localparam BALL_V_N = -2;
/*integer ball_v_p = 4;
integer ball_v_n = -4;*/

// round ball
wire [2:0] rom_addr, rom_col;
reg [7:0] rom_data;
wire rom_bit;

// object output signals 
wire wall_on, bar_on, sq_ball_on, rd_ball_on;
wire [2:0] wall_rgb, bar_rgb, ball_rgb;

// round ball image ROM
always @*
case (rom_addr)
	3'h0: rom_data = 8'b00111100; //    ****
	3'h1: rom_data = 8'b01111110; //   ******
	3'h2: rom_data = 8'b11111111; //  ********
	3'h3: rom_data = 8'b11111111; //  ********
	3'h4: rom_data = 8'b11111111; //  ********
	3'h5: rom_data = 8'b11111111; //  ********
	3'h6: rom_data = 8'b01111110; //   ******
	3'h7: rom_data = 8'b00111100; //    ****
endcase

// registers
//always @(posedge clk, posedge reset_reg)
always @(posedge clk)begin
	second_completed <= second_completed + 1;
	bar_y_reg <= 240 - BAR_Y_SIZE/2;
	if(second_completed == 49999999)begin
		half_min <= half_min+1;
		second_completed <= 0;
	end
	if(half_min == 29)begin
		BAR_Y_SIZE <= BAR_Y_SIZE/2;
		half_min <= 0;
	end
	if (reset_reg)
	begin
		counter <= counter + 1;
		BAR_Y_SIZE <= bar_size_def;
		bar_y_reg <= 240 - BAR_Y_SIZE/2;
		ball_x_reg <= 320;
		ball_y_reg <= 240;
		if(counter == 0)begin
			x_delta_reg <= x_1;
			y_delta_reg <= y_1;
		end
		else if(counter == 1)begin
			x_delta_reg <= x_2;
			y_delta_reg <= y_2;
		ends
		else if(counter == 2)begin
			x_delta_reg <= x_3;
			y_delta_reg <= y_3;
		end
		else begin
			x_delta_reg <= x_4;
			y_delta_reg <= y_4;
			counter <= 0;
		end
		
	end
	else
	begin
		bar_y_reg <= bar_y_next;
		ball_x_reg <= ball_x_next;
		ball_y_reg <= ball_y_next;
		x_delta_reg <= x_delta_next;
		y_delta_reg <= y_delta_next;
	end
end	
// refr_tick: I_clock tick asserted at start of v_sync
// i.e.. when the screen is refreshed (60 Hz)
assign refr_tick = (pix_y==481) && (pix_x==0);

// (wall) left vertical strip
// pixel within wall
assign wall_on = (WALL_X_L<=pix_x) && (pix_x<=WALL_X_R) ;
// wall rgb output
assign wall_rgb = 3'b110; // blue

// right vertical bar

// boundary 

assign bar_y_t = bar_y_reg;
assign bar_y_b = bar_y_t + BAR_Y_SIZE - 1;

// pixel within bar
assign bar_on = (BAR_X_L<=pix_x) && (pix_x<=BAR_X_R) && (bar_y_t <=pix_y) && (pix_y <=bar_y_b);

// bar rgb output
assign bar_rgb = 3'b010; // green

// new bar y_position
always @*
begin
	bar_y_next = bar_y_reg; // no move
	if (refr_tick)
		if (~btn[1] & (bar_y_b < (MAX_Y-1-BAR_V)))
			bar_y_next = bar_y_reg + BAR_V; // move down
		else if (~btn[0] & (bar_y_t > BAR_V))
			bar_y_next = bar_y_reg - BAR_V; // move up
end

// square ball
// boundary
assign ball_x_l = ball_x_reg;
assign ball_y_t = ball_y_reg;
assign ball_x_r = ball_x_l + BALL_SIZE - 1;
assign ball_y_b = ball_y_t + BALL_SIZE - 1;

// pixel within ball
assign sq_ball_on = (ball_x_l<=pix_x) && (pix_x <=ball_x_r) && (ball_y_t <=pix_y) && (pix_y <=ball_y_b);

// map current pixel location to ROM addr/col
assign rom_addr = pix_y [2:0] - ball_y_t [2:0];
assign rom_col = pix_x [2:0] - ball_x_l[2:0];
assign rom_bit = rom_data[rom_col];

// pixel within ball
assign rd_ball_on = sq_ball_on & rom_bit;

// ball rgb output
assign ball_rgb = 3'b100; // red

// new ball position
assign ball_x_next = (refr_tick) ? ball_x_reg+x_delta_reg : ball_x_reg ;
assign ball_y_next = (refr_tick) ? ball_y_reg+y_delta_reg : ball_y_reg ;

// new ball velocity
always @*
begin
	x_delta_next = x_delta_reg;
	y_delta_next = y_delta_reg;
	if (ball_y_t < 1) // reach top
		y_delta_next = BALL_V_P;
	else if (ball_y_b > (MAX_Y-1)) // reach bottom
		y_delta_next = BALL_V_N;
	else if (ball_x_l <= WALL_X_R) // reach wall 
		x_delta_next = BALL_V_P; // bounce back
	else if ((BAR_X_L<=ball_x_r) && (ball_x_r<=BAR_X_R) && (bar_y_t<=ball_y_b) && (ball_y_t<=bar_y_b)) // reach x of right bar and hit, ball bounce back
		x_delta_next = BALL_V_N;
	else if (ball_x_r > (MAX_X-1))
		reset_reg = 1;
	else
		reset_reg = 0;
		
end
//
// rgb multiplexing circuit

always @*
	if (~video_on)
		graph_rgb = 3'b000; // blank
	else
		if (wall_on)
			graph_rgb = wall_rgb;
		else if (bar_on)
			graph_rgb = bar_rgb;
		else if (rd_ball_on)
			graph_rgb = ball_rgb;
		else
			graph_rgb = 3'b110; // yellow background
endmodule	
	
	
	


