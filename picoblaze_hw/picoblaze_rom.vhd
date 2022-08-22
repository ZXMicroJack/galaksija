----------------------------------------------------------------------------------
--
-- ROM block
-- Can be used to emulate 27Cxxx style EEPROMs
-- Memory contents initialization file is specified as generic
-- ROM initialization file format:
-- Every line should contain exactly 8 zeros or ones
-- representing the byte value in binary notation (MSB is on the left)
-- First line represents the byte at address 0, second line at address 1 etc.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;


entity picoblaze_rom is
	 generic ( ROMFileName : string);
    Port (      address : in std_logic_vector(9 downto 0);
            instruction : out std_logic_vector(17 downto 0);
                    clk : in std_logic);
    end picoblaze_rom;

architecture low_level_definition of picoblaze_rom is

    type Mem_Image is array(0 to 1023) of bit_vector(17 downto 0);    
	 
	 -- Function to load ROM contents from file
    impure function LoadROM (ROMFileName : in string) return Mem_Image is
       FILE ROMFile		: text is in ROMFileName;                       
       variable str_line	: line;                                 
       variable ROM		: Mem_Image;                                      
    begin                                                        
       for I in ROM'range loop                                  
           readline (ROMFile, str_line);                             
           read (str_line, ROM(I));                                  
       end loop;                                                    
       return ROM;                                                  
    end function;                                                

    signal ROM : Mem_Image := LoadROM(ROMFileName);
begin
	
	process(clk, address)
	begin
		if (CLK'event) and (CLK='1') then
			instruction <= to_stdlogicvector(ROM(conv_integer(address)));
		end if;
	end process;
	
end low_level_definition;

