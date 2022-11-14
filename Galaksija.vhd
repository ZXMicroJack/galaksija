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
	 
-- 				VIDEO_DATA	: out STD_LOGIC;
-- 				VIDEO_SYNC 	: out STD_LOGIC;
-- 				
-- 				LATCH_D0		: out STD_LOGIC;
-- 				LATCH_D4		: out STD_LOGIC;
				
				-- Exernal port
-- 				DQext			: inout STD_LOGIC_VECTOR(7 downto 0);
-- 				Aext			: out STD_LOGIC_VECTOR(7 downto 0);
-- 				RDnext		: out STD_LOGIC;
-- 				WRnext		: out STD_LOGIC;
-- 				IORQnext		: out STD_LOGIC;
-- 				M1next		: out STD_LOGIC;
				
				-- End of external port
				
				LINE_IN		: in std_logic;
				AUDIO_LEFT : out std_logic;
				AUDIO_RIGHT : out std_logic;
				
				VGA_HSYNC 	: inout STD_LOGIC;
				VGA_VSYNC 	: inout STD_LOGIC;
				VGA_R : out STD_LOGIC_VECTOR(2 downto 0);
				VGA_G : out STD_LOGIC_VECTOR(2 downto 0);
				VGA_B : out STD_LOGIC_VECTOR(2 downto 0);
				
				STDN : out std_logic;
				STDNB : out std_logic;

        SRAM_ADDR : out std_logic_vector(15 downto 0);
        SRAM_DATA : inout std_logic_vector(7 downto 0);
        SRAM_WE_N : out std_logic
				
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
	signal RI : std_logic_vector(2 downto 0);
	signal GI : std_logic_vector(2 downto 0);
	signal BI : std_logic_vector(2 downto 0);

	signal HSYNC_Q, HSYNC_Q_n : std_logic;
	signal VSYNC_Q, VSYNC_Q_n : std_logic;
	
	signal SYNC1, SYNC2 : std_logic;
	signal SYNC : std_logic;

	signal LOAD_SCAN_LINE_n : std_logic;	
	signal LOAD_SCAN_LINE_n_int : std_logic;	
  signal LOAD_SCAN_LINE_n_prev : std_logic;
	
	signal dRFSH : std_logic;
	--
	-- End of Z80A signals
	--

	--
	-- Pixel clock
	-- 

	signal PDIV : std_logic_vector(3 downto 0) := "0000";
	signal PDIV2 : std_logic_vector(11 downto 0) := X"000";
	signal PDIV_RST : std_logic;
	signal PIX_CLK_COUNTER : std_logic_vector(2 downto 0) := "000";
	signal PIX_CLK : std_logic;	-- Pixel clock, should be 6.144 MHz
	
	signal iPIX_CLK : std_logic;
	signal KEYB_CLK : std_logic;

	--
	-- Address decoder
	--
	signal ROM_OE_n : std_logic;
	signal ROM_A : std_logic_vector(12 downto 0);
	
	signal RAM_A7 : std_logic;
	signal RAM_A : std_logic_vector(12 downto 0);
	
	signal LATCH_KBD_CS_n : std_logic;
	signal DECODER_EN : std_logic;
	
	signal LATCH_DATA : std_logic_vector(5 downto 0) := "111111"; -- Signal from latchs
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
	signal cram_out : std_logic_vector(2 downto 0);
  signal CRAM_WEN : std_logic;

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
	
