----------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity picoblaze is
	generic ( ROMFileName : string := "test_simple.rom");
    Port ( 
					 port_id: out    std_logic_vector( 7 downto 0);
					 write_strobe: out    std_logic;
					 out_port: out    std_logic_vector( 7 downto 0);
					 read_strobe: out    std_logic;
					 in_port: in    std_logic_vector( 7 downto 0);
					 interrupt: in    std_logic;
					 interrupt_ack: out    std_logic;
					 reset: in    std_logic;
					 clk: in    std_logic
			);

end picoblaze;

architecture rtl of picoblaze is
	 component KCPSM3
			port (
					 address: out    std_logic_vector( 9 downto 0);
					 instruction: in    std_logic_vector(17 downto 0);
					 port_id: out    std_logic_vector( 7 downto 0);
					 write_strobe: out    std_logic;
					 out_port: out    std_logic_vector( 7 downto 0);
					 read_strobe: out    std_logic;
					 in_port: in    std_logic_vector( 7 downto 0);
					 interrupt: in    std_logic;
					 interrupt_ack: out    std_logic;
					 reset: in    std_logic;
					 clk: in    std_logic
				  );
			end component KCPSM3;
			
	component picoblaze_rom is
	 generic (ROMFileName : string);
    Port (      address : in std_logic_vector(9 downto 0);
            instruction : out std_logic_vector(17 downto 0);
                    clk : in std_logic);
    end component picoblaze_rom;
			
			
	signal address: std_logic_vector( 9 downto 0);
	signal instruction: std_logic_vector(17 downto 0);
begin
	CPU : KCPSM3
	port map (
					address => address,
					instruction => instruction,
					port_id => port_id,
					write_strobe => write_strobe,
					out_port => out_port,
					read_strobe => read_strobe,
					in_port => in_port,
					interrupt => interrupt,
					interrupt_ack => interrupt_ack,
					reset => reset,
					clk => clk
				);

	ROM : picoblaze_rom
	generic map ( ROMFileName => ROMFileName)
	port map (
					address => address,
					instruction => instruction,
					clk => clk
				);

end rtl;

