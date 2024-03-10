// micro68k (reduced Motorola 68000) FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2024 by Michael Kohn

module micro68k
(
  output [7:0] leds,
  output [3:0] column,
  input raw_clk,
  output eeprom_cs,
  output eeprom_clk,
  output eeprom_di,
  input  eeprom_do,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  input  button_reset,
  input  button_halt,
  input  button_program_select,
  input  button_0,
  output spi_clk,
  output spi_mosi,
  input  spi_miso
);

// iceFUN 8x4 LEDs used for debugging.
reg [7:0] leds_value;
reg [3:0] column_value;

assign leds = leds_value;
assign column = column_value;

// Memory bus (ROM, RAM, peripherals).
reg [15:0] mem_address = 0;
reg [15:0] mem_write = 0;
reg [1:0] mem_write_mask = 0;
wire [15:0] mem_read;
//wire mem_data_ready;
reg mem_bus_enable = 0;
reg mem_write_enable = 0;

//wire [7:0] mem_debug;

// Clock.
reg [21:0] count = 0;
reg [19:0] clock_div;
reg [14:0] delay_loop;
wire clk;
assign clk = clock_div[1];

// Registers.
reg [31:0] data [7:0];
reg [31:0] address [7:0];
reg [15:0] pc = 0;
reg [15:0] pc_current = 0;

// Instruction
reg [15:0] instruction;
//reg [31:0] extra;
reg [31:0] arg1;
reg [2:0] arg1_reg;
//reg [31:0] source;
reg [31:0] temp;
reg [5:0] ea_code;
wire [2:0] op_reg;
wire [2:0] op_mode;
wire [2:0] ea_mode;
wire [2:0] ea_reg;
assign op_reg = instruction[11:9];
assign op_mode = instruction[8:6];
assign ea_mode = ea_code[5:3];
assign ea_reg  = ea_code[2:0];
reg is_address = 0;
reg is_immediate = 0;
reg [2:0] size = 0;
reg direction = 0;
reg is_lea;
reg do_branch;
reg [5:0] shift_count;
reg [2:0] shift_type;
wire[1:0] shift_size;
assign shift_size = instruction[7:6];

// When temp is loaded with ea data for (d8,PC,Xn * scale)
// Extra word is:
// 0 r r r  s X X X  d d d d d d d d
// r = the Xn register
// s = size (w or l)
// X = scale value (1, 2, 4)
// d = signed d8 displacement
wire [3:0] xn_reg;
wire xn_size;
wire [2:0] xn_scale;
wire signed [7:0] xn_disp;
assign xn_reg = temp[14:12];
assign xn_size = temp[11];
assign xn_scale = temp[10:8];
assign xn_disp = temp[7:0];

// ALU.
reg [2:0] dest_reg;
reg [3:0] alu_op = 0;
reg [31:0] dest_value;
reg [32:0] result;

// State.
reg [5:0] state = 0;
reg [5:0] state_after_fetch_data = 0;
reg [5:0] state_after_ea = 0;
reg mem_count = 0;
reg mem_last = 0;

// Effective Address.
reg [31:0] ea;
reg [31:0] ea_value;
reg [31:0] ea_wb;

// Flags.
reg [15:0]flags;

parameter FLAG_EXTEND   = 4;
parameter FLAG_NEGATIVE = 3;
parameter FLAG_ZERO     = 2;
parameter FLAG_OVERFLOW = 1;
parameter FLAG_CARRY    = 0;

// Eeprom.
reg [10:0] eeprom_count;
wire [7:0] eeprom_data_out;
reg  [7:0] eeprom_holding [3:0];
reg [10:0] eeprom_address;
reg [15:0] eeprom_mem_address;
reg eeprom_strobe = 0;
wire eeprom_ready;

// Debug.
//reg [7:0] debug_0 = 0;
//reg [7:0] debug_1 = 0;
//reg [7:0] debug_2 = 0;
//reg [7:0] debug_3 = 0;

// This block is simply a clock divider for the raw_clk.
always @(posedge raw_clk) begin
  count <= count + 1;
  clock_div <= clock_div + 1;
end

// Debug: This block simply drives the 8x4 LEDs.
always @(posedge raw_clk) begin
  case (count[9:7])
    //3'b000: begin column_value <= 4'b0111; leds_value <= ~instruction[7:0]; end
    3'b000: begin column_value <= 4'b0111; leds_value <= ~data[0][7:0]; end
    //3'b000: begin column_value <= 4'b0111; leds_value <= ~flags[7:0]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~instruction[15:8]; end
    3'b010: begin column_value <= 4'b1011; leds_value <= ~data[0][15:8]; end
    //3'b010: begin column_value <= 4'b1011; leds_value <= ~flags[15:8]; end
    3'b100: begin column_value <= 4'b1101; leds_value <= ~pc[7:0]; end
    3'b110: begin column_value <= 4'b1110; leds_value <= ~state; end
    default: begin column_value <= 4'b1111; leds_value <= 8'hff; end
  endcase
end

parameter STATE_RESET =        0;
parameter STATE_DELAY_LOOP =   1;
parameter STATE_FETCH_OP_0 =   2;
parameter STATE_FETCH_OP_1 =   3;
parameter STATE_START_DECODE = 4;

parameter STATE_FETCH_DATA_0 = 5;
parameter STATE_FETCH_DATA_1 = 6;
parameter STATE_FETCH_EA_0 =   7;
parameter STATE_FETCH_EA_1 =   8;
parameter STATE_WRITE_EA_0 =   9;
parameter STATE_WRITE_EA_1 =   10;

parameter STATE_COMPUTE_EA_0 = 11;
parameter STATE_COMPUTE_EA_1 = 12;
parameter STATE_COMPUTE_EA_2 = 13;

parameter STATE_ALU_IMM_0 =    14;
parameter STATE_ALU_IMM_1 =    15;
parameter STATE_ALU_CCR =      16;
parameter STATE_ALU_0 =        17;
parameter STATE_ALU_1 =        18;
parameter STATE_ALU_2 =        19;
parameter STATE_ALU_3 =        20;
parameter STATE_ALU_4 =        21;
parameter STATE_ALU_WB =       22;
parameter STATE_ALU_WB_MEM =   23;