-- 	signal CLK_SEL : std_logic_vector(1 downto 0) := "11";
	signal CLK_SEL : std_logic_vector(1 downto 0) := "00";
	
	signal CLK_50M, CLK_50M_VGA, CLK_50M_PBLAZE : std_logic;
	
	
	signal port_FFFF : std_logic_vector(2 downto 0) := "111";
	signal CAS_N : std_logic;
	signal CAS_P : std_logic;
	signal CAS_Z : std_logic;
	signal CAS_NZ : std_logic;

  signal VGA_HSYNC_int    : std_logic;
  signal VGA_VSYNC_int    : std_logic;
  signal VGA_R_int                        : std_logic;
  signal VGA_G_int                        : std_logic;
  signal VGA_B_int                        : std_logic;
  signal VIDEO_DATA       : std_logic;
  signal VIDEO_SYNC       : std_logic;
  signal VIDEO_DATA_R : std_logic;
  signal VIDEO_DATA_G : std_logic;
  signal VIDEO_DATA_B : std_logic;
  
  signal SRAM_CS_n : std_logic;
  signal SRAM_CS1_n : std_logic;
  signal SRAM_CS2_n : std_logic;
	
	-- 0x80 if z, 0xff if p, and 0x00 if n
	
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

-- 				  ESC_STATE : in STD_LOGIC;
-- 				  CLK_W2 : in STD_LOGIC;
-- 				  WR2 : in STD_LOGIC;
-- 				  AWR2 : in STD_LOGIC_VECTOR(15 downto 0);
-- 				  DIN2 : in STD_LOGIC;

				  COL_VADDR : out STD_LOGIC_VECTOR(5 downto 0);
				  COL_HADDR : out STD_LOGIC_VECTOR(5 downto 0);
				  COL_CLK : out STD_LOGIC;
				  
				  -- VGA controller signals
				  CLK_50M	: in std_logic;
				  VGA_HSYNC : inout std_logic;
				  VGA_VSYNC : inout std_logic;
				  VGA_VIDEO : out std_logic;
				  VGA_MODE : in std_logic
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
				  RESET_n : in STD_LOGIC;
          VIDEO_toggle : out std_logic			  
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
	signal COL_VADDR, COL_HADDR : std_logic_vector(10 downto 0);
	signal COLORS : std_logic_vector(2 downto 0);

	signal port_FFFE : std_logic := '0';
-- 	signal cass_out : std_logic;
	signal audio_out : std_logic;
	signal DAC_IN : std_logic_vector(7 downto 0);
	signal CLK_12M288 : std_logic;
	signal CLK_12M288B : std_logic;
  signal VIDEO_toggle : std_logic;
  signal VGA_MODE : std_logic := '1';

	signal SCAN_VADDR, SCAN_HADDR : std_logic_vector(10 downto 0);
  
  
begin
	--
	-- Expansion port
	--

-- 	Aext <= A(7 downto 0);
-- 	RDnext <= RD_n;
-- 	WRnext <= WR_n;
-- 	IORQnext <= IORQ_n;
-- 	M1next <= M1_n;
	STDN <= '0';
	STDNB <= '1';
	
	-- Output buffer

-- iogenerate: for i in 0 to 7 generate	
-- 	begin
-- 	IOBUF_inst : IOBUF
-- 		generic map (
-- 			DRIVE => 12,
-- 			IBUF_DELAY_VALUE => "0", -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
-- 			IFD_DELAY_VALUE => "AUTO", -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
-- 			IOSTANDARD => "LVTTL",
-- 			SLEW => "SLOW")
--    port map (
--       O => Dext_in(i),     -- Buffer output
--       IO => DQext(i),   -- Buffer inout port (connect directly to top-level port)
--       I => D(i),     -- Buffer input
--       T => Dext_outen_n      -- 3-state enable input 
--    );
-- 	end generate;
-- 	
-- 	Dext_outen_n <= WR_n or IORQ_n;

	
-- 	Dext_in_en_n <= RD_n or IORQ_n;
	
