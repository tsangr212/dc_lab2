module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);

	localparam IDLE = 3'd0;
	localparam MP_pre = 3'd1;
	localparam MP = 3'd2;
	localparam MA_pre = 3'd3;
	localparam MA = 3'd4;
	localparam OUT = 3'd5;

	logic MP_start_r, MP_start_w; 
	// logic [269:0] MP_N_r, MP_N_w;
	// logic [269:0] MP_a_r, MP_a_w; 
	// logic [269:0] MP_b_r, MP_b_w;
	// logic [269:0] MP_k_r, MP_k_w;
	logic MP_finish; //wire
	logic [269:0] MP_data; //wire

	logic MA1_start_r, MA1_start_w;
	// logic [269:0] MA1_N_r, MA1_N_w;
	// logic [269:0] MA1_a_r, MA1_a_w;
	// logic [269:0] MA1_b_r, MA1_b_w;
	logic MA1_finish;
	logic [269:0] MA1_data;

	logic MA2_start_r, MA2_start_w;
	// logic [269:0] MA2_N_r, MA2_N_w;
	// logic [269:0] MA2_a_r, MA2_a_w;
	// logic [269:0] MA2_b_r, MA2_b_w;
	logic MA2_finish;
	logic [269:0] MA2_data;

	logic [8:0] counter_r, counter_w;	
	logic [3:0] state_r, state_w;
	logic [255:0] N_r, N_w; 
	logic [255:0] y_r, y_w;
	logic [255:0] d_r, d_w; 	
	logic [269:0] t_r, t_w;
	logic [269:0] m_r, m_w;	
	logic finish_r, finish_w;
	logic [269:0] data_r, data_w;


	MP MP1 (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(MP_start_r),
		.i_N(N_r),
		.i_a({1'd1,256'd0}),
		.i_b(y_r),
		.i_k(9'd257),
		.o_data(MP_data),
		.o_finish(MP_finish)
		
	);
	MA MA1 (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(MA1_start_r),
		.i_N(N_r),
		.i_a(m_r),
		.i_b(t_r),
		.o_data(MA1_data),
		.o_finish(MA1_finish)
	);
	MA MA2 (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(MA2_start_r),
		.i_N(N_r),
		.i_a(t_r),
		.i_b(t_r),
		.o_data(MA2_data),
		.o_finish(MA2_finish)
	);

	assign o_finished = finish_r;
	assign o_a_pow_d = data_r;
	always_comb begin //finish
		case (state_r)
			IDLE: begin
				finish_w = 0;
			end
			OUT: begin
				finish_w = 1'b1;
			end 
			default: begin
				finish_w = 0;
			end
		endcase
	end
	always_comb begin //MP, MA
		case (state_r)
			MP_pre: begin
				MP_start_w = 1'b1;
				MA1_start_w = 0;
				MA2_start_w = 0;
			end 
			MA_pre: begin
				MP_start_w = 0;
				MA1_start_w = 1'b1;
				MA2_start_w = 1'b1;
			end 
			default: begin
				MP_start_w = 0;
				MA1_start_w = 0;
				MA2_start_w = 0;
			end 
		endcase
	end
	always_comb begin //counter
		case (state_r)
			MA_pre: counter_w = counter_r;
			MA: begin
				if (counter_r<9'd255 && MA1_finish==1 && MA2_finish==1) counter_w = counter_r+1;
				else													counter_w = counter_r;
				// counter_w = (counter_r<9'd255 && MA1_finish==1 && MA2_finish==1) ? counter_r+1 : counter_r;
			end
			default: counter_w = 0; 
		endcase
	end
	always_comb begin //state
		state_w = state_r;
		case (state_r)
			IDLE: begin
				if(i_start) state_w = MP_pre;
				else state_w = IDLE;
				// state_w = (i_start==1'b1) ? (state_r + 1) : state_r;
			end
			MP_pre: state_w = MP;
			MP: begin
				if (MP_finish==1) state_w = MA_pre;
				else			  state_w = state_r;
				// state_w = (MP_finish==1) ? MA_pre:state_r;
			end
			MA_pre: state_w = MA;
			MA: begin
				if (MA1_finish==1 && MA2_finish==1) begin 
					if (counter_r==9'd255) state_w = OUT;
					else				   state_w = MA_pre;
					// state_w = (counter_r==9'd255) ? OUT : MA_pre;
				end
				else state_w = state_r;
			end
			OUT: state_w = IDLE;
			// default: 
		endcase
	end
	always_comb begin //produce			
		case (state_r)
			IDLE: begin
				N_w = i_n;
				y_w = i_a;
				d_w = i_d;
				t_w = 0;
				m_w = 1'd1;
				data_w = 0;
			end
			MP: begin
				N_w = N_r;
				y_w = y_r;
				d_w = d_r;
				if (MP_finish==1) t_w = MP_data;
				else			  t_w = t_r;
				// t_w = (MP_finish==1)? MP_data:t_r;
				m_w = m_r;
				data_w = 0;
			end
			MA: begin
				if(d_r[counter_r]==1'b1) begin
					if (MA1_finish==1) m_w = MA1_data;
					else m_w = m_r;
				end
				else m_w = m_r;
				if (MA2_finish==1) t_w = MA2_data;
				else			   t_w = t_r;
				// t_w = (MA2_finish==1)? MA2_data:t_r;
				N_w = N_r;
				y_w = y_r;
				d_w = d_r;
				data_w = 0;
			end
			OUT: begin
				N_w = N_r;
				y_w = y_r;
				d_w = d_r;
				t_w = 0;
				m_w = 0;
				data_w = m_r;
			end
			default: begin
				N_w = N_r;
				y_w = y_r;
				d_w = d_r;
				t_w = t_r;
				m_w = m_r;
				data_w = 0;
			end
		endcase
	end
	always_ff @( posedge i_clk or posedge i_rst ) begin
		if(i_rst) begin
			MP_start_r <= 0;
			MA1_start_r <= 0; 
			MA2_start_r <= 0;
			counter_r <= 0;
			state_r <= 0;
			N_r <= 0;
			y_r <= 0;
			d_r <= 0;
			t_r <= 0;
			m_r <= 0;
			finish_r <= 0;
			data_r <= 0; 
		end
		else begin
			MP_start_r <= MP_start_w;
			MA1_start_r <= MA1_start_w; 
			MA2_start_r <= MA2_start_w;
			counter_r <= counter_w;
			state_r <= state_w;
			N_r <= N_w;
			y_r <= y_w;
			d_r <= d_w;
			t_r <= t_w;
			m_r <= m_w;
			finish_r <= finish_w;
			data_r <= data_w; 
		end
	end
endmodule

module MP (
	input i_clk,
	input i_rst,
	input i_start,
	input [269:0] i_N,
	input [269:0] i_a,
	input [269:0] i_b,
	input [269:0] i_k,
	output [269:0] o_data,
	output o_finish
);
	localparam IDLE = 2'd0;
	localparam MP = 2'd1;
	// localparam MP2 = ;
	localparam OUT = 2'd2;
	// localparam BITS = 9'd256;
		
	logic [8:0] counter_r, counter_w;
	logic [1:0] state_r, state_w;
	logic [269:0] N_r, N_w;
	logic [269:0] a_r, a_w;
	logic [269:0] k_r, k_w; 
	logic [269:0] t_r, t_w;
	logic [269:0] m_r, m_w;	
	logic finish_r, finish_w;
	logic [269:0] data_r, data_w;

	assign o_finish = finish_r;
	assign o_data = data_r;
	always_comb begin //finish
		case (state_r)
			IDLE: begin
				finish_w = 0;
			end
			OUT: begin
				finish_w = 1'b1;
			end
			default: begin
				finish_w = 0;
			end
		endcase
	end
	always_comb begin //counter
		case (state_r)
			// IDLE: counter_w = 0;
			MP:  begin
				if (counter_r<k_r) counter_w = counter_r+1;
				else			   counter_w = counter_r;
				// counter_w = (counter_r<k_r) ? counter_r+1 : counter_r;
			end
			// OUT: counter_w = 0; 
			default: counter_w = 0;
		endcase
	end
	always_comb begin //state
		case (state_r)
			IDLE: begin
				if (i_start==1'b1) state_w = MP;
				else 			   state_w = state_r;
				// state_w = (i_start==1'b1) ? MP : state_r;
			end
			MP: begin
				if (counter_r==k_r) state_w = OUT;
				else				state_w = MP;
				// state_w = (counter_r==k_r) ? OUT : MP;
			end
			OUT: state_w = IDLE;
			// default: 
		endcase
	end
	always_comb begin //produce			
		case (state_r)
			IDLE: begin
				N_w = i_N;
				a_w = i_a;
				k_w = i_k;
				t_w = i_b;
				m_w = 0;
				data_w = 0;
			end
			MP: begin
				if(a_r[counter_r]==1'b1) begin
					if (m_r + t_r >= N_r) m_w = m_r + t_r - N_r;
					else 				  m_w = m_r + t_r;
					// m_w = (m_r + t_r >= N_r)? m_r + t_r - N_r : m_r + t_r;
				end
				else m_w = m_r;
				if(t_r + t_r > N_r) t_w = t_r + t_r - N_r;
				else 				t_w = t_r + t_r;
				// t_w = (t_r + t_r > N_r)? t_r + t_r - N_r : t_r + t_r;
				N_w = N_r;
				a_w = a_r;
				k_w = k_r;
				data_w = 0;
			end
			OUT: begin
				N_w = N_r;
				a_w = a_r;
				k_w = k_r;			
				t_w = 0;
				m_w = 0;
				data_w = m_r;
			end
		endcase
	end
	always_ff @( posedge i_clk or posedge i_rst ) begin
		if(i_rst) begin			
			counter_r <= 0;
			state_r <= 0;
			N_r <= 0;
			a_r <= 0;
			k_r <= 0;
			t_r <= 0;
			m_r <= 0;
			finish_r <= 0;
			data_r <= 0; 
		end
		else begin
			counter_r <= counter_w;
			state_r <= state_w;
			N_r <= N_w;
			a_r <= a_w;
			k_r <= k_w;
			t_r <= t_w;
			m_r <= m_w;
			finish_r <= finish_w;
			data_r <= data_w;
		end
	end
endmodule

module MA (
	input i_clk,
	input i_rst,
	input i_start,
	input [269:0] i_N,
	input [269:0] i_a,
	input [269:0] i_b,
	output [269:0] o_data,
	output o_finish
);
	localparam IDLE = 3'd0;
	localparam ONE = 3'd1;
	localparam ODD = 3'd2;
	localparam SHFT = 3'd3;
	localparam OUT = 3'd4;

	logic [8:0] counter_r, counter_w;
	logic [2:0] state_r, state_w;
	logic [269:0] N_r, N_w;
	logic [269:0] a_r, a_w;
	logic [269:0] b_r, b_w; 
	logic [269:0] m_r, m_w;	
	logic finish_r, finish_w;
	logic [269:0] data_r, data_w;

	assign o_finish = finish_r;
	assign o_data = data_r;
	always_comb begin //finish
		case (state_r)
			IDLE: begin
				finish_w = 0;
			end
			OUT: begin
				finish_w = 1'b1;
			end
			default: begin
				finish_w = 0;
			end
		endcase
	end
	always_comb begin //counter
		case (state_r)
			// IDLE: counter_w = 0;
			ONE:  counter_w = counter_r;
			ODD: counter_w = counter_r;
			SHFT: begin
				if (counter_r<9'd255) counter_w = counter_r+1;
				else				  counter_w = counter_r;
			// counter_w = (counter_r<9'd255) ? counter_r+1 : counter_r;
			end
			// OUT: counter_w = 0; 
			default: counter_w = 0; 
		endcase
	end
	always_comb begin //state
		case (state_r)
			IDLE: begin
				if (i_start==1'b1) state_w = ONE;
				else			   state_w = state_r;
			// state_w = (i_start==1'b1) ? ONE : state_r;
			end
			ONE: state_w = ODD;
			ODD: state_w = SHFT;
			SHFT: begin 
				if (counter_r==9'd255) state_w = OUT;
				else state_w = ONE;
				// state_w = (counter_r==9'd257) ? OUT : ONE;
			end
			OUT: state_w = IDLE;
			// default: 
		endcase
	end
	always_comb begin //produce			
		case (state_r)
			IDLE: begin
				N_w = i_N;
				a_w = i_a;
				b_w = i_b;
				m_w = 0;
				data_w = 0;
			end
			ONE: begin
				N_w = N_r;
				a_w = a_r;
				b_w = b_r;
				if (a_r[counter_r]==1'b1) m_w = m_r + b_r;
				else					  m_w = m_r;
				// m_w = (a_r[counter_r]==1'b1)? m_r + b_r : m_r;
				data_w = 0;
			end
			ODD: begin
				N_w = N_r;
				a_w = a_r;
				b_w = b_r;
				if (m_r[0]==1) m_w = m_r + N_r;
				else		   m_w = m_r;
				// m_w = (m_r[0]==1)? m_r + N_r : m_r;
				data_w = 0;
			end
			SHFT: begin
				N_w = N_r;
				a_w = a_r;
				b_w = b_r;
				m_w = m_r >> 1;
				data_w = 0;
			end
			OUT: begin
				N_w = N_r;
				a_w = a_r;
				b_w = b_r;
				m_w = 0;
				if (m_r >= N_r) data_w = m_r - N_r;
				else			data_w = m_r;
				// data_w = (m_r >= N_r)? m_r - N_r : m_r;
			end
		endcase
	end
	always_ff @( posedge i_clk or posedge i_rst ) begin
		if(i_rst) begin
			counter_r <= 0;
			state_r <= 0;
			N_r <= 0;
			a_r <= 0;
			b_r <= 0;
			m_r <= 0;
			finish_r <= 0;
			data_r <= 0; 
		end
		else begin
			counter_r <= counter_w;
			state_r <= state_w;
			N_r <= N_w;
			a_r <= a_w;
			b_r <= b_w;
			m_r <= m_w;
			finish_r <= finish_w;
			data_r <= data_w; 
		end
	end
endmodule
