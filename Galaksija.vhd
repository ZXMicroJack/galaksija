----------------------------------------------------------------------------------
-- Galaksija
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity Galaksija is
    Port ( 	extCLK_50M 		: in  STD_LOGIC;

				PS2_CLK		: in STD_LOGIC;
				PS2_DATA		: in STD_LOGIC;
	 
				VIDEO_DATA	: out STD_LOGIC;
				VIDEO_SYNC 	: out STD_LOGIC;
				
				LATCH_D0		: out STD_LOGIC;
				LATCH_D4		: out STD_LOGIC;
				
				-- Exernal port
				DQext			: inout STD_LOGIC_VECTOR(7 downto 0);
				Aext			: out STD_LOGIC_VECTOR(7 downto 0);
				RDnext		: out STD_LOGIC;
				WRnext		: out STD_LOGIC;
				IORQnext		: out STD_LOGIC;
				M1next		: out STD_LOGIC;
				
				-- End of external port
				
				LINE_IN		: in std_logic;
				
				VGA_HSYNC 	: inout STD_LOGIC;
				VGA_VSYNC 	: inout STD_LOGIC;
				VGA_R		 	: out STD_LOGIC;
				VGA_G		 	: out STD_LOGIC;
				VGA_B		 	: out STD_LOGIC
				
			);
end Galaksija;

architecture rtl of Galaksija is
	-- Generate only Picoblaze system
