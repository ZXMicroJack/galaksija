----------------------------------------------------------------------------------
-- Asynchronous RAM
-- Used to emulate 6264 and similar
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;


entity ram_mem_v3 is
	 generic ( AddrWidth : integer := 13;
					RAMFileName : string);
    Port ( A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
           DQ : inout  STD_LOGIC_VECTOR (7 downto 0);
           WE_n : in  STD_LOGIC;
           OE_n : in  STD_LOGIC;
           CS1_n : in  STD_LOGIC;
           CS2 : in  STD_LOGIC;
			  CLK : in STD_LOGIC;
			  
			  -- Secondary RAM port
			  CLK2 : in STD_LOGIC;
			  WR2 : in STD_LOGIC;
			  DIN2 : in STD_LOGIC_VECTOR(7 downto 0);
			  DOUT2 : out STD_LOGIC_VECTOR(7 downto 0);
			  ADDR2 : in STD_LOGIC_VECTOR(AddrWidth-1 downto 0)
			  );
end ram_mem_v3;

architecture rtl of ram_mem_v3 is
	-- Data types
	type Mem_Image is array(natural range <>) of bit_vector(7 downto 0);
	
	 -- Function to load ROM contents from file
    impure function LoadROM (ROMFileName : in string) return Mem_Image is
       FILE ROMFile		: text is in ROMFileName;                       
       variable str_line	: line;                                 
       variable ROM		: Mem_Image(0 to 2**AddrWidth-1);                                      
    begin                                                        
       for I in ROM'range loop                                  
           readline (ROMFile, str_line);                             
           read (str_line, ROM(I));                                  
       end loop;                                                    
       return ROM;                                                  
    end function;                                                

	-- RAM array
--	signal RAM : Mem_Image(0 to 2**AddrWidth-1) := LoadROM(RAMFileName);
	shared variable RAM : Mem_Image(0 to 2**AddrWidth-1) := LoadROM(RAMFileName);
	
	-- Composite enable signal
	signal Enable : std_logic;
	
	signal w : std_logic;

	signal dint : std_logic_vector(7 downto 0);
begin
	Enable <= CS2 and not(CS1_n);
	
	process(Enable, WE_n)
	begin
		if (Enable = '1') then
			w <= not WE_n;
		else
			w <= '0';
		end if;
	end process;
	
	process(A, OE_n, WE_n, CLK, Enable, w)
	begin
		if (CLK'event) and (CLK = '1') then
				dint <= to_stdlogicvector(RAM(conv_integer(A)));
				if (w = '1') then
					RAM(conv_integer(A)) := to_bitvector(DQ);
				end if;
		end if;
	end process;
		
	-- Secondary RAM port for Picoblaze access	
	process (CLK2, ADDR2, WR2, DIN2)
	begin
		if (CLK2'event) and (CLK2 = '1') then
			DOUT2 <= to_stdlogicvector(RAM(conv_integer(ADDR2)));
			if (WR2 = '1') then
				RAM(conv_integer(ADDR2)) := to_bitvector(DIN2);
			end if;
		end if;
	end process;

	-- Output buffer
	process(Enable, OE_n, dint, w)
	begin
		if (Enable = '1') and (OE_n = '0') and (w = '0') then
			DQ <= dint;
		else
			DQ <= (others => 'Z');
		end if;
	end process;

end rtl;