parameter STATE_MOVE_0 =       24;
parameter STATE_MOVE_1 =       25;
parameter STATE_EXT =          26;
parameter STATE_SHIFT_0 =      27;
parameter STATE_SHIFT_1 =      28;
parameter STATE_SHIFT_2 =      29;
parameter STATE_BRANCH_0 =     30;
parameter STATE_BRANCH_1 =     31;
parameter STATE_PUSH_TEMP_0 =  32;
parameter STATE_PUSH_TEMP_1 =  33;
parameter STATE_POP_PC_0 =     34;
parameter STATE_POP_PC_1 =     35;
parameter STATE_SWAP =         37;
parameter STATE_BIT_UPDATE   = 38;

parameter STATE_ALU_QUICK_0  = 39;

parameter STATE_HALTED =       57; // 0x39
parameter STATE_ERROR =        58; // 0x3a
parameter STATE_EEPROM_START = 59;
parameter STATE_EEPROM_READ =  60;
parameter STATE_EEPROM_WAIT =  61;
parameter STATE_EEPROM_WRITE = 62;
parameter STATE_EEPROM_DONE =  63;

parameter ALU_OR  = 0;
parameter ALU_AND = 1;
parameter ALU_SUB = 2;
parameter ALU_ADD = 3;
parameter ALU_BIT = 4;
parameter ALU_EOR = 5;
parameter ALU_CMP = 6;
parameter ALU_MOV = 7;
parameter ALU_JMP = 8;
parameter ALU_JSR = 9;
parameter ALU_LEA = 10;
parameter ALU_CLR = 11;
parameter ALU_NEG = 12;
parameter ALU_SR  = 13;
//parameter ALU_ADDQ = 14;

task set_flags8_nocf(input [8:0] data);
  flags[FLAG_NEGATIVE] <= data[7];
  flags[FLAG_ZERO]     <= data[7:0] == 0;
  flags[FLAG_OVERFLOW] <= 0;
  flags[FLAG_CARRY]    <= 0;
endtask

task set_flags16_nocf(input [16:0] data);
  flags[FLAG_NEGATIVE] <= data[15];
  flags[FLAG_ZERO]     <= data[15:0] == 0;
  flags[FLAG_OVERFLOW] <= 0;
  flags[FLAG_CARRY]    <= 0;
endtask

task set_flags32_nocf(input [32:0] data);
  flags[FLAG_NEGATIVE] <= data[31];
  flags[FLAG_ZERO]     <= data[31:0] == 0;
  flags[FLAG_OVERFLOW] <= 0;
  flags[FLAG_CARRY]    <= 0;
endtask

task set_flags8(input [8:0] data, input [7:0] old);
  flags[FLAG_NEGATIVE] <= data[7];
  flags[FLAG_ZERO]     <= data[7:0] == 0;
  flags[FLAG_OVERFLOW] <= data[8] ^ old[7];
  flags[FLAG_CARRY]    <= data[8];
endtask

task set_flags16(input [16:0] data, input [15:0] old);
  flags[FLAG_NEGATIVE] <= data[15];
  flags[FLAG_ZERO]     <= data[15:0] == 0;
  flags[FLAG_OVERFLOW] <= data[16] ^ old[15];
  flags[FLAG_CARRY]    <= data[16];
endtask

task set_flags32(input [32:0] data, input [31:0] old);
  flags[FLAG_NEGATIVE] <= data[31];
  flags[FLAG_ZERO]     <= data[31:0] == 0;
  flags[FLAG_OVERFLOW] <= data[32] ^ old[31];
  flags[FLAG_CARRY]    <= data[32];
endtask