--	constant picoblaze_only : boolean := true;
	constant picoblaze_only : boolean := false;

	--
	-- Z80A signals
	--
	signal A : std_logic_vector(15 downto 0); -- System address bus
	signal D : std_logic_vector(7 downto 0);
	
	signal RESET1_n : std_logic;
	signal RESET2_n : std_logic;
	
	signal RESET_n : std_logic; -- Z80A reset
	signal RFSH_n : std_logic; -- Z80A memory refresh
	signal CPU_CLK_n : std_logic; -- Z80A clock
	signal CPU_CLK_n_int : std_logic;
	signal CPU_CLK : std_logic;
	signal MREQ_n : std_logic;
	signal IORQ_n : std_logic;
	signal M1_n : std_logic;
	signal WAIT_n : std_logic;
	signal INT_n : std_logic;
	signal NMI_n : std_logic := '1';
	signal WR_n : std_logic;
	
	signal RFSH : std_logic;

	signal RD_n : std_logic;

	-- Video related signals
	signal HSYNC_DIV : std_logic_vector(9 downto 0) := "0000000000";
	signal VSYNC_DIV : std_logic_vector(9 downto 0) := "0000000001";
	signal HSYNC : std_logic;
	signal VSYNC : std_logic;
	signal VIDEO_INT : std_logic;

	signal HSYNC_Q, HSYNC_Q_n : std_logic;
	signal VSYNC_Q, VSYNC_Q_n : std_logic;
	
	signal SYNC1, SYNC2 : std_logic;
	signal SYNC : std_logic;

	signal LOAD_SCAN_LINE_n : std_logic;	
	signal LOAD_SCAN_LINE_n_int : std_logic;	

	signal dRFSH : std_logic;
	--
	-- End of Z80A signals
	--

	--
	-- Pixel clock
	-- 

	signal PDIV : std_logic_vector(3 downto 0) := "0000";
	signal PDIV_RST : std_logic;
	signal PIX_CLK_COUNTER : std_logic_vector(2 downto 0) := "000";
	signal PIX_CLK : std_logic;	-- Pixel clock, should be 6.144 MHz
	
	signal iPIX_CLK : std_logic;

	--
	-- Address decoder
	--
	signal ROM_OE_n : std_logic;
	signal ROM_A : std_logic_vector(12 downto 0);
	
	signal RAM_A7 : std_logic;
	signal RAM_A : std_logic_vector(12 downto 0);
	
	signal LATCH_KBD_CS_n : std_logic;
	signal DECODER_EN : std_logic;
	
	signal LATCH_DATA : std_logic_vector(5 downto 0) := "111111"; -- Signal from latch
	signal LATCH_D5 : std_logic;
	signal LATCH_CLK : std_logic;

	signal RAM_WR_n : std_logic;
	
	signal RAM_CS1_n, RAM_CS2_n, RAM_CS3_n, RAM_CS4_n, RAM_CS_n : std_logic;
	
	--
	-- Keyboard
	--

	signal KR : std_logic_vector(7 downto 0);	-- row select for keyboard
	signal dKR7 : std_logic;
	signal KS : std_logic_vector(7 downto 0) := "11111111";	-- Scanline for keyboard
	signal KSout : std_logic;
	signal KRsel : std_logic_vector(2 downto 0);
	signal KSsel : std_logic_vector(2 downto 0);

	--
	-- Character generator
	--

	signal LATCH_IN : std_logic_vector(5 downto 0);
	signal CHROM_A : std_logic_vector(10 downto 0);
	signal CHROM_D : std_logic_vector(7 downto 0);
	signal SHREG : std_logic_vector(7 downto 0);

	signal VIDEO_DATA_int : std_logic;

	signal CHROM_CLK : std_logic;

	signal WAIT_CLK : std_logic;
	
	--
	-- VGA
	--
	
	signal VGA_VIDEO : std_logic;

	signal HPOS : std_logic := '1';

	--
	-- Misc
	--
	signal ESC_STATE : std_logic;
	signal KEY_CODE : std_logic_vector(7 downto 0);
	signal KEY_STROBE : std_logic;
	

	signal PBLAZE_VADDR : std_logic_vector(15 downto 0);
	signal PBLAZE_VDATA : std_logic;
	signal PBLAZE_VWR : std_logic;
	signal PBLAZE_LIN : std_logic;
	signal PBLAZE_LOUT : std_logic;

	signal PBLAZE_CHADDR : std_logic_vector(10 downto 0);
	
	signal CLK_SEL : std_logic_vector(1 downto 0) := "11";
	
	signal CLK_50M, CLK_50M_VGA, CLK_50M_PBLAZE : std_logic;
	
	
	signal port_FFFF : std_logic_vector(2 downto 0) := "111";
	--
	-- Components
	-- 
	
	component T80a is
		generic(
			Mode : integer := 0	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		);
		port(
			RESET_n		: in std_logic;
			CLK_n			: in std_logic;
			WAIT_n		: in std_logic;
			INT_n			: in std_logic;
			NMI_n			: in std_logic;
			BUSRQ_n		: in std_logic;
			M1_n			: out std_logic;
			MREQ_n		: out std_logic;
			IORQ_n		: out std_logic;
			RD_n			: out std_logic;
			WR_n			: out std_logic;
			RFSH_n		: out std_logic;
			HALT_n		: out std_logic;
			BUSAK_n		: out std_logic;
			A				: out std_logic_vector(15 downto 0);
			D			: inout std_logic_vector(7 downto 0)
		);
	end component T80a;

	component reset_gen is
		 generic (CycleCount : integer := 1000000);
		 Port ( RESET_n : out  STD_LOGIC;
				  CLK : in  STD_LOGIC);
	end component reset_gen;
	
	component MMV is
		 generic( Period : integer := 1000);
		 Port ( CLK : in  STD_LOGIC;
				  TRIG : in  STD_LOGIC;
				  Q : out  STD_LOGIC;
				  Q_n : out  STD_LOGIC);
	end component MMV;

	component galaksija_rom_8k is
		 Port ( A : in  STD_LOGIC_VECTOR (12 downto 0);
				  DO : out  STD_LOGIC_VECTOR (7 downto 0);
				  OE_n : in  STD_LOGIC;
				  CE_n : in  STD_LOGIC;
				  CLK : in STD_LOGIC);
	end component galaksija_rom_8k;

	component galaksija_chgen_rom is
		 Port ( A : in  STD_LOGIC_VECTOR (10 downto 0);
				  DO : out  STD_LOGIC_VECTOR (7 downto 0);
				  OE_n : in  STD_LOGIC;
				  CE_n : in  STD_LOGIC;
				  CLK : in STD_LOGIC);
	end component galaksija_chgen_rom;

	component ram_mem_v2 is
		 generic ( AddrWidth : integer := 13; RAMFileName : string := "osrom.txt");
		 Port ( A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
				  DQ : inout  STD_LOGIC_VECTOR (7 downto 0);
				  WE_n : in  STD_LOGIC;
				  OE_n : in  STD_LOGIC;
				  CS1_n : in  STD_LOGIC;
				  CS2 : in  STD_LOGIC;
				  CLK : in STD_LOGIC
				  );
	end component ram_mem_v2;

	component composite_to_vga is
		 Port ( CLK : in  STD_LOGIC;	-- Pixel clock
				  RESET_n : in STD_LOGIC;
				  VIDEO_DATA : in  STD_LOGIC;
				  VIDEO_SYNC : in  STD_LOGIC;
				  START_FRAME_n : in  STD_LOGIC;	-- Should be connected to WAIT_n signal
				  HPOS : in STD_LOGIC;	-- Horizontal position indicator 2BA8: '1' when horizontal position = 11 else '0'

				  ESC_STATE : in STD_LOGIC;
				  CLK_W2 : in STD_LOGIC;
				  WR2 : in STD_LOGIC;
				  AWR2 : in STD_LOGIC_VECTOR(15 downto 0);
				  DIN2 : in STD_LOGIC;

				  COL_VADDR : out STD_LOGIC_VECTOR(5 downto 0);
				  COL_HADDR : out STD_LOGIC_VECTOR(5 downto 0);
				  COL_CLK : out STD_LOGIC;
				  
				  -- VGA controller signals
				  CLK_50M	: in std_logic;
				  VGA_HSYNC : inout std_logic;
				  VGA_VSYNC : inout std_logic;
				  VGA_VIDEO : out std_logic
				 );
	end component composite_to_vga;


	component galaksija_keyboard_v2 is
		 Port ( CLK : in  STD_LOGIC;
				  PS2_DATA : in  STD_LOGIC;
				  PS2_CLK : in  STD_LOGIC;
				  LINE_IN : in  STD_LOGIC := '0';
				  KR : in  STD_LOGIC_VECTOR (7 downto 0);
				  KS : out  STD_LOGIC_VECTOR (7 downto 0);
				  NMI_n : out std_logic;
				  RST_n : out std_logic;
				  ESC : out std_logic;
				  KEY_CODE : out std_logic_vector(7 downto 0);
			     KEY_STROBE : out std_logic;
				  RESET_n : in STD_LOGIC
				  );
	end component galaksija_keyboard_v2;

	component tristate_bit is
		 Port ( DIN : in  STD_LOGIC;
				  DOUT : out  STD_LOGIC;
				  EN_n : in  STD_LOGIC);
	end component tristate_bit;

	component tristate_buff is
		 Port ( DIN : in  STD_LOGIC_VECTOR(7 downto 0);
				  DOUT : out  STD_LOGIC_VECTOR(7 downto 0);
				  EN_n : in  STD_LOGIC);
	end component tristate_buff;

	component picoblaze_soc is
		 Port (
			CLK_50M : in  STD_LOGIC;
			RESET_n : in STD_LOGIC;
			KEY_STROBE : in STD_LOGIC;
			KEY_CODE : in STD_LOGIC_VECTOR(7 downto 0);
			ESC_STATE : in STD_LOGIC;

			CH_ADDR	: out STD_LOGIC_VECTOR(10 downto 0);
			CH_DATA	: in STD_LOGIC_VECTOR(7 downto 0);

			VIDEO_ADDR : out STD_LOGIC_VECTOR(15 downto 0);
			VIDEO_DATA : out STD_LOGIC;
			VIDEO_WR	  : out STD_LOGIC;

			PRAM_CLK2 : out STD_LOGIC;
			PRAM_WR2 : out STD_LOGIC;
			PRAM_DIN2 : in STD_LOGIC_VECTOR(7 downto 0);
			PRAM_DOUT2 : out STD_LOGIC_VECTOR(7 downto 0);
			PRAM_ADDR2 : out STD_LOGIC_VECTOR(12 downto 0);
			
			CLK_SEL : out STD_LOGIC_VECTOR(1 downto 0);
			
			LINE_IN : in STD_LOGIC;
			LINE_OUT : out STD_LOGIC		
		 );
	end component picoblaze_soc;

	component clk_deskew is
		port (
			CLK_IN : in STD_LOGIC;
			CLK_OUT : out STD_LOGIC;
			CLK_FB	: in STD_LOGIC
				);
	end component clk_deskew;

	component ram_mem_v3 is
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
	end component ram_mem_v3;

	component color_ram is
		 Port ( CLK_WR : in  STD_LOGIC;
				  A : in  STD_LOGIC_VECTOR (15 downto 0);
				  D : inout  STD_LOGIC_VECTOR (2 downto 0);
				  WR_n : in  STD_LOGIC;
				  MREQ_n : in  STD_LOGIC;
				  OE_n : in STD_LOGIC;
				  VADDR : in  STD_LOGIC_VECTOR (5 downto 0);
				  HADDR : in  STD_LOGIC_VECTOR (5 downto 0);
				  CLK_RD : in  STD_LOGIC;
				  COLORS : out STD_LOGIC_VECTOR(2 downto 0)
				  );
	end component color_ram;
		
	--
	-- End of components
	--
	
	signal PRAM_CLK2 : std_logic;
	signal PRAM_WR2 : std_logic;
	signal PRAM_DIN2 : std_logic_vector(7 downto 0);
	signal PRAM_DOUT2 : std_logic_vector(7 downto 0);
	signal PRAM_ADDR2 : std_logic_vector(12 downto 0);
	
	signal TMP : std_logic_vector(7 downto 0);
	
	signal KSBUF_en : std_logic;
	signal KSTMP : std_logic_vector(7 downto 0);

	signal RAM_HA : std_logic_vector(7 downto 0);

	-- Registers for clock deskewing
	signal RESET_n_50M, VIDEO_DATA_int_50M, SYNC_50M, WAIT_n_50M, HPOS_50M : std_logic;
	signal RESET_n_VGA, VIDEO_DATA_int_VGA, SYNC_VGA, WAIT_n_VGA, HPOS_VGA : std_logic;

	signal PBLAZE_VWR_P50M : std_logic;
	signal PBLAZE_VADDR_P50M : std_logic_vector(15 downto 0);
	signal PBLAZE_VDATA_P50M : std_logic;
		
	signal PBLAZE_VWR_VGA : std_logic;
	signal PBLAZE_VADDR_VGA : std_logic_vector(15 downto 0);
	signal PBLAZE_VDATA_VGA : std_logic;

	signal Dext_in : std_logic_vector(7 downto 0);
	signal Dext_outen_n : std_logic;
	signal Dext_in_en_n : std_logic;


	signal VGA_VADDR, VGA_HADDR : std_logic_vector(5 downto 0);
	signal VGA_CLK25M : std_logic;
	signal COLORS : std_logic_vector(2 downto 0);

	signal port_FFFE : std_logic := '0';
