-------------------------------------------------------------------------------
-- This entity converts a fixed point value to a floating point value
--
-- Author: M.Schilling
-- Date: 2016/12/21
-- 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.fpupack.all;


entity fpu_fixed2float is
    generic (
                FRACT_WIDTH := 16 -- Tells us how many bits the fractional part of the input fixed point value takes (default: 16.16 fixed point)
            );
    port (
        clk_i 			: in std_logic;

        -- Input fixed point value
        fixed_i        	: in std_logic_vector(FP_WIDTH-1 downto 0);
        
        -- Output float value
        output_o        : out std_logic_vector(FP_WIDTH-1 downto 0);
        
        -- Control signals
        start_i			: in std_logic; -- is also restart signal
        ready_o 		: out std_logic
	);   
end fpu_fixed2float;

architecture rtl of fpu_fixed2float is
begin

-- TODO (rough):
-- * convert the integer part of the fixed point value into a sign and a unsigned value
-- * the sign bit can already be used for the result
-- * count the leading zeroes of the unsigned value
-- * the difference between the INTEGER_WIDTH and the leading zeros count is the floating point EXPONENT
-- * the mantissa is the unsigned fixed point value shifted right by the EXPONENT

end rtl;
