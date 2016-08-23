-----
-- This is a floating point CORDIC processor
-- It can be used to calculate
-- sine, cosine, tangens, arctan, arccos, arcsin, ln, tanh etc.
--
-- Note: The angle has to be in range [-pi/2,pi/2]
--
-- TODO: Add documentation and references
--
-- Author: M.Schilling
-- Date: 2015/11/19
-- 
-----

library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.fpupack.all;


entity fpu_cordic is
    generic(
               ITERATIONS : integer := 32 -- The number of iterations the core runs to calculate final results
           );
	port(
        clk_i 			: in std_logic;

        -- Input Operand
        opx_i        	: in std_logic_vector(FP_WIDTH-1 downto 0);  -- Default: FP_WIDTH=32 
        opy_i        	: in std_logic_vector(FP_WIDTH-1 downto 0);  -- Default: FP_WIDTH=32 
        opz_i        	: in std_logic_vector(FP_WIDTH-1 downto 0);  -- Default: FP_WIDTH=32 

        -- Mode signal
        -- MSB: 1: vector mode 0: rotating mode
        -- LSB: 0: Trigonometric 1: Hyperbolic
        mode_i          : in std_logic_vector(1 downto 0);
        
        -- Output port   
        outx_o        : out std_logic_vector(FP_WIDTH-1 downto 0);
        outy_o        : out std_logic_vector(FP_WIDTH-1 downto 0);
        outz_o        : out std_logic_vector(FP_WIDTH-1 downto 0);
        
        -- Control signals
        start_i			: in std_logic; -- is also restart signal
        ready_o 		: out std_logic
		);
end fpu_cordic;

architecture rtl of fpu_cordic is

-- Types for lookup table depending on ITERATIONS and mode
type table_t is array(0 to ITERATIONS-1) of std_logic_vector(FP_WIDTH-1 downto 0);
type lookup_t is array(0 to 1) of table;

type t_state is (idle, );
signal s_state : t_state := idle;
signal s_count : integer range 0 to ITERATIONS-1;

-- Input registers
signal s_mode_i : std_logic_vector(1 downto 0);
signal s_opx_i : std_logic_vector(FP_WIDTH-1 downto 0);
signal s_opy_i : std_logic_vector(FP_WIDTH-1 downto 0);
signal s_opz_i : std_logic_vector(FP_WIDTH-1 downto 0);

signal fp_sub1_opb : std_logic_vector(FP_WIDTH-1 downto 0);
signal fp_sub1_result : std_logic_vector(FP_WIDTH-1 downto 0);
signal fp_sub2_opb : std_logic_vector(FP_WIDTH-1 downto 0);
signal fp_sub2_result : std_logic_vector(FP_WIDTH-1 downto 0);
signal fp_sub3_opb : std_logic_vector(FP_WIDTH-1 downto 0);
signal fp_sub3_result : std_logic_vector(FP_WIDTH-1 downto 0);

signal fp_sub_start : std_logic;
signal fp_sub_rdy : std_logic;

signal sign : std_logic; -- di
signal exp_sub1 : std_logic_vector(EXP_WIDTH-1 downto 0);
signal exp_sub2 : std_logic_vector(EXP_WIDTH-1 downto 0);

-- lookup table
signal elementary : std_logic_vector(FP_WIDTH-1 downto 0);
constant lookup : lookup_t :=
(
    0 => ( -- Table for atan(2^-i)
            0 => x"3f490fdb", -- 0.785398f
            1 => x"3eed6338", -- 0.463648f
            2 => x"3e7adbb0", -- 0.244979f
            3 => x"3dfeadd5", -- 0.124355f
            4 => x"3d7faade", -- 0.062419f
            5 => x"3cffeaae", -- 0.031240f
            6 => x"3c7ffaab", -- 0.015624f
            7 => x"3bfffeab", -- 0.007812f
            8 => x"3b7fffab", -- 0.003906f
            9 => x"3affffeb", -- 0.001953f
            10 => x"3a7ffffb", -- 0.000977f
            11 => x"39ffffff", -- 0.000488f
            12 => x"39800000", -- 0.000244f
            13 => x"39000000", -- 0.000122f
            14 => x"38800000", -- 0.000061f
            15 => x"38000000", -- 0.000031f
            16 => x"37800000", -- 0.000015f
            17 => x"37000000", -- 0.000008f
            18 => x"36800000", -- 0.000004f
            19 => x"36000000", -- 0.000002f
            20 => x"35800000", -- 0.000001f
            21 => x"35000000", -- 0.000000f
            22 => x"34800000", -- 0.000000f
            23 => x"34000000", -- 0.000000f
            24 => x"33800000", -- 0.000000f
            25 => x"33000000", -- 0.000000f
            26 => x"32800000", -- 0.000000f
            27 => x"32000000", -- 0.000000f
            28 => x"31800000", -- 0.000000f
            29 => x"31000000", -- 0.000000f
            30 => x"30800000", -- 0.000000f
            31 => x"30000000", -- 0.000000f
            others => x"00000000"
         )
     1 => ( -- table for atanh(2^-i)
            0 => x"7f800000", -- inff
            1 => x"3f0c9f54", -- 0.549306f
            2 => x"3e82c578", -- 0.255413f
            3 => x"3e00ac49", -- 0.125657f
            4 => x"3d802ac5", -- 0.062582f
            5 => x"3d000aac", -- 0.031260f
            6 => x"3c8002ab", -- 0.015626f
            7 => x"3c0000ab", -- 0.007813f
            8 => x"3b80002b", -- 0.003906f
            9 => x"3b00000b", -- 0.001953f
            10 => x"3a800003", -- 0.000977f
            11 => x"3a000001", -- 0.000488f
            12 => x"39800001", -- 0.000244f
            13 => x"39000000", -- 0.000122f
            14 => x"38800000", -- 0.000061f
            15 => x"38000000", -- 0.000031f
            16 => x"37800000", -- 0.000015f
            17 => x"37000000", -- 0.000008f
            18 => x"36800000", -- 0.000004f
            19 => x"36000000", -- 0.000002f
            20 => x"35800000", -- 0.000001f
            21 => x"35000000", -- 0.000000f
            22 => x"34800000", -- 0.000000f
            23 => x"34000000", -- 0.000000f
            24 => x"33800000", -- 0.000000f
            25 => x"33000000", -- 0.000000f
            26 => x"32800000", -- 0.000000f
            27 => x"32000000", -- 0.000000f
            28 => x"31800000", -- 0.000000f
            29 => x"31000000", -- 0.000000f
            30 => x"30800000", -- 0.000000f
            31 => x"30000000", -- 0.000000f
            others => x"00000000"
         )
);