-- tristategenerate: for i in 0 to 7 generate
-- 	begin
-- 	Dext_in_buff : tristate_bit
-- 		port map (
-- 					DIN => Dext_in(i),
-- 					DOUT => D(i),
-- 					EN_n => Dext_in_en_n
-- 				);
-- 	end generate;
	
	--
	-- clock generation
	--
	clocks: entity work.clock
    port map(
      CLK_IN1 => extCLK_50M,
      CLK_OUT1 => CLK_12M288,
      CLK_OUT2 => CLK_12M288B,
      RESET => '0',
      LOCKED => open
    );

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
	
	process(CLK_12M288, PIX_CLK_COUNTER)
	begin
		if (CLK_12M288'event) and (CLK_12M288 = '1') then
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

-- 	deskew_VGA: clk_deskew 
-- 		port map(
-- 						CLK_IN => extCLK_50M,
-- 						CLK_OUT => CLK_50M_VGA,
-- 						CLK_FB => CLK_50M_VGA
-- 					);
--   CLK_50M_VGA <= extCLK_50M;
--   CLK_50M_VGA <= CLK_12M288B;

-- 	CLK_50M_PBLAZE <= extCLK_50M;
-- 	CLK_50M <= extCLK_50M;
	CLK_50M <= CLK_12M288;

	-- CLK_SEL is set by Picoblaze via CPU_FREQ menu
	process (PIX_CLK_COUNTER, CLK_SEL, ESC_STATE, CLK_12M288)
	begin
		if (ESC_STATE = '0') then
			case CLK_SEL is
				when "00" => iPIX_CLK <= PIX_CLK_COUNTER(0);
				when "01" => iPIX_CLK <= CLK_12M288;
				when "10" => iPIX_CLK <= PIX_CLK_COUNTER(0);
				when "11" => iPIX_CLK <= CLK_12M288;
				when others => null;
			end case;
		else
			iPIX_CLK <= '0';	-- Stop Galaksija clock if Picoblaze is active
		end if;
	end process;
	
  KEYB_CLK        <= PIX_CLK_COUNTER(0);      -- 6,25 MHz
	
	--
	-- Pixel clock divider at 6.144MHz
	-- Reset at PDIV(3 downto 2) = "11" -> 512kHz
		
	process(PIX_CLK, PDIV_RST, PDIV)
	begin
		if (PIX_CLK'event) and (PIX_CLK='0') then
			if (PDIV(3 downto 0) = "1011") then
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
-- 	generic map ( Period => 6)
	generic map ( Period => 24)
	port map(
					TRIG => HSYNC,
					CLK => PIX_CLK,
					Q => HSYNC_Q,
					Q_n => HSYNC_Q_n
				);

	
	-- VSYNC MMV C4 = 100 nF R13 = 27 K, T = 2.7 mS => 135000 cycles @ 50 MHz
	VSYNC_MMV: MMV
	generic map (Period => 8437)
-- 	generic map (Period => 7273)
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

-- 	PIX_CLK_COUNTER(1)
-- 	
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
  -- ll = MREQ and RFSH and PIX_CLK_COUNTER(1)
--   LOAD_SCAN_LINE_n_int <= not (PIX_CLK_COUNTER(1) and (not MREQ_n) and RFSH);
  -- TODO get this right
--   LOAD_SCAN_LINE_n_int <= not (PIX_CLK_COUNTER(1) and (not MREQ_n) and RFSH);
--   LOAD_SCAN_LINE_n_int <= (not MREQ_n) and (not RFSH_n);

	--
	-- Address decoder
	--
		
	DECODER_EN <= (not(MREQ_n) and not(A(14))) and not(A(15));
	
	-- Keyboard and latch address decoding
-- 	LATCH_KBD_CS_n <= '0' when 
--     ((A(11)='0') and (A(12)='0') and (A(13)='1') and (DECODER_EN = '1')) and (RFSH_n = '1')
--     else '1';
	LATCH_KBD_CS_n <= '0' when 
    ((A(11)='0') and (A(12)='0') and (A(13)='1') and (DECODER_EN = '1'))
    else '1';

    
	ROM_OE_n <= '0' when ((A(13)='0') and (DECODER_EN='1') and (RFSH = '0')) else
					'1';
					
	ROM_A <= A(12 downto 0);

	RAM_CS1_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='0') and (A(13)='1')) or (RFSH = '1') else '1';
	RAM_CS2_n <= '0' when ((DECODER_EN='1') and (A(11)='0') and (A(12)='1') and (A(13)='1')) else '1';
	RAM_CS3_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='1') and (A(13)='1')) else '1';
	
	-- gives us 32k expansion
