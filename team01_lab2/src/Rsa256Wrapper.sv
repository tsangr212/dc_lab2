module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest,
	 output run_ready,
	 output processing,
	 output communicating
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
localparam S_GET_KEY = 0;
localparam S_GET_DATA = 1;
localparam S_WAIT_CALCULATE = 2;
localparam S_SEND_DATA = 3;
localparam S_WAIT_RX = 4;
localparam S_WAIT_TX = 5;

localparam MAXBYTE = 32;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [2:0] state_r, state_w;
logic [7:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;
logic keyready_r,keyready_w;
logic dataready_r,dataready_w;
logic [31:0] time_counter_r,time_counter_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8]; //[247:240]

assign run_ready = (keyready_r == 0);
assign processing = (state_r == S_WAIT_CALCULATE);
assign communicating = (state_r != S_WAIT_CALCULATE);


Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask


//Read bytes
always_comb begin
    //default condition
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    state_w = state_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = rsa_start_r;
    keyready_w = keyready_r;
    dataready_w = dataready_r;
	 time_counter_w = time_counter_r;

    if(avm_waitrequest && (state_r != S_WAIT_CALCULATE)) begin          //warning: states don't depend on I/O should be excluded
        state_w = state_r;
		  if (state_r == S_WAIT_RX) time_counter_w = time_counter_r + 1;
    end
    else begin
        case (state_r) 
            S_WAIT_RX: begin
                 //confirm RX ready
                if ((avm_readdata[RX_OK_BIT]) && (avm_address_r == STATUS_BASE)) begin
                    StartRead(RX_BASE);
                        if(!keyready_r) begin
                            state_w = S_GET_KEY;
									 time_counter_w = 0;
								end
                        else begin
                            state_w = S_GET_DATA;
									 time_counter_w = 0;
								end
                end
					 else begin
						 state_w = state_r;
                   StartRead(STATUS_BASE);
																			//counter for end protocol 
							
						 if(time_counter_r >= 50000000) begin
							  dataready_w = 0;
							  state_w = S_WAIT_RX;
							  keyready_w = 0;
							  dec_w = 0;
						 end
						 else begin
							  time_counter_w = time_counter_r + 1;
						 end
						 
					 end
					 
            end

            S_WAIT_TX: begin
                 //confirm RX ready
                if ((avm_readdata[TX_OK_BIT]) && (avm_address_r == STATUS_BASE)) begin
                    StartWrite(TX_BASE);
                    state_w = S_SEND_DATA;
                end
                else begin
                    state_w = state_r;
                    StartRead(STATUS_BASE);
                end
            end

            S_GET_KEY: begin
                
                //update input data
                if (bytes_counter_r < 32) begin //0~31
                    n_w = (n_r << 8) | avm_readdata[7:0];
                end
                else begin //32~63
                    d_w = (d_r << 8) | avm_readdata[7:0];
                end
                
                StartRead(STATUS_BASE); //go back to confirm TX
                state_w = S_WAIT_RX;
                

                if (bytes_counter_r >= 63) begin //counter
                    bytes_counter_w = 0;
                    keyready_w = 1;
                end
                else begin
                    bytes_counter_w = bytes_counter_r + 1;
                end
            end
            
            S_GET_DATA: begin
                enc_w = (enc_r << 8) | avm_readdata[7:0]; //0~31
                StartRead(STATUS_BASE);
                state_w = S_WAIT_RX;

                if (bytes_counter_r >= 31) begin //counter
                    bytes_counter_w = 0;
                    if(enc_w == {32{8'h40}}) begin             // new protocol: transmit ends (work)
                        dataready_w = 0;
                        state_w = S_WAIT_RX;
                        keyready_w = 0;
                        dec_w = 0;
                        
                    end
                    else begin
                        dataready_w = 1;
                        rsa_start_w = 1;
                        state_w = S_WAIT_CALCULATE;
                    end

                end
                else begin
                    bytes_counter_w = bytes_counter_r + 1;
                end
            end

            S_WAIT_CALCULATE: begin
                rsa_start_w = 0;
                if (rsa_finished) begin
                    dec_w = rsa_dec;     //catch output from core
                    state_w = S_WAIT_TX;  
                    
                    dataready_w = 0;
                end
                else begin
                    state_w = state_r;  
                end
            end

            S_SEND_DATA: begin
                dec_w = dec_r << 8; //[247:240]
                StartRead(STATUS_BASE);
                state_w = S_WAIT_TX;

                if (bytes_counter_r >= 30) begin //counter (only 31 cycles)
                    bytes_counter_w = 0;
                    state_w = S_WAIT_RX;
                    dec_w = 0;
                    enc_w = 0;

                    // end of this FSM cycle
                end
                else begin
                    bytes_counter_w = bytes_counter_r + 1;
                end
            end
        endcase
    end
end
    


always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_WAIT_RX;
        bytes_counter_r <= 0;
        rsa_start_r <= 0;
        keyready_r <= 0;
        dataready_r <= 0;
		  time_counter_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
        keyready_r <= keyready_w;
        dataready_r <= dataready_w;
		  time_counter_r <= time_counter_w;
    end
end

endmodule