begin

    -- select di according to mode and sign of current values (first stage)
    with s_mode_i(2) select
        sign <= s_opz_i(FP_WIDTH-1) when '0',
                not s_opy_i(FP_WIDTH-1) when '1';

    -- 'shift' yi by i (new = exponent - i)
    exp_sub1 <= std_logic_vector(signed(s_opy_i(FP_WIDTH-2 downto FP_WIDTH-EXP_WIDTH-1)) - to_signed(s_count, EXP_WIDTH));
    -- 'shift' xi by i (new = exponent - i)
    exp_sub2 <= std_logic_vector(signed(s_opx_i(FP_WIDTH-2 downto FP_WIDTH-EXP_WIDTH-1)) - to_signed(s_count, EXP_WIDTH));

    -- second operand of sub2: - di*xi*2^-i (second stage)
    fp_sub2_opb <= not sign & exp_sub2 & s_opx_i(FRAC_WIDTH-1 downto 0);
    -- second operand of sub1: m * di * yi * 2^-i
    with s_mode_i(1 downto 0) select
        fp_sub1_opb <= sign & exp_sub1 & s_opy_i(FRAC_WIDTH-1 downto 0) when "00",
                       not sign & exp_sub1 & s_opy_i(FRAC_WIDTH-1 downto 0) when "10",
                       "0" & ZERO_VECTOR when others;
    -- second operand of sub3: di * elementary angle (e.g. atan(2^-i))
    fp_sub3_opb <= sign & elementary(FP_WIDTH-2 downto 0);

    fp_sub1 : entity work.fpu_sub(rtl)
        port map (
                    clk_i => clk,
                    opa_i => s_opx_i,
                    opb_i => fp_sub1_opb, -- m*di*yi*2^-i
                    rmode_i => "00", -- round to nearest even
                    output_o => fp_sub1_result,
                    start_i => fp_sub_start,
                    ready_o => fp_sub_rdy
                 );
    fp_sub2 : entity work.fpu_sub(rtl)
        port map (
                    clk_i => clk,
                    opa_i => s_opy_i,
                    opb_i => fp_sub2_opb, -- -di*xi*2^-i
                    rmode_i => "00", -- round to nearest even
                    output_o => fp_sub2_result,
                    start_i => fp_sub_start,
                    ready_o => open
                 );
    fp_sub3 : entity work.fpu_sub(rtl)
        port map (
                    clk_i => clk,
                    opa_i => s_opz_i,
                    opb_i => fp_sub3_opb, -- di*ei
                    rmode_i => "00", -- round to nearest even
                    output_o => fp_sub3_result,
                    start_i => fp_sub_start,
                    ready_o => open
                 );

        -- ROM process
        process(clk)
        begin
            if rising_edge(clk_i) then
                elementary <= lookup(to_integer(unsigned(s_mode_i(1 downto 0))))(s_count);
            end if;
        end process;

-- FSM
process(clk_i)
begin
	if rising_edge(clk_i) then
        -- defaults
        fp_sub_start <= '0';
        ready_o <= '0';
        s_state <= s_state;
        case s_state is
            when idle =>
                -- sample incoming values
                if (start_i = '1') then
                    s_opx_i <= opx_i;
                    s_opy_i <= opy_i;
                    s_opz_i <= opz_i;
                    s_mode_i <= mode_i;
                    if (mode_i(1 downto 0) = "10") then
                        s_count <= 1; -- In hyperbolic mode we have to start at iteration 1!
                    else
                        s_count <= 0;
                    end if;
                    s_state <= compute;
                end if;
            when compute =>
                -- Idle state for BRAM, time for first stage stuff
                s_state <= compute1;
            when compute1 =>
                -- start the adders
                fp_sub_start <= '1';
                s_state <= iterate;
            when iterate =>
                -- We have to wait for one of the adders
                if (fp_sub_rdy = '1') then
                    -- update values & counter
                    s_opx_i <= fp_sub1_result;
                    s_opy_i <= fp_sub2_result;
                    s_opz_i <= fp_sub3_result;
                    s_count <= s_count + 1; -- TODO: We can count up in the previous state! then we can go to compute1 -> check sizes!
                    -- if we have done ITERATIONS we are finished :)
                    if (s_count < ITERATIONS-1) then
                        s_state <= compute;
                    else
                        ready_o <= '1';
                        outx_o <= fp_sub1_result;
                        outy_o <= fp_sub2_result;
                        outz_o <= fp_sub3_result;
                        s_state <= idle;
                    end if;
                end if;
        end case;
	end if;	
end process;

end rtl;