// This block is the main CPU instruction execute state machine.
always @(posedge clk) begin
  if (!button_reset)
    state <= STATE_RESET;
  else if (!button_halt)
    state <= STATE_HALTED;
  else
    case (state)
      STATE_RESET:
        begin
          mem_address <= 0;
          mem_write_enable <= 0;
          mem_write <= 0;
          instruction <= 0;
          flags <= 0;
          delay_loop <= 12000;
          arg1 <= 0;
          arg1_reg <= 0;
          //eeprom_strobe <= 0;
          state <= STATE_DELAY_LOOP;
          // Set stack pointer (sp).
          address[7] <= 16'h1000;
        end
      STATE_DELAY_LOOP:
        begin
          // This is probably not needed. The chip starts up fine without it.
          if (delay_loop == 0) begin

            // If button is not pushed, start rom.v code otherwise use EEPROM.
            if (button_program_select) begin
              pc <= 16'h4000;
              state <= STATE_FETCH_OP_0;
            end else begin
              pc <= 16'hc000;
              state <= STATE_EEPROM_START;
            end
          end else begin
            delay_loop <= delay_loop - 1;
          end
        end
      STATE_FETCH_OP_0:
        begin
          is_lea <= 0;
          is_address <= 0;
          is_immediate <= 0;
          do_branch <= 0;
          direction <= 0;
          mem_count <= 0;
          mem_bus_enable <= 1;
          mem_address <= pc;
          pc <= pc + 2;
          state <= STATE_FETCH_OP_1;
        end
      STATE_FETCH_OP_1:
        begin
          pc_current <= pc;
          mem_bus_enable <= 0;
          instruction <= mem_read;
          state <= STATE_START_DECODE;
        end
      STATE_START_DECODE:
        case (instruction[15:14])
          2'b00:
            case (instruction[13:12])
              2'b00:
                if (instruction[8] == 0) begin
                  // ori  #<data>, <ea>  0000 000 0
                  // andi #<data>, <ea>  0000 001 0
                  // subi #<data>, <ea>  0000 010 0
                  // addi #<data>, <ea>  0000 011 0
                  // eori #<data>, <ea>  0000 101 0
                  // bclr #<data>, <ea>  0000 100 0 10
                  // btst #<data>, <ea>  0000 100 0 00
                  // bchg #<data>, <ea>  0000 100 0 01
                  // bset #<data>, <ea>  0000 100 0 11
                  // cmpi #<data>, <ea>  0000 110 0
                  alu_op <= instruction[11:9];
                  state <= STATE_ALU_IMM_0;
                end else begin
                  // bclr dn, <ea> 0000 rrr1 10 mmmrrr
                  // btst dn, <ea> 0000 rrr1 00 mmmrrr
                  // bchg dn, <ea> 0000 rrr1 01 mmmrrr
                  // bset dn, <ea> 0000 rrr1 11 mmmrrr
                  alu_op <= ALU_BIT;
                  state <= STATE_ALU_0;
                end
              default:
                begin
                  // move <ea>, <ea>
                  // movea <ea>, An
                  alu_op <= ALU_MOV;
                  state <= STATE_ALU_0;
                end
            endcase
          2'b01:
            // lea  0100 rrr1 11mm mrrr
            // move 0100 0000 11mm mrrr <- sr
            // move 0100 0010 11mm mrrr <- ccr
            // clr  0100 0010 ssmm mrrr
            // neg  0100 0100 ssmm mrrr
            // move 0100 0100 11mm mrrr -> ccr
            // move 0100 0110 11mm mrrr -> sr
            // ext  0100 100p pp00 0rrr (p is only 010 or 011)
            // swap 0100 1000 0100 0rrr
            // jmp  0100 1110 11mm mrrr
            // jsr  0100 1110 10mm mrrr
            // trap 0100 1110 0100 vvvv
            // nop  0100 1110 0111 0001
            // rts  0100 1110 0111 0101
            case (instruction[13:12])
              2'b00:
                if (instruction[8] == 1) begin
                  // lea <ea>, an
                  is_lea <= 1;
                  alu_op <= ALU_LEA;
                  state <= STATE_ALU_0;
                end else begin
                  case (instruction[11:9])
                    3'b000:
                      begin
                        // move sr, <ea>
                        alu_op <= ALU_SR;
                        state <= STATE_ALU_0;
                      end
                    3'b001:
                      begin
                        // clr <ea>
                        // move ccr, <ea>
                        if (instruction[7:6] == 2'b11)
                          alu_op <= ALU_SR;
                        else
                          alu_op <= ALU_CLR;
                        state <= STATE_ALU_0;
                      end
                    3'b010:
                      begin
                        // neg <ea>
                        // mov <ea>, ccr
                        if (instruction[7:6] == 2'b11)
                          alu_op <= ALU_SR;
                        else
                          alu_op <= ALU_NEG;
                        state <= STATE_ALU_0;
                      end
                    3'b011:
                      begin
                        // move <ea>, sr
                        alu_op <= ALU_SR;
                        state <= STATE_ALU_0;
                      end
                    3'b100:
                      begin
                        // swap dn
                        // ext dn
                        arg1 <= data[instruction[2:0]];
                        if (instruction[7:6] == 2'b01)
                          state <= STATE_SWAP;
                        else
                          state <= STATE_EXT;
                      end
                    3'b111:
                      case (instruction[7:6])
                        2'b01:
                          if (instruction[5:4] == 2'b00)
                            // trap #n
                            if (instruction[3:0] == 1)
                              state <= STATE_ERROR;
                            else
                              state <= STATE_HALTED;
                          else
                            // rts 0101
                            // nop
                            case (instruction[3:0])
                              4'b0101: state <= STATE_POP_PC_0;
                              default: state <= STATE_FETCH_OP_0;
                            endcase
                        2'b10:
                          begin
                            // jsr <ea>
                            is_lea <= 1;
                            alu_op <= ALU_JSR;
                            state <= STATE_ALU_0;
                          end
                        2'b11:
                          begin
                            // jmp <ea>
                            is_lea <= 1;
                            alu_op <= ALU_JMP;
                            state <= STATE_ALU_0;
                          end
                      endcase
                  endcase
                end
              2'b01:
                begin
                  // addq #n, <ea>
                  // subq #n, <ea>
                  if (instruction[8] == 0)
                    alu_op <= ALU_ADD;
                  else
                    alu_op <= ALU_SUB;

                  state <= STATE_ALU_QUICK_0;
                end
              2'b10:
                begin
                  // bcc <label>
                  // bra <label>
                  // bsr <label>
                  state <= STATE_BRANCH_0;
                end
              2'b11:
                begin
                  // moveq
                  data[op_reg] <= $signed(instruction[7:0]);
                  state <= STATE_FETCH_OP_0;
                end
              default: state <= STATE_ERROR;
            endcase
          2'b10:
            case (instruction[13:12])
              2'b00:
                begin
                  // or <ea>, dn
                  // or dn, <ea>
                  alu_op <= ALU_OR;
                  state <= STATE_ALU_0;
                end
              2'b01:
                begin
                  // sub <ea>, dn
                  // sub dn, <ea>
                  // sub vs suba based on opmode
                  alu_op <= ALU_SUB;
                  state <= STATE_ALU_0;
                end
              2'b11:
                begin
                  // eor dn, <ea>
                  // cmp <ea>, dn
                  // cmpa <ea>, an
                  if (op_mode[2] == 1) begin
                    alu_op <= ALU_EOR;
                  end else begin
                    alu_op <= ALU_CMP;
                  end

                  state <= STATE_ALU_0;
                end
              default: state <= STATE_HALTED;
            endcase
          2'b11:
            case (instruction[13:12])
              4'b00:
                begin
                  // and <ea>, dn
                  // and dn, <ea>
                  alu_op <= ALU_AND;
                  state <= STATE_ALU_0;
                end
              2'b01:
                begin
                  // add <ea>, dn
                  // add dn, <ea>
                  // adda dn, <ea>
                  // adda dn, <ea>
                  // add vs adda based on opmode
                  alu_op <= ALU_ADD;
                  state <= STATE_ALU_0;
                end
              4'b10:
                begin
                  // lsr #n, dn
                  // lsr dx, dn
                  // lsl #n, dn
                  // lsl dx, dn
                  // asr #n, dn
                  // asr dx, dn
                  // asl #n, dn
                  // asl dx, dn
                  // ror #n, dn
                  // ror dx, dn
                  // rol #n, dn
                  // rol dx, dn
                  state <= STATE_SHIFT_0;
                end
            endcase
        endcase
      STATE_FETCH_DATA_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= pc;
          state <= STATE_FETCH_DATA_1;
        end
      STATE_FETCH_DATA_1:
        begin
          mem_bus_enable <= 0;
          mem_count <= mem_count + 1;
          pc <= pc + 2;

          if (mem_last == 1)
            case (mem_count)
              0: temp[31:16] <= mem_read;
              1: temp[15:0]  <= mem_read;
            endcase
          else
            begin
              temp[31:0] <= 0;
              temp[15:0] <= mem_read;
            end

          if (mem_count == mem_last)
            state <= state_after_fetch_data;
          else
            state <= STATE_FETCH_DATA_0;
        end
      STATE_FETCH_EA_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= { ea[31:1], 1'b0 };
          state <= STATE_FETCH_EA_1;
        end
      STATE_FETCH_EA_1:
        begin
          mem_bus_enable <= 0;
          mem_count <= mem_count + 1;
          ea <= ea + 2;

          if (mem_last == 1)
            case (mem_count)
              0: temp[31:16] <= mem_read;
              1: temp[15:0]  <= mem_read;
            endcase
          else
            begin
              temp[31:16] <= 0;

              if (size == 2) begin
                temp[15:0] <= mem_read;
              end else begin
                temp[15:8] <= 0;

                if (ea[0] == 0)
                  temp[7:0] <= mem_read[7:0];
                else
                  temp[7:0] <= mem_read[15:8];
              end
            end

          if (mem_count == mem_last)
            state <= state_after_ea;
          else
            state <= STATE_FETCH_EA_0;
        end
      STATE_WRITE_EA_0:
        begin
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          mem_address <= { ea_wb[31:1], 1'b0 };

          if (mem_last == 1) begin
            mem_write_mask <= 2'b00;

            case (mem_count)
              0: mem_write <= temp[31:16];
              1: mem_write <= temp[15:0];
              //DEBUG
              //0: mem_write <= 7;
              //1: mem_write <= 10;
            endcase
          end else begin
            if (size == 2) begin
              mem_write_mask <= 2'b00;
              mem_write <= temp[15:0];
              //DEBUG
              //mem_write <= 16'ha152;
            end else begin
              if (ea_wb[0] == 0) begin
                mem_write_mask <= 2'b10;
                mem_write[7:0] <= temp[7:0];
              end else begin
                mem_write_mask <= 2'b01;
                mem_write[15:8] <= temp[7:0];
              end
            end
          end

          state <= STATE_WRITE_EA_1;
        end
      STATE_WRITE_EA_1:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;
          ea_wb <= ea_wb + 2;

          if (mem_count == mem_last)
            state <= state_after_ea;
          else
            state <= STATE_WRITE_EA_0;

          mem_count <= mem_count + 1;
        end
      STATE_COMPUTE_EA_0:
        begin
          mem_count <= 0;

          case (ea_mode)
            3'b010:
              begin
                // (An).
                ea <= address[ea_reg];
                state <= state_after_ea;
              end
            3'b011:
              begin
                // (An)+.
                ea <= address[ea_reg];
                address[ea_reg] <= address[ea_reg] + size;
                state <= state_after_ea;
              end
            3'b100:
              begin
                // -(An).
                ea <= address[ea_reg] - size;
                address[ea_reg] <= address[ea_reg] - size;
                state <= state_after_ea;
              end
            3'b101:
              begin
                // (d16, An).
                mem_count <= 0;
                mem_last <= 0;
                state_after_fetch_data <= STATE_COMPUTE_EA_1;
                state <= STATE_FETCH_DATA_0;
              end
            3'b110:
              begin
                // (d8, An, Xn).
                mem_count <= 0;
                mem_last <= 0;
                state_after_fetch_data <= STATE_COMPUTE_EA_1;
                state <= STATE_FETCH_DATA_0;
              end
            3'b111:
              begin
                // (xxx).w      (reg 000). 2 bytes
                // (xxx).l      (reg 001). 4 bytes
                // #data        (reg 100). 2 or 4 bytes (depends on size)
                // (d16, pc)    (reg 010). 2 bytes
                // (d8, pc, Xn) (reg 011). 2 bytes
                mem_count <= 0;
                mem_last <= ea_reg == 3'b001 ? 1 : 0;

                state_after_fetch_data <= STATE_COMPUTE_EA_1;
                state <= STATE_FETCH_DATA_0;
              end
            default: state <= STATE_ERROR;
          endcase
        end
      STATE_COMPUTE_EA_1:
        begin
          case (ea_mode)
            3'b101:
              begin
                // (d16, An).
                ea <= address[ea_reg] + $signed(temp[15:0]);
              end
            3'b110:
              begin
                // (d8, An, Xn).
                if (xn_size == 0)
                  if (xn_scale == 0)
                    ea <= address[ea_reg] + xn_disp + data[xn_reg][15:0];
                  else
                    ea <= address[ea_reg] + xn_disp + (data[xn_reg][15:0] << (xn_scale == 4 ? 2 : 1));
                else
                  if (xn_scale == 0)
                    ea <= address[ea_reg] + xn_disp + data[xn_reg];
                  else
                    ea <= address[ea_reg] + xn_disp + (data[xn_reg] << (xn_scale == 4 ? 2 : 1));
              end
            3'b111:
              begin
                mem_count <= 0;

                case (ea_reg)
                  3'b000:
                    begin
                      // (xxx).w      (reg 000).
                      ea <= temp;
                    end
                  3'b001:
                    begin
                      // (xxx).l      (reg 001).
                      ea <= temp;
                    end
/*
                  3'b100:
                    begin
                      // #data        (reg 100).
                      state <= state_after_ea;
                    end
*/
                  3'b010:
                    begin
                      // (d16, pc)    (reg 010).
                      ea <= pc_current + $signed(temp[15:0]);
                    end
                  3'b011:
                    begin
                      // (d8, pc, Xn) (reg 011).
                      if (xn_size == 0)
                        if (xn_scale == 0)
                          ea <= pc_current + xn_disp + data[xn_reg][15:0];
                        else
                          ea <= pc_current + xn_disp + (data[xn_reg][15:0] << (xn_scale == 4 ? 2 : 1));
                      else
                        if (xn_scale == 0)
                          ea <= pc_current + xn_disp + data[xn_reg];
                        else
                          ea <= pc_current + xn_disp + (data[xn_reg] << (xn_scale == 4 ? 2 : 1));
                    end
                endcase
              end
          endcase

          state <= state_after_ea;
        end
      STATE_ALU_IMM_0:
        begin
          mem_count <= 0;
          is_immediate <= 1;
          direction <= 1;

          if (alu_op == ALU_BIT) begin
            mem_last <= 0;
            size <= ea_mode == 0 ? 4 : 1;
          end else begin
            mem_last <= instruction[7:6] == 2 ? 1 : 0;

            case (instruction[7:6])
              2'b00: size <= 1;
              2'b01: size <= 2;
              2'b10: size <= 4;
            endcase
          end

          state_after_fetch_data <= STATE_ALU_IMM_1;
          state <= STATE_FETCH_DATA_0;
        end
      STATE_ALU_IMM_1:
        begin
          arg1 <= temp;
          ea_code <= instruction[5:0];

          if (instruction[5:0] == 6'b111100)
            state <= STATE_ALU_CCR;
          else
            state <= STATE_ALU_1;
        end
      STATE_ALU_QUICK_0:
        begin
          is_immediate <= 1;
          direction <= 1;
          arg1 <= op_reg == 0 ? 8 : op_reg;
          ea_code <= instruction[5:0];

          mem_count <= 0;
          mem_last <= instruction[7:6] == 2 ? 1 : 0;

          case (instruction[7:6])
            2'b00: size <= 1;
            2'b01: size <= 2;
            2'b10: size <= 4;
          endcase

          state <= STATE_ALU_1;
        end
      STATE_ALU_CCR:
        begin
          case (alu_op)
            ALU_OR:  flags[4:0] <= arg1 | flags[4:0];
            ALU_AND: flags[4:0] <= arg1 & flags[4:0];
            //ALU_SUB: flags[4:0] <= arg1 - flags[4:0];
            ALU_ADD: flags[4:0] <= arg1 + flags[4:0];
            ALU_EOR: flags[4:0] <= arg1 ^ flags[4:0];
          endcase

          state <= STATE_FETCH_OP_0;
        end
      STATE_ALU_0:
        begin
          // byte d00 data
          // word d01 data
          // long d10 data
          // word 011 address
          // long 111 address
          if (alu_op == ALU_MOV) begin
            // For move, the size bits are 13:12. Also the encoding is
            // different.
            direction <= 0;
            mem_last <= instruction[13:12] == 2'b10 ? 1 : 0;
            case (instruction[13:12])
              2'b01: size <= 1;
              2'b11: size <= 2;
              2'b10: size <= 4;
            endcase
          end else if (alu_op == ALU_BIT) begin
            direction <= 1;
            size <= ea_mode == 0 ? 4 : 1;
            is_immediate <= 1;
            mem_last <= 0;
          end else if (alu_op == ALU_SR) begin
            direction <= ~instruction[10];
            size <= 2;
          end else if (op_mode[1:0] == 2'b11) begin
            direction <= 0;
            mem_last <= op_mode[2];
            is_address <= 1;
            size <= op_mode[2] == 0 ? 2 : 4;
          end else begin
            direction <= op_mode[2];
            mem_last <= op_mode[1];
            case (op_mode[1:0])
              0: size <= 1;
              1: size <= 2;
              2: size <= 4;
            endcase
          end

          if (alu_op == ALU_BIT) begin
            arg1 <= data[instruction[11:9]];
          end else begin
            arg1 <= data[op_reg];
            arg1_reg <= op_reg;
          end

          ea_code <= instruction[5:0];

          state_after_ea <= STATE_ALU_2;
          state <= STATE_ALU_1;
        end
      STATE_ALU_1:
        begin
          // Start decoding effective address.
          // (000) Dn.
          // (001) An.
          case (ea_mode)
            3'b000:
              begin
                temp <= data[ea_reg];
                state <= STATE_ALU_3;
              end
            3'b001:
              begin
                temp <= address[ea_reg];
                state <= STATE_ALU_3;
              end
            3'b111:
              begin
                if (ea_reg == 3'b100) begin
                  // ea is #<data>
                  mem_count <= 0;
                  mem_last <= size == 4 ? 1 : 0;
                  state_after_fetch_data <= STATE_ALU_3;
                  state <= STATE_FETCH_DATA_0;
                end else begin
                  state_after_ea <= STATE_ALU_2;
                  state <= STATE_COMPUTE_EA_0;
                end
              end
            default:
              begin
                state_after_ea <= STATE_ALU_2;
                state <= STATE_COMPUTE_EA_0;
              end
          endcase
        end
      STATE_ALU_2:
        begin
          mem_count <= 0;
          mem_last <= size == 4 ? 1 : 0;
          ea_wb <= ea;

          if (is_lea == 1) begin
            if (alu_op == ALU_JMP || alu_op == ALU_JSR)
              pc <= ea;
            else
              address[op_reg] <= ea;

            if (alu_op == ALU_JSR) begin
              temp <= pc;
              state <= STATE_PUSH_TEMP_0;
            end else begin
              state <= STATE_FETCH_OP_0;
            end
          end else begin
            state <= STATE_FETCH_EA_0;
          end

          if (alu_op == ALU_MOV) begin
            ea_code[2:0] <= instruction[11:9];
            ea_code[5:3] <= instruction[8:6];
            state_after_ea <= STATE_MOVE_0;
          end else begin
            state_after_ea <= STATE_ALU_3;
          end
        end
      STATE_ALU_3:
        begin
          if (is_immediate) begin
            dest_value <= temp;
            dest_reg = ea_reg;
          end else if (direction == 0) begin
            arg1 <= temp;
            dest_reg = op_reg;
            dest_value <= data[op_reg];
          end else begin
            dest_value <= temp;
            temp <= data[op_reg];
          end

          if (alu_op == ALU_MOV) begin
            state <= STATE_MOVE_0;
            ea_code[2:0] <= instruction[11:9];
            ea_code[5:3] <= instruction[8:6];
          end else begin
            state <= STATE_ALU_4;
          end
        end
      STATE_ALU_4:
        begin
          case (alu_op)
            ALU_OR:  result <= dest_value | arg1;
            ALU_AND: result <= dest_value & arg1;
            ALU_SUB: result <= dest_value - arg1;
            ALU_CMP: result <= dest_value - arg1;
            ALU_ADD: result <= dest_value + arg1;
            ALU_EOR: result <= dest_value ^ arg1;
            ALU_CLR: result <= 0;
            ALU_NEG: result <= 0 - arg1;
            ALU_SR:  result <= flags;
            ALU_BIT: begin flags[FLAG_ZERO] <= ~arg1[arg1]; result <= arg1; end
          endcase

          if (alu_op == ALU_BIT) begin
            state <= STATE_BIT_UPDATE;
          end else if (alu_op == ALU_SR && direction == 0) begin
            flags <= temp;
            state <= STATE_FETCH_OP_0;
          end else begin
            state <= STATE_ALU_WB;
          end
        end
      STATE_ALU_WB:
        begin
          if (alu_op != ALU_BIT && alu_op != ALU_SR)
            case (size)
              1:
                begin
                  set_flags8(result, dest_value);
                  temp[7:0] <= result[7:0];
                end
              2:
                begin
                  set_flags16(result, dest_value);
                  temp[15:0] <= result[15:0];
                end
              4:
                begin
                  set_flags32(result, dest_value);
                  temp[31:0] <= result[31:0];
                end
            endcase

          if (is_address == 1) begin
            if (size == 2)
              address[op_reg][15:0] <= result[15:0];
            else
              address[op_reg] <= result;

            state <= STATE_FETCH_OP_0;
          end else if (direction == 0) begin
            case (size)
              1: data[op_reg][7:0] <= result[7:0];
              2: data[op_reg][15:0] <= result[15:0];
              4: data[op_reg] <= result;
            endcase

            state <= STATE_FETCH_OP_0;
          end else begin
            case (ea_mode)
              3'b000:
                begin
                  case (size)
                    1: data[ea_reg][7:0] <= result[7:0];
                    2: data[ea_reg][15:0] <= result[15:0];
                    4: data[ea_reg] <= result;
                  endcase

                  state <= STATE_FETCH_OP_0;
                end
              3'b001:
                begin
                  case (size)
                    1: address[ea_reg][7:0] <= result[7:0];
                    2: address[ea_reg][15:0] <= result[15:0];
                    4: address[ea_reg] <= result;
                  endcase

                  state <= STATE_FETCH_OP_0;
                end
              default:
                state <= STATE_ALU_WB_MEM;
            endcase
          end
        end
      STATE_ALU_WB_MEM:
        begin
          mem_count <= 0;
          mem_last <= size == 4 ? 1 : 0;
          temp <= result;
          state_after_ea <= STATE_FETCH_OP_0;
          state <= STATE_WRITE_EA_0;
        end
      STATE_MOVE_0:
        begin
          arg1 <= temp;

          case (ea_mode)
            3'b000:
              begin
                case (size)
                  1:
                    begin
                      data[ea_reg][7:0] <= temp[7:0];
                      flags[FLAG_NEGATIVE] <= temp[7];
                      flags[FLAG_ZERO] <= temp[7:0] == 0 ? 1 : 0;
                    end
                  2:
                    begin
                      data[ea_reg][15:0] <= temp[15:0];
                      flags[FLAG_NEGATIVE] <= temp[15];
                      flags[FLAG_ZERO] <= temp[15:0] == 0 ? 1 : 0;
                    end
                  4:
                    begin
                      data[ea_reg] <= temp;
                      flags[FLAG_NEGATIVE] <= temp[31];
                      flags[FLAG_ZERO] <= temp[31:0] == 0 ? 1 : 0;
                    end
                endcase

                flags[FLAG_OVERFLOW] <= 0;
                flags[FLAG_CARRY] <= 0;

                state <= STATE_FETCH_OP_0;
              end
            3'b001:
              begin
                case (size)
                  2: data[ea_reg][15:0] <= temp[15:0];
                  4: data[ea_reg] <= temp;
                endcase
                state <= STATE_FETCH_OP_0;
              end
            default:
              begin
                state_after_ea <= STATE_MOVE_1;
                state <= STATE_COMPUTE_EA_0;
              end
          endcase
        end
      STATE_MOVE_1:
        begin
          ea_wb <= ea;

          case (instruction[13:12])
            2'b01:
              begin
                set_flags8_nocf(arg1);
                temp[7:0] <= arg1[7:0];
              end
            2'b11:
              begin
                set_flags16_nocf(arg1);
                temp[15:0] <= arg1[15:0];
              end
            2'b10:
              begin
                set_flags32_nocf(arg1);
                temp[31:0] <= arg1[31:0];
              end
          endcase

          mem_count <= 0;
          mem_last <= size == 4 ? 1 : 0;
          state_after_ea <= STATE_FETCH_OP_0;
          state <= STATE_WRITE_EA_0;
        end
      STATE_EXT:
        begin
          if (op_mode == 2) begin
            data[instruction[2:0]][15:0] <= $signed(arg1[7:0]);
            flags[FLAG_NEGATIVE] <= arg1[7];
            flags[FLAG_ZERO]     <= arg1[7:0] == 0;
          end else begin
            data[instruction[2:0]] <= $signed(arg1[15:0]);
            flags[FLAG_NEGATIVE] <= arg1[15];
            flags[FLAG_ZERO]     <= arg1[15:0] == 0;
          end

          flags[FLAG_OVERFLOW] <= 0;
          flags[FLAG_CARRY] <= 0;
        end
      STATE_SHIFT_0:
        begin
          if (instruction[5] == 0)
            shift_count <= instruction[11:9] == 0 ? 8 : instruction[11:9];
          else
            shift_count <= data[instruction[11:9]];

          //           0=right / 1=left, 00=arithmetic / 01=logical / 11=roll
          shift_type = { instruction[8], instruction[4:3] };
          state <= STATE_SHIFT_1;
        end
      STATE_SHIFT_1:
        begin
          case (shift_type)
            3'b000: result <= $signed(data[instruction[2:0]]) >> shift_count;
            3'b001: result <= data[instruction[2:0]] >> shift_count;
            3'b011:
              case (shift_size)
                2'b00:
                  begin
                    result <=
                      (data[instruction[2:0]][7:0] >> shift_count) |
                      (data[instruction[2:0]][7:0] << (8 - shift_count));
                  end
                2'b01:
                  begin
                    result <=
                      (data[instruction[2:0]][15:0] >> shift_count) |
                      (data[instruction[2:0]][15:0] << (16 - shift_count));
                  end
                2'b10:
                  begin
                    result <=
                      (data[instruction[2:0]] >> shift_count) |
                      (data[instruction[2:0]] << (32 - shift_count));
                  end
              endcase
            3'b100: result <= $signed(data[instruction[2:0]]) << shift_count;
            3'b101: result <= data[instruction[2:0]] << shift_count;
            3'b111:
              case (shift_size)
                2'b00:
                  begin
                    result <=
                      (data[instruction[2:0]][7:0] << shift_count) |
                      (data[instruction[2:0]][7:0] >> (8 - shift_count));
                  end
                2'b01:
                  begin
                    result <=
                      (data[instruction[2:0]][15:0] << shift_count) |
                      (data[instruction[2:0]][15:0] >> (16 - shift_count));
                  end
                2'b10:
                  begin
                    result <=
                      (data[instruction[2:0]] << shift_count) |
                      (data[instruction[2:0]] >> (32 - shift_count));
                  end
              endcase
          endcase

          state <= STATE_SHIFT_2;
        end
      STATE_SHIFT_2:
        begin
          case (shift_size)
            2'b00:
              begin
                data[instruction[2:0]][7:0] <= result[7:0];
                flags[FLAG_ZERO] <= result[7:0] == 0;
                flags[FLAG_NEGATIVE] <= result[7];

                if (shift_type[2] == 0)
                  flags[FLAG_CARRY] <= data[instruction[2:0]][shift_count - 1];
                else
                  flags[FLAG_CARRY] <= data[instruction[2:0]][8 - shift_count];
              end
            2'b01:
              begin
                data[instruction[2:0]][15:0] <= result[15:0];
                flags[FLAG_ZERO] <= result[15:0] == 0;
                flags[FLAG_NEGATIVE] <= result[15];

                if (shift_type[2] == 0)
                  flags[FLAG_CARRY] <= data[instruction[2:0]][shift_count - 1];
                else
                  flags[FLAG_CARRY] <= data[instruction[2:0]][16 - shift_count];
              end
            2'b10:
              begin
                data[instruction[2:0]] <= result;
                flags[FLAG_ZERO] <= result == 0;
                flags[FLAG_NEGATIVE] <= result[31];

                if (shift_type[2] == 0)
                  flags[FLAG_CARRY] <= data[instruction[2:0]][shift_count - 1];
                else
                  flags[FLAG_CARRY] <= data[instruction[2:0]][32 - shift_count];
              end
          endcase

          flags[FLAG_OVERFLOW] <= 0;

          state <= STATE_FETCH_OP_0;
        end
      STATE_BRANCH_0:
        begin
          if (instruction[7:0] == 0) begin
            mem_count <= 0;
            mem_last <= 0;
            state_after_fetch_data <= STATE_BRANCH_1;
            state <= STATE_FETCH_DATA_0;
          end else begin
            temp <= { {8{instruction[7]}}, instruction[7:0] };
            state <= STATE_BRANCH_1;
          end

          case (instruction[11:9])
            3'b000:
              begin
                // Branch always / subroutine.
                do_branch <= 1;
              end
            3'b001:
              begin
                // Branch high / low or same (hi, ls).
                if ((~flags[FLAG_CARRY] && ~flags[FLAG_ZERO]) ^ instruction[8])
                  do_branch <= 1;
              end
            3'b010:
              begin
                // Branch carry clear / carry set (cc/hi, cs/lo).
                if (~flags[FLAG_CARRY] ^ instruction[8])
                  do_branch <= 1;
              end
            3'b011:
              begin
                // Branch not equal / equal (ne, eq).
                if (~flags[FLAG_ZERO] ^ instruction[8])
                  do_branch <= 1;
              end
            3'b100:
              begin
                // Branch overflow clear / overflow set (vc, vs).
                if (~flags[FLAG_OVERFLOW] ^ instruction[8])
                  do_branch <= 1;
              end
            3'b101:
              begin
                // Branch plus / minus (pl, mi).
                if (~flags[FLAG_NEGATIVE] ^ instruction[8])
                  do_branch <= 1;
              end
            3'b110:
              begin
                // Branch greater or equal / less than (ge, lt).
                if (((flags[FLAG_NEGATIVE] && flags[FLAG_OVERFLOW]) ||
                    (~flags[FLAG_NEGATIVE] || ~flags[FLAG_OVERFLOW]))
                     ^ instruction[8])
                  do_branch <= 1;
              end
            3'b111:
              begin
                // Branch greater than / less or requal (gt, le).
                if (((flags[FLAG_NEGATIVE] &&
                      flags[FLAG_OVERFLOW] &&
                     ~flags[FLAG_ZERO]) ||
                    (~flags[FLAG_NEGATIVE] &&
                     ~flags[FLAG_OVERFLOW] &&
                     ~flags[FLAG_ZERO])) ^ instruction[8])
                  do_branch <= 1;
              end
          endcase

          arg1 <= pc;
        end
      STATE_BRANCH_1:
        begin
          if (do_branch)
            pc <= $signed(arg1[15:0]) + $signed(temp[15:0]);

          temp <= pc;

          if (instruction[11:8] == 4'b0001) begin
            mem_count <= 0;
            state <= STATE_PUSH_TEMP_0;
          end else begin
            state <= STATE_FETCH_OP_0;
          end
        end
      STATE_PUSH_TEMP_0:
        begin
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          mem_address <= address[7] - 2;
          mem_write_mask <= 2'b00;

          case (mem_count)
            0: mem_write <= temp[15:0];
            1: mem_write <= temp[31:16];
          endcase

          state <= STATE_PUSH_TEMP_1;
        end
      STATE_PUSH_TEMP_1:
        begin
          mem_bus_enable <= 0;
          mem_write_enable <= 0;
          //ea_wb <= ea_wb + 2;

          if (mem_count == 1)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_PUSH_TEMP_0;

          address[7] <= mem_address;
          mem_count <= mem_count + 1;
        end
      STATE_POP_PC_0:
        begin
          mem_bus_enable <= 1;
          mem_address <= address[7];
          state <= STATE_POP_PC_1;
        end
      STATE_POP_PC_1:
        begin
          case (mem_count)
            //0: pc[31:16] <= mem_read;
            1: pc[15:0]  <= mem_read;
          endcase

          address[7] <= mem_address + 2;
          mem_count <= mem_count + 1;
          mem_bus_enable <= 0;

          if (mem_count == 1)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_POP_PC_0;
        end
      STATE_SWAP:
        begin
          data[instruction[2:0]][31:16] <= arg1[15:0];
          data[instruction[2:0]][15:0]  <= arg1[31:16];
          state <= STATE_FETCH_OP_0;
        end
      STATE_BIT_UPDATE:
        begin
          case (instruction[7:6])
            2'b01: result[arg1] <= result[arg1] ^ 1;
            2'b10: result[arg1] <= 0;
            2'b11: result[arg1] <= 1;
          endcase

          if (instruction[7:6] == 0)
            state <= STATE_FETCH_OP_0;
          else
            state <= STATE_ALU_WB;
        end
      STATE_HALTED:
        begin
          state <= STATE_HALTED;
        end
      STATE_ERROR:
        begin
          state <= STATE_ERROR;
        end
      STATE_EEPROM_START:
        begin
          // Initialize values for reading from SPI-like EEPROM.
          if (eeprom_ready) begin
            //eeprom_mem_address <= pc;
            eeprom_mem_address <= 16'hc000;
            eeprom_count <= 0;
            state <= STATE_EEPROM_READ;
          end
        end
      STATE_EEPROM_READ:
        begin
          // Set the next EEPROM address to read from and strobe.
          mem_bus_enable <= 0;
          eeprom_address <= eeprom_count;
          eeprom_strobe <= 1;
          state <= STATE_EEPROM_WAIT;
        end
      STATE_EEPROM_WAIT:
        begin
          // Wait until 8 bits are clocked in.
          eeprom_strobe <= 0;

          if (eeprom_ready) begin

            if (eeprom_count[1:0] == 3) begin
              mem_address <= eeprom_mem_address;
              mem_write_mask <= 4'b0000;
              // After reading 4 bytes, store the 32 bit value to RAM.
              mem_write <= {
                eeprom_data_out,
                eeprom_holding[2],
                eeprom_holding[1],
                eeprom_holding[0]
              };

              state <= STATE_EEPROM_WRITE;
            end else begin
              // Read 3 bytes into a holding register.
              eeprom_holding[eeprom_count[1:0]] <= eeprom_data_out;
              state <= STATE_EEPROM_READ;
            end

            eeprom_count <= eeprom_count + 1;
          end
        end
      STATE_EEPROM_WRITE:
        begin
          // Write value read from EEPROM into memory.
          mem_bus_enable <= 1;
          mem_write_enable <= 1;
          eeprom_mem_address <= eeprom_mem_address + 4;

          state <= STATE_EEPROM_DONE;
        end
      STATE_EEPROM_DONE:
        begin
          // Finish writing and read next byte if needed.
          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          if (eeprom_count == 0) begin
            // Read in 2048 bytes.
            state <= STATE_FETCH_OP_0;
          end else
            state <= STATE_EEPROM_READ;
        end
    endcase
end

memory_bus memory_bus_0(
  .address      (mem_address),
  .data_in      (mem_write),
  .write_mask   (mem_write_mask),
  .data_out     (mem_read),
  //.debug        (mem_debug),
  //.data_ready   (mem_data_ready),
  .bus_enable   (mem_bus_enable),
  .write_enable (mem_write_enable),
  .clk          (clk),
  .raw_clk      (raw_clk),
  .speaker_p    (speaker_p),
  .speaker_m    (speaker_m),
  .ioport_0     (ioport_0),
  .ioport_1     (ioport_1),
  .ioport_2     (ioport_2),
  .ioport_3     (ioport_3),
  .button_0     (button_0),
  .reset        (~button_reset),
  .spi_clk      (spi_clk),
  .spi_mosi     (spi_mosi),
  .spi_miso     (spi_miso)
);

eeprom eeprom_0
(
  .address    (eeprom_address),
  .strobe     (eeprom_strobe),
  .raw_clk    (raw_clk),
  .eeprom_cs  (eeprom_cs),
  .eeprom_clk (eeprom_clk),
  .eeprom_di  (eeprom_di),
  .eeprom_do  (eeprom_do),
  .ready      (eeprom_ready),
  .data_out   (eeprom_data_out)
);

endmodule