-- 	SRAM_CS1_n <= '0' when MREQ_n = '0' and (A(15)='1' xor A(14)='1') else '1';
	SRAM_CS1_n <= '1';

	-- 48k expansion
-- 	SRAM_CS2_n <= '0' when MREQ_n = '0' and (A(15)='1' and A(14)='1') else '1';
	SRAM_CS2_n <= '1';
	
	-- uncomment for 6k
-- 	SRAM_CS_n <= '1';
	
-- 	SRAM_CS_n <= '0' when MREQ_n = '0' and (A(15)='1' or A(14)='1') and (A(15 downto 14) /= "11") else '1';
	SRAM_CS_n <= '0' when MREQ_n = '0' and (A(15)='1' or A(14)='1') and (A(15 downto 13) /= "111") else '1';
-- 	SRAM_CS_n <= SRAM_CS1_n and SRAM_CS2_n;
	
	-- 4000 - E000
	-- 0100 ....  1011
	-- 010 011 100 101 110 
	

	-- Extended RAM (+2k)
-- 	RAM_CS4_n <= '0' when ((A(14) = '1') and (A(15) = '0') and (A(11)= '0') and (A(12) = '0') and (A(13)='0')) else '1';
	RAM_CS4_n <= '1';

	RAM_CS_n <= RAM_CS1_n and RAM_CS2_n and RAM_CS3_n and RAM_CS4_n;
	
	RAM_WR_n <= WR_n;

	RAM_A7 <= not(not(A(7)) and LATCH_D5);
	
	RAM_A <= "00" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS1_n = '0' else
				"01" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS2_n = '0' else
				"10" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS3_n = '0' else
				"11" & A(10 downto 8) & RAM_A7 & A(6 downto 0);
				
				
	--
	-- SRAM
	--
	SRAM_ADDR(15 downto 0) <= A(15 downto 8) & RAM_A7 & A(6 downto 0);
	SRAM_DATA(7 downto 0) <= D(7 downto 0) when SRAM_CS_n = '0' and WR_n = '0' else (others => 'Z');
	SRAM_WE_N <= '0' when SRAM_CS_n = '0' and WR_n = '0' else '1';
	D(7 downto 0) <= SRAM_DATA(7 downto 0) when SRAM_CS_n = '0' and RD_n = '0' else (others => 'Z');

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
-- 			  CLK => CLK_50M,
        CLK => KEYB_CLK,
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
			  RESET_n => RESET1_n,
			  VIDEO_toggle => VIDEO_toggle
			  );
	
	--
	-- Character generator
	--
	
	-- Latch
	
	LATCH_CLK <= PIX_CLK;
	LATCH_IN <= D(7 downto 2);

	
	-- Loadscan_ne : nor(a,0,0), a : nor(nMREQ,nRFRSH,nCLK) 
	-- to S/nC -> active low load parallel
	process(LATCH_CLK, LATCH_IN, dKR7)
	begin
		if (LATCH_CLK'event) and (LATCH_CLK = '1') then
      -- nor nWrite nMreq O7
      -- O7 = 0 when A3..5 = '111'
      -- /WR or /KR7 or /MREQ
      -- TODO get this right
			if (KR(7) = '0' and WR_n = '0' and MREQ_n = '0') then
-- 			if (MREQ_n = '0' and RFSH_n = '0') then
				LATCH_DATA <= LATCH_IN;
			end if;
		end if;
	end process;
	
	LATCH_D5 <= LATCH_DATA(5);
-- 	LATCH_D4 <= LATCH_DATA(4);
-- 	LATCH_D0 <= LATCH_DATA(0);
	
  --LATCH_D6 <= LATCH_DATA(6); -- cassette port output bit 0
  --LATCH_D2 <= LATCH_DATA(2); -- cassette port output bit 1
  --Cassette port is high if both output bits are 1, low if both are 0 and
  --zero if one bit is 1 and one is 0.
  --pulse is 134 samples 2 pulses in 134 samples for 1.
  
--   cass_out <= LATCH_DATA(4) and LATCH_DATA(0);
  
	process(D, PIX_CLK)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
			TMP <= D;
		end if;
	end process;
	
	-- Character generator address	
	CHROM_A <= LATCH_DATA(3 downto 0) & TMP(7) & TMP(5 downto 0) when ESC_STATE = '0' else PBLAZE_CHADDR;
-- 	CHROM_CLK <= PIX_CLK when ESC_STATE = '0' else CLK_50M;
	CHROM_CLK <= PIX_CLK when ESC_STATE = '0' else '0';

	CH_GEN_ROM: galaksija_chgen_rom
	port map (
					A => CHROM_A,
					DO => CHROM_D,
					OE_n => '0',
					CE_n => '0',
					CLK => CHROM_CLK
				);
	
	-- Video shift register
-- 	process(PIX_CLK, LOAD_SCAN_LINE_n, SHREG)
-- 	begin
-- 		if (PIX_CLK'event) and (PIX_CLK = '1') then
-- 			if (LOAD_SCAN_LINE_n = '0') then
-- 				SHREG <= CHROM_D;
-- 			else
-- 				SHREG <= SHREG(6 downto 0) & '0';
-- 			end if;
-- 		end if;
-- 	end process;
  process(PIX_CLK, LOAD_SCAN_LINE_n, SHREG)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
      LOAD_SCAN_LINE_n_prev <= LOAD_SCAN_LINE_n;
			if (LOAD_SCAN_LINE_n_prev = '1' and LOAD_SCAN_LINE_n = '0') then
				SHREG <= CHROM_D;
			else
				SHREG <= SHREG(6 downto 0) & '1';
			end if;
		end if;
	end process;
	

	--MJ

	process(PIX_CLK,VSYNC_Q_n,LOAD_SCAN_LINE_n_prev,LOAD_SCAN_LINE_n,LOAD_SCAN_LINE_n_prev)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
      if (VSYNC_Q_n = '0') then
        SCAN_HADDR(10 downto 0) <= "00000000000";
        SCAN_VADDR(10 downto 0) <= "00000000000";
      elsif (SCAN_HADDR(10 downto 0) = "00000000000") then
        if (LOAD_SCAN_LINE_n_prev = '1' and LOAD_SCAN_LINE_n = '0') then
          SCAN_HADDR <= SCAN_HADDR + 1;
        end if;
      elsif (HSYNC_Q_n = '0') then
        SCAN_HADDR(10 downto 0) <= "00000000000";
        SCAN_VADDR <= SCAN_VADDR + 1;
      else
        SCAN_HADDR <= SCAN_HADDR + 1;
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

		process (CLK_12M288, VIDEO_DATA_int, SYNC, WAIT_n, RESET_n, HPOS)
		begin
			if (CLK_12M288'event) and (CLK_12M288 = '1') then
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

-- 		process(CLK_50M_PBLAZE, PBLAZE_VWR, PBLAZE_VADDR, PBLAZE_VDATA)
-- 		begin
-- 			if (CLK_50M_PBLAZE'event) and (CLK_50M_PBLAZE = '1') then
-- 				PBLAZE_VWR_P50M <= PBLAZE_VWR;
-- 				PBLAZE_VADDR_P50M <= PBLAZE_VADDR;
-- 				PBLAZE_VDATA_P50M <= PBLAZE_VDATA;
-- 			end if;
-- 		end process;
-- 
-- 		process(CLK_50M_VGA, PBLAZE_VWR_P50M, PBLAZE_VADDR_P50M, PBLAZE_VDATA_P50M)
-- 		begin
-- 			if (CLK_50M_VGA'event) and (CLK_50M_VGA = '1') then
-- 				PBLAZE_VWR_VGA <= PBLAZE_VWR_P50M;
-- 				PBLAZE_VADDR_VGA <= PBLAZE_VADDR_P50M;
-- 				PBLAZE_VDATA_VGA <= PBLAZE_VDATA_P50M;
-- 			end if;
-- 		end process;

	--
	--
	--

      VGA_RGB_SWITCH : process(VGA_MODE, VIDEO_toggle) begin
        if (VIDEO_toggle'event) and (VIDEO_toggle = '1') then
          VGA_MODE <= not VGA_MODE;
        end if;
      end process;
       
--       VGA_R <= VGA_R_int when VGA_MODE = '1' else VIDEO_DATA;
--       VGA_G <= VGA_G_int when VGA_MODE = '1' else VIDEO_DATA;
--       VGA_B <= VGA_B_int when VGA_MODE = '1' else VIDEO_DATA;
--       VGA_HSYNC <= VGA_HSYNC_int when VGA_MODE = '1' else VIDEO_SYNC;
--       VGA_VSYNC <= VGA_VSYNC_int when VGA_MODE = '1' else '1';

--       VGA_R <= VGA_R_int&VGA_R_int&VGA_R_int;
--       VGA_G <= VGA_G_int&VGA_G_int&VGA_G_int;
--       VGA_B <= VGA_B_int&VGA_B_int&VGA_B_int;
--       VGA_HSYNC <= VGA_HSYNC_int when VGA_MODE = '1' else (VGA_HSYNC_int xor (not VGA_VSYNC_int));
--       VGA_VSYNC <= VGA_VSYNC_int when VGA_MODE = '1' else '1';


      -- THIS WORKS
--       VGA_R <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       VGA_G <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       VGA_B <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       VGA_HSYNC <= VIDEO_SYNC;
--       VGA_VSYNC <= '1';

--       VGA_HSYNC_int when VGA_MODE = '1' else (VGA_HSYNC_int xor (not VGA_VSYNC_int));
--       VGA_VSYNC <= VGA_VSYNC_int when VGA_MODE = '1' else '1';

--       RI <= VGA_R_int&VGA_R_int&VGA_R_int;
--       GI <= VGA_G_int&VGA_G_int&VGA_G_int;
--       BI <= VGA_B_int&VGA_B_int&VGA_B_int;

--       THIS WORKS
--       RI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       GI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       BI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;

--       VIDEO_DATA_R <= VIDEO_DATA and not(port_FFFF(2)) when port_FFFE = '0' else
--             VIDEO_DATA and not(COLORS(2));
--       VIDEO_DATA_G <= VIDEO_DATA and not(port_FFFF(1)) when port_FFFE = '0' else
--             VIDEO_DATA and not(COLORS(1));
--       VIDEO_DATA_B <= VIDEO_DATA and not(port_FFFF(0)) when port_FFFE = '0' else
--             VIDEO_DATA and not(COLORS(0));

      VIDEO_COLORING : process(VIDEO_DATA, port_FFFE, COLORS, port_FFFF) begin
        if (PIX_CLK'event and PIX_CLK = '1') then
          if (port_FFFE = '0') then
            VIDEO_DATA_R <= VIDEO_DATA and not(port_FFFF(2));
            VIDEO_DATA_G <= VIDEO_DATA and not(port_FFFF(1));
            VIDEO_DATA_B <= VIDEO_DATA and not(port_FFFF(0));
          else
            VIDEO_DATA_R <= VIDEO_DATA and not(COLORS(2));
            VIDEO_DATA_G <= VIDEO_DATA and not(COLORS(1));
            VIDEO_DATA_B <= VIDEO_DATA and not(COLORS(0));
          end if;
        end if;
      end process;
            
      RI <= VIDEO_DATA_R&VIDEO_DATA_R&VIDEO_DATA_R;
      GI <= VIDEO_DATA_G&VIDEO_DATA_G&VIDEO_DATA_G;
      BI <= VIDEO_DATA_B&VIDEO_DATA_B&VIDEO_DATA_B;

      VGA_SCANDOUBLER : entity work.vga_scandoubler
        port map(
          clkvideo => PIX_CLK_COUNTER(0),
          clkvga => CLK_12M288,
          enable_scandoubling => VGA_MODE,
          disable_scaneffect => '1',
          ri => RI,
          gi => GI,
          bi => BI,
          hsync_ext_n => HSYNC_Q_n,
          vsync_ext_n => VSYNC_Q_n,
          csync_ext_n => VIDEO_SYNC,
          ro => VGA_R,
          go => VGA_G,
          bo => VGA_B,
          hsync => VGA_HSYNC,
          vsync => VGA_VSYNC
        );
      

--       VGA_SCANDOUBLER : entity work.vga_scandoubler
--         port map(
--           clkvideo => PIX_CLK_COUNTER(0),
--           clkvga => CLK_12M288,
--           enable_scandoubling => VGA_MODE,
--           disable_scaneffect => '1',
--           ri => RI,
--           gi => GI,
--           bi => BI,
--           hsync_ext_n => VGA_HSYNC_int,
--           vsync_ext_n => VGA_VSYNC_int,
--           csync_ext_n => VGA_HSYNC_int xor (not VGA_VSYNC_int),
--           ro => VGA_R,
--           go => VGA_G,
--           bo => VGA_B,
--           hsync => VGA_HSYNC,
--           vsync => VGA_VSYNC
--         );

-- module vga_scandoubler (
-- 	input wire clkvideo,
-- 	input wire clkvga,
--   input wire enable_scandoubling,
--   input wire disable_scaneffect,  // 1 to disable scanlines
-- 	input wire [2:0] ri,
-- 	input wire [2:0] gi,
-- 	input wire [2:0] bi,
-- 	input wire hsync_ext_n,
-- 	input wire vsync_ext_n,
--   input wire csync_ext_n,
-- 	output reg [2:0] ro,
-- 	output reg [2:0] go,
-- 	output reg [2:0] bo,
-- 	output reg hsync,
-- 	output reg vsync
--   );

      
      
      
--       VGA_HSYNC <= VGA_HSYNC_int;
--       VGA_VSYNC <= VGA_VSYNC_int;
	
-- 	VGAOUT: composite_to_vga
-- 				port map(
-- 								CLK => PIX_CLK,
-- 								RESET_n => RESET_n_VGA,
-- 								VIDEO_DATA => VIDEO_DATA_int_VGA,
-- 								VIDEO_SYNC => SYNC_VGA,
-- 								START_FRAME_n => WAIT_n_VGA,
-- 								HPOS => HPOS_VGA,
-- 								
-- 								COL_VADDR => VGA_VADDR,
-- 								COL_HADDR => VGA_HADDR,
-- 								COL_CLK => VGA_CLK25M,
-- 																
-- 								CLK_50M => CLK_12M288B,
-- 								VGA_HSYNC => VGA_HSYNC_int,
-- 								VGA_VSYNC => VGA_VSYNC_int,
-- 								VGA_VIDEO => VGA_VIDEO,
-- 								VGA_MODE => '0'
-- 							);
	
-- 	VGA_R_int <= VGA_VIDEO and not(port_FFFF(2)) when port_FFFE = '0' else
-- 				VGA_VIDEO and not(COLORS(2));
-- 	VGA_G_int <= VGA_VIDEO and not(port_FFFF(1)) when port_FFFE = '0' else
-- 				VGA_VIDEO and not(COLORS(1));
-- 	VGA_B_int <= VGA_VIDEO and not(port_FFFF(0)) when port_FFFE = '0' else
-- 				VGA_VIDEO and not(COLORS(0));
	
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


-- module dpsram#(parameter RAM_SIZE = 32768, parameter ADDRESS_WIDTH = 15, parameter WORD_SIZE = 8)(
--     output wire [WORD_SIZE-1:0] q1,
--     output wire [WORD_SIZE-1:0] q2,
--     input wire [ADDRESS_WIDTH-1:0] a1,
--     input wire [ADDRESS_WIDTH-1:0] a2,
--     input wire [WORD_SIZE-1:0] d1,
--     input wire [WORD_SIZE-1:0] d2,
--     input wire clk,
--     input wire wren1,
--     input wire wren2);
    
  
--   CRAM_WEN <= not WR_n and A(15) and A(14) and A(13) and not A(12) and not MREQ_n;
-- 	CRAM: entity dpsram
--     generic map (
--       RAM_SIZE => 3072,
--       ADDRESS_WIDTH => 12,
--       WORD_SIZE => 3
--     )
--     port map(
--       a1 => A(11 downto 0),
--       q1 => cram_out,
--       d1 => D(2 downto 0),
--       wren1 => CRAM_WEN,
--       clk => PIX_CLK,
--       
--       a2 => SCAN_HADDR(7 downto 2) & SCAN_HADDR(7 downto 2),
--       wren2 => '0',
--       d2 => "000",
--       q2 => COLORS(2 downto 0)
--     )
--     ;
	
	CRAM: color_ram 
		 Port map ( CLK_WR => PIX_CLK,
						A => A, 
						D => D(2 downto 0),
						WR_n => WR_n,
						MREQ_n => MREQ_n,
						OE_n => RD_n,
						VADDR => SCAN_VADDR(7 downto 2),
						HADDR => SCAN_HADDR(7 downto 2),
						CLK_RD => PIX_CLK,
						COLORS => COLORS
				  );
	
	--
	-- End of VGA output
	--

  DAC_L: entity work.dac2
    port map(clk_i   => PIX_CLK,		--CLK_50M,
            res_n_i => RESET_n,
            dac_i   => DAC_IN,
            dac_o   => audio_out);
  AUDIO_RIGHT <= audio_out;
  AUDIO_LEFT <= audio_out;
	CAS_P <= '1' when (LATCH_DATA(4)='1' and LATCH_DATA(0)='1') else '0';
	CAS_N <= '1' when (LATCH_DATA(4)='0' and LATCH_DATA(0)='0') else '0';
	CAS_Z <= '1' when (CAS_P='0' and CAS_N='0') else '0';
	CAS_NZ <= '1' when (CAS_P='1' or CAS_N='1') else '0';
-- 	DAC_IN(7 downto 0) <= CAS_N&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ;
	DAC_IN(7 downto 0) <= (CAS_P or CAS_Z)&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ&CAS_NZ;

-- 	DAC_IN(7 downto 0) <= X"80" when (LATCH_DATA(4)='1' and LATCH_DATA(0)='1') else
--                         X"7F" when (LATCH_DATA(4)='0' and LATCH_DATA(0)='0') else
--                         X"00";
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
	
-- 	pblaze_soc: picoblaze_soc 
-- 		 Port map(
-- 			CLK_50M => CLK_50M_PBLAZE,
-- 			RESET_n => RESET_n,
-- 			KEY_STROBE => KEY_STROBE,
-- 			KEY_CODE => KEY_CODE,
-- 			ESC_STATE => ESC_STATE,
-- 			
-- 			CH_ADDR => PBLAZE_CHADDR,
-- 			CH_DATA => CHROM_D,
-- 
-- 			VIDEO_ADDR => PBLAZE_VADDR,
-- 			VIDEO_DATA => PBLAZE_VDATA,
-- 			VIDEO_WR	  => PBLAZE_VWR,
-- 			
-- 			PRAM_CLK2 => PRAM_CLK2,
-- 			PRAM_WR2 => PRAM_WR2,
-- 			PRAM_DIN2 => PRAM_DOUT2,
-- 			PRAM_DOUT2 => PRAM_DIN2,
-- 			PRAM_ADDR2 => PRAM_ADDR2,
-- 			
-- 			CLK_SEL => CLK_SEL,
-- 			
-- 			LINE_IN => PBLAZE_LIN,
-- 			LINE_OUT => PBLAZE_LOUT
-- 		 );
		
	--
	--
	--
	
end rtl;