begin
	--
	-- Expansion port
	--

	Aext <= A(7 downto 0);
	RDnext <= RD_n;
	WRnext <= WR_n;
	IORQnext <= IORQ_n;
	M1next <= M1_n;
	
	-- Output buffer

iogenerate: for i in 0 to 7 generate	
	begin
	IOBUF_inst : IOBUF
		generic map (
			DRIVE => 12,
			IBUF_DELAY_VALUE => "0", -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
			IFD_DELAY_VALUE => "AUTO", -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
			IOSTANDARD => "LVTTL",
			SLEW => "SLOW")
   port map (
      O => Dext_in(i),     -- Buffer output
      IO => DQext(i),   -- Buffer inout port (connect directly to top-level port)
      I => D(i),     -- Buffer input
      T => Dext_outen_n      -- 3-state enable input 
   );
	end generate;
	
	Dext_outen_n <= WR_n or IORQ_n;

	
	Dext_in_en_n <= RD_n or IORQ_n;
	
tristategenerate: for i in 0 to 7 generate
	begin
	Dext_in_buff : tristate_bit
		port map (
					DIN => Dext_in(i),
					DOUT => D(i),
					EN_n => Dext_in_en_n
				);
	end generate;

	--
	-- CPU instantation
	--

	cpu_inst: if (picoblaze_only=false) generate
				 begin
					CPU: T80a
					generic map ( Mode => 0 )
					port map (
									A => A,
									D => D,
									BUSRQ_n => '1',	-- No bus requests
									RESET_n => RESET_n,
									RFSH_n => RFSH_n,
									CLK_n => CPU_CLK_n,
									MREQ_n => MREQ_n,
									IORQ_n => IORQ_n,
									M1_n => M1_n,
									WAIT_n => WAIT_n,
									INT_n => INT_n,
									NMI_n => NMI_n,
									WR_n => WR_n,
									RD_n => RD_n
								);
				end generate cpu_inst;

	RFSH <= not RFSH_n;

	RESET_n <= RESET1_n and RESET2_n;

	--
	-- Reset generator
	--
	RST_GEN: reset_gen
	generic map ( CycleCount => 100)
	port map (
					RESET_n => RESET1_n,
					CLK => CPU_CLK
				);
	
	--
	-- WAIT_n signal generator
	--
	
	WAIT_CLK <= not(not(M1_n) and not(IORQ_n));
	
	process (WAIT_CLK, HSYNC_Q_n)
	begin
		if (HSYNC_Q_n = '0') then
			WAIT_n <= '1';
		else
			if (WAIT_CLK'event) and (WAIT_CLK = '1') then
				WAIT_n <= '0';
			end if;
		end if;
	end process;
	
	--
	-- Pixel clock
	-- For initial release it is generated as CLK_50M/8. Fix to generate correct clock of 6.144 MHz (with DCM)
	-- 
	process(CLK_50M, PIX_CLK_COUNTER)
	begin
		if (CLK_50M'event) and (CLK_50M = '1') then
			PIX_CLK_COUNTER <= PIX_CLK_COUNTER + 1;
		end if;
	end process;

	--
	-- Clock management
	--

	CPU_CLK <= PDIV(0);
	CPU_CLK_n_int <= not CPU_CLK;
		
	CPU_CLK_n <= CPU_CLK_n_int;
	
	PIX_CLK <= iPIX_CLK;

	deskew_VGA: clk_deskew 
		port map(
						CLK_IN => extCLK_50M,
						CLK_OUT => CLK_50M_VGA,
						CLK_FB => CLK_50M_VGA
					);

	CLK_50M_PBLAZE <= extCLK_50M;
	CLK_50M <= extCLK_50M;

	-- CLK_SEL is set by Picoblaze via CPU_FREQ menu
	process (PIX_CLK_COUNTER, CLK_SEL, ESC_STATE, CLK_50M)
	begin
		if (ESC_STATE = '0') then
			case CLK_SEL is
				when "00" => iPIX_CLK <= PIX_CLK_COUNTER(2);
				when "01" => iPIX_CLK <= PIX_CLK_COUNTER(1);
				when "10" => iPIX_CLK <= PIX_CLK_COUNTER(0);
				when "11" => iPIX_CLK <= CLK_50M;
				when others => null;
			end case;
		else
			iPIX_CLK <= '0';	-- Stop Galaksija clock if Picoblaze is active
		end if;
	end process;
	
	--
	-- Pixel clock divider
	--
		
	process(PIX_CLK, PDIV_RST, PDIV)
	begin
		if (PIX_CLK'event) and (PIX_CLK='0') then
			if (PDIV = "1011") then
				PDIV <= "0000";
			else
				PDIV <= PDIV + 1;
			end if;
		end if;
	end process;

	-- Further pixel clock division to generate vertical and horizontal sync
	process (PDIV(3), HSYNC_DIV)
	begin
		if (PDIV(3)'event) and (PDIV(3)='0') then
			HSYNC_DIV <= HSYNC_DIV + 1;
		end if;
	end process;
	
	process (HSYNC_DIV(9), VSYNC_DIV)
	begin
		if (HSYNC_DIV(9)'event) and (HSYNC_DIV(9)='1') then
			VSYNC_DIV <= VSYNC_DIV(8 downto 0) & VSYNC_DIV(9);
		end if;
	end process;

	HSYNC <= HSYNC_DIV(4);
	VSYNC <= VSYNC_DIV(9);
	VIDEO_INT <= VSYNC_DIV(1);
	
	INT_n <= not VIDEO_INT;

	-- Video sync signal generation
	
	-- HSYNC MMV C3 = 5 nF R12 = 390 T=1.95 us => 98 cycles @ 50 MHz
	HSYNC_MMV: MMV
	generic map ( Period => 6)
	port map(
					TRIG => HSYNC,
					CLK => PIX_CLK,
					Q => HSYNC_Q,
					Q_n => HSYNC_Q_n
				);

	
	-- VSYNC MMV C4 = 100 nF R13 = 27 K, T = 2.7 mS => 135000 cycles @ 50 MHz
	VSYNC_MMV: MMV
	generic map (Period => 8437)
	port map(
					TRIG => VSYNC,
					CLK => PIX_CLK,
					Q => VSYNC_Q,
					Q_n => VSYNC_Q_n);
	
	SYNC1 <= not(HSYNC_Q and VSYNC_Q);
	SYNC2 <= not(VSYNC_Q_n and HSYNC_Q_n);
	
	SYNC <= not(SYNC1 and SYNC2);
	VIDEO_SYNC <= SYNC;

	
	-- Load scan line FF

	LOAD_SCAN_LINE_n <= LOAD_SCAN_LINE_n_int;

	process (CPU_CLK, LATCH_KBD_CS_n)
	begin
		if (CPU_CLK'event) and (CPU_CLK = '1') then
			dRFSH <= LATCH_KBD_CS_n;
		end if;
	end process;

	process(MREQ_n, CPU_CLK_n, RFSH, PIX_CLK, dRFSH)
	begin
			if ((RFSH = '0') and (PIX_CLK = '1')) or (dRFSH = '0') then
					LOAD_SCAN_LINE_n_int <= '1';
			else
			if (CPU_CLK_n'event) and (CPU_CLK_n='1') then
						LOAD_SCAN_LINE_n_int <= not MREQ_n;
			end if;
			end if;
	end process;

	--
	-- Address decoder
	--
		
	DECODER_EN <= (not(MREQ_n) and not(A(14))) and not(A(15));
	
	-- Keyboard and latch address decoding
	LATCH_KBD_CS_n <= '0' when ((A(11)='0') and (A(12)='0') and (A(13)='1') and (DECODER_EN = '1')) and (RFSH_n = '1')else
							'1';
							
	ROM_OE_n <= '0' when ((A(13)='0') and (DECODER_EN='1') and (RFSH = '0')) else
					'1';
					
	ROM_A <= A(12 downto 0);

	RAM_CS1_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='0') and (A(13)='1')) or (RFSH = '1') else '1';
	RAM_CS2_n <= '0' when ((DECODER_EN='1') and (A(11)='0') and (A(12)='1') and (A(13)='1')) else '1';
	RAM_CS3_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='1') and (A(13)='1')) else '1';

	-- Extended RAM (+2k)
	RAM_CS4_n <= '0' when ((A(14) = '1') and (A(15) = '0') and (A(11)= '0') and (A(12) = '0') and (A(13)='0')) else '1';

	RAM_CS_n <= RAM_CS1_n and RAM_CS2_n and RAM_CS3_n and RAM_CS4_n;
	
	RAM_WR_n <= WR_n;

	RAM_A7 <= not(not(A(7)) and LATCH_D5);
	
	RAM_A <= "00" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS1_n = '0' else
				"01" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS2_n = '0' else
				"10" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS3_n = '0' else
				"11" & A(10 downto 8) & RAM_A7 & A(6 downto 0);
				
	--
	-- RAM and ROM
	--

	mem_inst: if (picoblaze_only=false) generate
				 begin

					RAM: ram_mem_v3
					generic map ( AddrWidth => 13, RAMFileName=>"highres_ram.txt" )
					port map (
									A => RAM_A,
									DQ => D,
									WE_n => RAM_WR_n,
									OE_N => '0',
									CS1_n => RAM_CS_n,
									CS2 => '1',
									CLK => PIX_CLK ,

								   CLK2 => PRAM_CLK2,
									WR2 => PRAM_WR2,
								   DIN2 => PRAM_DIN2,
								   DOUT2 => PRAM_DOUT2,
								   ADDR2 => PRAM_ADDR2
								);

					ROM: galaksija_rom_8k
					port map (
									A => ROM_A,
									DO => D,
									OE_n => ROM_OE_n,
									CE_n => '0',
									CLK => PIX_CLK
								);
				end generate mem_inst;

	--
	-- Keyboard.
	--
		
	KRsel <= A(5) & A(4) & A(3);
	-- Select keyboard row or select latch
	process(KRsel, LATCH_KBD_CS_n)
	begin
		if (LATCH_KBD_CS_n = '0') then
			case (KRsel) is
				when "000" => KR <= "11111110";
				when "001" => KR <= "11111101";
				when "010" => KR <= "11111011";
				when "011" => KR <= "11110111";
				when "100" => KR <= "11101111";
				when "101" => KR <= "11011111";
				when "110" => KR <= "10111111";
				when "111" => KR <= "01111111";
				when others => KR <= "11111111";
			end case;
		else
			KR <= "11111111";
		end if;
	end process;
	
	
	
	KSsel <= A(2) & A(1) & A(0);
	-- Multiplex the keyboard scanlines
	process(KSsel, LATCH_KBD_CS_n, KS, RD_n)
	begin
			case KSsel is
				when "000" => KSout <= KS(0);
				when "001" => KSout <= KS(1);
				when "010" => KSout <= KS(2);
				when "011" => KSout <= KS(3);
				when "100" => KSout <= KS(4);
				when "101" => KSout <= KS(5);
				when "110" => KSout <= KS(6);
				when "111" => KSout <= KS(7);
				when others => KSout <= '1';
			end case;
	end process;

	--
	--
	--

	KSBUF_en <= LATCH_KBD_CS_n when RD_n = '0' else
					'1';
					
	KSBUF : tristate_bit
	port map (
					DIN => KSOut,
					DOUT => D(0),
					EN_n => KSBUF_en
				);
	
  
	--
	-- PS2 Keyboard
	--
	PS2_KBD: galaksija_keyboard_v2
   Port map ( 
			  CLK => CLK_50M,
			  NMI_n => NMI_n,
           PS2_DATA => PS2_DATA,
           PS2_CLK => PS2_CLK,
           LINE_IN => LINE_IN,
           KR => KR,
           KS => KS,
			  RST_n => RESET2_n,
			  ESC => ESC_STATE,
			  KEY_CODE => KEY_CODE,
			  KEY_STROBE => KEY_STROBE,
			  RESET_n => RESET1_n
			  );
	
	--
	-- Character generator
	--
	
	-- Latch
	
	LATCH_CLK <= PIX_CLK;
	LATCH_IN <= D(7 downto 2);
	
	process(LATCH_CLK, LATCH_IN, dKR7)
	begin
		if (LATCH_CLK'event) and (LATCH_CLK = '1') then
			if (KR(7) = '0') then
				LATCH_DATA <= LATCH_IN;
			end if;
		end if;
	end process;
	
	LATCH_D5 <= LATCH_DATA(5);
	LATCH_D4 <= LATCH_DATA(4);
	LATCH_D0 <= LATCH_DATA(0);

	process(D, PIX_CLK)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
			TMP <= D;
		end if;
	end process;
	
	-- Character generator address	
	CHROM_A <= LATCH_DATA(3 downto 0) & TMP(7) & TMP(5 downto 0) when ESC_STATE = '0' else
				  PBLAZE_CHADDR;
	CHROM_CLK <= PIX_CLK when ESC_STATE = '0' else
					 CLK_50M;

	CH_GEN_ROM: galaksija_chgen_rom
	port map (
					A => CHROM_A,
					DO => CHROM_D,
					OE_n => '0',
					CE_n => '0',
					CLK => CHROM_CLK
				);
	
	-- Video shift register
	process(PIX_CLK, LOAD_SCAN_LINE_n, SHREG)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
			if (LOAD_SCAN_LINE_n = '0') then
				SHREG <= CHROM_D;
			else
				SHREG <= SHREG(6 downto 0) & '0';
			end if;
		end if;
	end process;
		
	VIDEO_DATA_int <=  not SHREG(7) when SYNC = '1' else
                      '0'; -- Blank video when SYNC is active

	VIDEO_DATA <= VIDEO_DATA_int;

	--
	-- VGA output
	-- The following code is not a part of original Galaksija, and may be removed
	-- This block converts composite video generated by Galaksija to VGA output
	--

	--
	-- Register signals to avoid excessive clock skew
	--

		process (CLK_50M, VIDEO_DATA_int, SYNC, WAIT_n, RESET_n, HPOS)
		begin
			if (CLK_50M'event) and (CLK_50M = '1') then
				RESET_n_50M <= RESET_n;
				VIDEO_DATA_int_50M <= VIDEO_DATA_int;
				SYNC_50M <= SYNC;
				WAIT_n_50M <= WAIT_n;
				HPOS_50M <= HPOS;
			end if;
		end process;

		process (PIX_CLK, VIDEO_DATA_int_50M, SYNC_50M, WAIT_n_50M, RESET_n_50M, HPOS_50M)
		begin
			if (PIX_CLK'event) and (PIX_CLK = '1') then
				SYNC_VGA <= SYNC_50M;
				WAIT_n_VGA <= WAIT_n_50M;
				RESET_n_VGA <= RESET_n_50M;
				VIDEO_DATA_int_VGA <= VIDEO_DATA_int_50M;
				HPOS_VGA <= HPOS_50M;
			end if;
		end process;

		process(CLK_50M_PBLAZE, PBLAZE_VWR, PBLAZE_VADDR, PBLAZE_VDATA)
		begin
			if (CLK_50M_PBLAZE'event) and (CLK_50M_PBLAZE = '1') then
				PBLAZE_VWR_P50M <= PBLAZE_VWR;
				PBLAZE_VADDR_P50M <= PBLAZE_VADDR;
				PBLAZE_VDATA_P50M <= PBLAZE_VDATA;
			end if;
		end process;

		process(CLK_50M_VGA, PBLAZE_VWR_P50M, PBLAZE_VADDR_P50M, PBLAZE_VDATA_P50M)
		begin
			if (CLK_50M_VGA'event) and (CLK_50M_VGA = '1') then
				PBLAZE_VWR_VGA <= PBLAZE_VWR_P50M;
				PBLAZE_VADDR_VGA <= PBLAZE_VADDR_P50M;
				PBLAZE_VDATA_VGA <= PBLAZE_VDATA_P50M;
			end if;
		end process;

	--
	--
	--

	VGAOUT: composite_to_vga
				port map(
								CLK => PIX_CLK,
								RESET_n => RESET_n_VGA,
								VIDEO_DATA => VIDEO_DATA_int_VGA,
								VIDEO_SYNC => SYNC_VGA,
								START_FRAME_n => WAIT_n_VGA,
								HPOS => HPOS_VGA,
								
								ESC_STATE => ESC_STATE,
								CLK_W2 => CLK_50M_VGA,
								WR2 => PBLAZE_VWR_VGA,
								AWR2 => PBLAZE_VADDR_VGA,
								DIN2 => PBLAZE_VDATA_VGA,

								COL_VADDR => VGA_VADDR,
								COL_HADDR => VGA_HADDR,
								COL_CLK => VGA_CLK25M,
																
								CLK_50M => CLK_50M_VGA,
								VGA_HSYNC => VGA_HSYNC,
								VGA_VSYNC => VGA_VSYNC,
								VGA_VIDEO => VGA_VIDEO
							);
	
	VGA_R <= VGA_VIDEO and not(port_FFFF(2)) when port_FFFE = '0' else
				VGA_VIDEO and not(COLORS(2));
	VGA_G <= VGA_VIDEO and not(port_FFFF(1)) when port_FFFE = '0' else
				VGA_VIDEO and not(COLORS(1));
	VGA_B <= VGA_VIDEO and not(port_FFFF(0)) when port_FFFE = '0' else
				VGA_VIDEO and not(COLORS(0));
	
	-- Color

	-- Color is specified by writing to the port FFFF
	process(RESET_n, PIX_CLK, D, A, WR_n)
	begin
		if (RESET_n = '0') then
			port_FFFF <= "000";
		else
			if (PIX_CLK'event) and (PIX_CLK = '1') then
				if (WR_n = '0') and (MREQ_n = '0') and (A = X"FFFF") then
						port_FFFF <= D(2 downto 0);
				end if;
			end if;
		end if;
	end process;

	-- Color RAM activation register - overrides register FFFF settings
	process(RESET_n, PIX_CLK, D, A, WR_n)
	begin
		if (RESET_n = '0') then
			port_FFFE <= '0';
		else
			if (PIX_CLK'event) and (PIX_CLK = '1') then
				if (WR_n = '0') and (MREQ_n = '0') and (A = X"FFFE") then
						port_FFFE <= D(0);
				end if;
			end if;
		end if;
	end process;

	CRAM: color_ram 
		 Port map ( CLK_WR => PIX_CLK,
						A => A, 
						D => D(2 downto 0),
						WR_n => WR_n,
						MREQ_n => MREQ_n,
						OE_n => RD_n,
						VADDR => VGA_VADDR,
						HADDR => VGA_HADDR,
						CLK_RD => VGA_CLK25M,
						COLORS => COLORS
				  );
	
	--
	-- End of VGA output
	--

	--
	-- A simple circuit to monitor software horizontal position
	--

	process (PIX_CLK, RAM_WR_n, RAM_CS_n, A)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
			if (RAM_WR_n = '0') and (RAM_CS_n = '0') and (A = X"2BA8") then
				if (D = X"0B") then
					HPOS <= '1';
				else
					HPOS <= '0';
				end if;
			end if;
		end if;
	end process;
		
	--
	-- Picoblaze system for data storage
	--
	
	pblaze_soc: picoblaze_soc 
		 Port map(
			CLK_50M => CLK_50M_PBLAZE,
			RESET_n => RESET_n,
			KEY_STROBE => KEY_STROBE,
			KEY_CODE => KEY_CODE,
			ESC_STATE => ESC_STATE,
			
			CH_ADDR => PBLAZE_CHADDR,
			CH_DATA => CHROM_D,

			VIDEO_ADDR => PBLAZE_VADDR,
			VIDEO_DATA => PBLAZE_VDATA,
			VIDEO_WR	  => PBLAZE_VWR,
			
			PRAM_CLK2 => PRAM_CLK2,
			PRAM_WR2 => PRAM_WR2,
			PRAM_DIN2 => PRAM_DOUT2,
			PRAM_DOUT2 => PRAM_DIN2,
			PRAM_ADDR2 => PRAM_ADDR2,
			
			CLK_SEL => CLK_SEL,
			
			LINE_IN => PBLAZE_LIN,
			LINE_OUT => PBLAZE_LOUT
		 );
		
	--
	--
	--
	
end rtl;
