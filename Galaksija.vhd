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
        SRAM_WE_N : out std_logic;

        SD_CS_N : buffer std_logic;
        SD_CLK : out std_logic;
        SD_MOSI : out std_logic;
        SD_MISO : in std_logic;
        
        LED : out std_logic
			);
end Galaksija;

architecture rtl of Galaksija is
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
	signal mrst_n : std_logic;
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
  
  -- ctrl-module signals
  signal osd_window : std_logic;
	signal osd_pixel : std_logic;
	signal host_divert_keyboard : std_logic;
	signal host_divert_sdcard : std_logic;
	signal dswitch : std_logic_vector(15 downto 0);
	signal RO : std_logic_vector(7 downto 0);
	signal GO : std_logic_vector(7 downto 0);
	signal BO : std_logic_vector(7 downto 0);
	signal PS2_DATA_S : std_logic;
	signal PS2_CLK_S : std_logic;

	-- hyperload functionality from ctrl-module
	signal hyperloading : std_logic;
	signal hyperload_fifo_data : std_logic_vector(7 downto 0);
	signal tape_data : std_logic_vector(7 downto 0);
	signal hyperload_fifo_rd : std_logic;
	signal hyperload_fifo_empty : std_logic;
	signal hyperload_fifo_full : std_logic;
	signal tape_dclk : std_logic;
	signal tape_reset : std_logic;
	signal tape_hreq : std_logic;
	signal tape_busy : std_logic;
	signal apply_rom_patch : std_logic;
	
	-- hypersave functionality from ctrl-module
  signal tape_data_in : std_logic_vector(7 downto 0);
  signal tape_data_in_rdy : std_logic := '0';
  
  signal memcfg : std_logic_vector(1 downto 0) := "10";
  signal memcfgx : std_logic_vector(1 downto 0) := "10";

  signal alt_char_rom : std_logic := '0';
  signal apply_charrom_patch : std_logic;
  signal CHROM_D_PATCHED : std_logic_vector(7 downto 0);
	
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
			D			: inout std_logic_vector(7 downto 0);
			SavePC      : out std_logic_vector(15 downto 0);
      SaveINT     : out std_logic_vector(7 downto 0);
      RestorePC   : in std_logic_vector(15 downto 0);
      RestoreINT  : in std_logic_vector(7 downto 0);
      
      RestorePC_n : in std_logic
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
          VIDEO_toggle : out std_logic;
          MRST_n : out std_logic
				  );
	end component galaksija_keyboard_v2;

	component tristate_bit is
		 Port ( DIN : in  STD_LOGIC;
				  DOUT : out  STD_LOGIC;
				  EN_n : in  STD_LOGIC);
	end component tristate_bit;

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
	signal CLK_48M333 : std_logic;
  signal VIDEO_toggle : std_logic;
  signal VGA_MODE : std_logic := '1';

	signal SCAN_VADDR, SCAN_HADDR : std_logic_vector(10 downto 0);
	signal MULTIBOOT_COUNTER : std_logic_vector(2 downto 0) := "000";
  
  
begin
	--
	-- Expansion port
	--

	STDN <= '0';
	STDNB <= '1';
		
	--
	-- clock generation
	--
	clocks: entity work.clock
    port map(
      CLK_IN1 => extCLK_50M,
      CLK_OUT1 => CLK_12M288,
      CLK_OUT2 => CLK_12M288B,
      CLK_OUT3 => CLK_48M333,
      RESET => '0',
      LOCKED => open
    );

	--
	-- CPU instantation
	--

-- 			SavePC      : out std_logic_vector(15 downto 0);
-- 		SaveINT     : out std_logic_vector(7 downto 0);
-- 		RestorePC   : in std_logic_vector(15 downto 0);
-- 		RestoreINT  : in std_logic_vector(7 downto 0);
-- 		
-- 		RestorePC_n : in std_logic

-- 	cpu_inst: if (picoblaze_only=false) generate
-- 				 begin
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
-- 									WAIT_n => '1',
									INT_n => INT_n,
									NMI_n => NMI_n,
									WR_n => WR_n,
									RD_n => RD_n,
									RestorePC_n => '1',
									RestorePC => X"0000",
									RestoreINT => X"00"
								);
-- 				end generate cpu_inst;

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
	CLK_50M <= CLK_12M288;

	-- CLK_SEL is set by Picoblaze via CPU_FREQ menu
	process (PIX_CLK_COUNTER, CLK_SEL, CLK_12M288)
	begin
    case CLK_SEL is
      when "00" => iPIX_CLK <= PIX_CLK_COUNTER(0);
      when "01" => iPIX_CLK <= CLK_12M288;
      when "10" => iPIX_CLK <= PIX_CLK_COUNTER(0);
      when "11" => iPIX_CLK <= CLK_12M288;
      when others => null;
    end case;
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

	--
	-- Address decoder
	--
		
	DECODER_EN <= (not(MREQ_n) and not(A(14))) and not(A(15));
	
	-- Keyboard and latch address decoding
--  LATCH_KBD_CS_n <= '0' when ((A(11)='0') and (A(12)='0') and (A(13)='1') and (DECODER_EN = '1')) and (RFSH_n = '1')else '1';
    LATCH_KBD_CS_n <= '0' when ((A(11)='0') and (A(12)='0') and (A(13)='1') and (DECODER_EN = '1')) else '1';

    
	ROM_OE_n <= '0' when ((A(13)='0') and (DECODER_EN='1') and (RFSH = '0')) and apply_rom_patch = '0' else
					'1';
					
	ROM_A <= A(12 downto 0);

	-- TODO: try this one
	RAM_CS1_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='0') and (A(13)='1')) else '1';  -- 00 101 00000000000 = h2800

-- 	RAM_CS1_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='0') and (A(13)='1')) or (RFSH = '1') else '1';
	RAM_CS2_n <= '0' when ((DECODER_EN='1') and (A(11)='0') and (A(12)='1') and (A(13)='1')) else '1';
	RAM_CS3_n <= '0' when ((DECODER_EN='1') and (A(11)='1') and (A(12)='1') and (A(13)='1')) else '1';
	
	-- gives us 32k expansion
-- 	SRAM_CS1_n <= '0' when MREQ_n = '0' and (A(15)='1' xor A(14)='1') else '1';
-- 	SRAM_CS1_n <= '1';

	-- 48k expansion
-- 	SRAM_CS2_n <= '0' when MREQ_n = '0' and (A(15)='1' and A(14)='1') else '1';
-- 	SRAM_CS2_n <= '1';
	
-- 	dswitch
	-- uncomment for 6k
-- 	SRAM_CS_n <= '1';

  -- +32k + 6k
-- 	SRAM_CS_n <= '0' when MREQ_n = '0' and (A(15 downto 14)="01" or A(15 downto 14)="10") else '1';

	-- +MAX - 16bytes
	SRAM_CS1_n <= '0' when MREQ_n = '0' and (A(15 downto 14)="01" or A(15 downto 14)="10") else '1';
  SRAM_CS2_n <= '0' when MREQ_n = '0' and A(15 downto 14)/="00" and A(15 downto 4) /= X"FFF" else '1';
  
--   SRAM_CS_n <= SRAM_CS1_n when memcfg(1 downto 0) = "01" else
--                 SRAM_CS2_n when memcfg(1 downto 0) = "10" else
--                 '1';

  process (PIX_CLK, RESET_n) begin
    if (PIX_CLK'event and PIX_CLK = '1' and RESET_n = '0') then
      memcfgx(1 downto 0) <= memcfg(1 downto 0);
    end if;
  end process;

  process (SRAM_CS_n) begin
    if (memcfgx(0) = '1') then SRAM_CS_n <= SRAM_CS1_n;
    elsif (memcfgx(1) = '1') then SRAM_CS_n <= SRAM_CS2_n;
    else SRAM_CS_n <= '1';
    end if;
  end process;
--   SRAM_CS_n <= (SRAM_CS1_n when memcfg(0) = '1' else '1') and 
--                 (SRAM_CS2_n when memcfg(1) = '1' else '1');

-- 	SRAM_CS_n <= '0' when MREQ_n = '0' and (A(15)='1' or A(14)='1') and (A(15 downto 14) /= "11") else '1';
-- 	SRAM_CS_n <= '0' when MREQ_n = '0' and (A(15)='1' or A(14)='1') and (A(15 downto 13) /= "111") else '1';
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

-- 	mem_inst: if (picoblaze_only=false) generate
-- 				 begin
-- 
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
								

-- 								module rom_patch(output reg[7:0] q, input wire[15:0] a, input wire clk, output wire patch, input wire on);

          ROM_PATCH: entity work.rom_patch
          port map(
            a => A,
            q => D,
            clk => PIX_CLK,
            patch => apply_rom_patch,
            override => hyperloading
          );
-- 				end generate mem_inst;

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
	PS2_DATA_S <= PS2_DATA or host_divert_keyboard;
	PS2_CLK_S <= PS2_CLK or host_divert_keyboard;
	
	PS2_KBD: galaksija_keyboard_v2
   Port map ( 
-- 			  CLK => CLK_50M,
        CLK => KEYB_CLK,
			  NMI_n => NMI_n,
           PS2_DATA => PS2_DATA_S,
           PS2_CLK => PS2_CLK_S,
           LINE_IN => LINE_IN,
           KR => KR,
           KS => KS,
			  RST_n => RESET2_n,
			  ESC => ESC_STATE,
			  KEY_CODE => KEY_CODE,
			  KEY_STROBE => KEY_STROBE,
			  RESET_n => RESET1_n,
			  VIDEO_toggle => VIDEO_toggle,
			  MRST_n => mrst_n
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
-- 			if (KR(7) = '0' and WR_n = '0' and MREQ_n = '0') then
			if (KR(7) = '0') then
-- 			if (MREQ_n = '0' and RFSH_n = '0') then
				LATCH_DATA <= LATCH_IN;
			end if;
		end if;
	end process;
	
	LATCH_D5 <= LATCH_DATA(5);
-- 	LATCH_D4 <= LATCH_DATA(4);
-- 	LATCH_D0 <= LATCH_DATA(0);
	
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
	CHROM_A <= LATCH_DATA(3 downto 0) & TMP(7) & TMP(5 downto 0);
-- 	CHROM_CLK <= PIX_CLK when ESC_STATE = '0' else CLK_50M;
	CHROM_CLK <= PIX_CLK;

	CH_GEN_ROM: galaksija_chgen_rom
	port map (
					A => CHROM_A,
					DO => CHROM_D,
					OE_n => '0',
					CE_n => '0',
					CLK => CHROM_CLK
				);
				  
  CH_GEN_ROM_PATCH: entity work.char_rom_patch
    port map(
      a => CHROM_A,
      q => CHROM_D_PATCHED,
      clk => PIX_CLK,
      patch => apply_charrom_patch,
      override => alt_char_rom
    );
  
	
	-- Video shift register
  process(PIX_CLK, LOAD_SCAN_LINE_n, SHREG)
	begin
		if (PIX_CLK'event) and (PIX_CLK = '1') then
      LOAD_SCAN_LINE_n_prev <= LOAD_SCAN_LINE_n;
			if (LOAD_SCAN_LINE_n_prev = '1' and LOAD_SCAN_LINE_n = '0') then
        if (apply_charrom_patch = '1') then
          SHREG <= CHROM_D_PATCHED;
        else 
          SHREG <= CHROM_D;
        end if;
			else
				SHREG <= SHREG(6 downto 0) & '1';
			end if;
		end if;
	end process;
	

	--MJ

-- 	process(PIX_CLK,VSYNC_Q_n,LOAD_SCAN_LINE_n_prev,LOAD_SCAN_LINE_n,LOAD_SCAN_LINE_n_prev)
-- 	begin
-- 		if (PIX_CLK'event) and (PIX_CLK = '1') then
--       if (VSYNC_Q_n = '0') then
--         SCAN_HADDR(10 downto 0) <= "00000000000";
--         SCAN_VADDR(10 downto 0) <= "00000000000";
--       elsif (SCAN_HADDR(10 downto 0) = "00000000000") then
--         if (LOAD_SCAN_LINE_n_prev = '1' and LOAD_SCAN_LINE_n = '0') then
--           SCAN_HADDR <= SCAN_HADDR + 1;
--         end if;
--       elsif (HSYNC_Q_n = '0') then
--         SCAN_HADDR(10 downto 0) <= "00000000000";
--         SCAN_VADDR <= SCAN_VADDR + 1;
--       else
--         SCAN_HADDR <= SCAN_HADDR + 1;
--       end if;
-- 		end if;
-- 	end process;
	
	

		
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

      VGA_RGB_SWITCH : process(VGA_MODE, VIDEO_toggle) begin
        if (VIDEO_toggle'event) and (VIDEO_toggle = '1') then
          VGA_MODE <= not VGA_MODE;
        end if;
      end process;
       
      VIDEO_COLORING : process(VIDEO_DATA, port_FFFE, COLORS, port_FFFF) begin
        if (PIX_CLK'event and PIX_CLK = '1') then
--           if (port_FFFE = '0') then
--             VIDEO_DATA_R <= VIDEO_DATA and not(port_FFFF(2));
--             VIDEO_DATA_G <= VIDEO_DATA and not(port_FFFF(1));
--             VIDEO_DATA_B <= VIDEO_DATA and not(port_FFFF(0));
--           else
--             VIDEO_DATA_R <= VIDEO_DATA and not(COLORS(2));
--             VIDEO_DATA_G <= VIDEO_DATA and not(COLORS(1));
--             VIDEO_DATA_B <= VIDEO_DATA and not(COLORS(0));
--           end if;
            VIDEO_DATA_R <= VIDEO_DATA;
            VIDEO_DATA_G <= VIDEO_DATA;
            VIDEO_DATA_B <= VIDEO_DATA;
        end if;
      end process;
            
      RI <= VIDEO_DATA_R&VIDEO_DATA_R&VIDEO_DATA_R;
      GI <= VIDEO_DATA_G&VIDEO_DATA_G&VIDEO_DATA_G;
      BI <= VIDEO_DATA_B&VIDEO_DATA_B&VIDEO_DATA_B;

--       RI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       GI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;
--       BI <= VIDEO_DATA&VIDEO_DATA&VIDEO_DATA;

      VGA_SCANDOUBLER : entity work.vga_scandoubler
        port map(
          clkvideo => PIX_CLK_COUNTER(0),
          clkvga => CLK_12M288,
          enable_scandoubling => VGA_MODE,
          disable_scaneffect => '1',
          ri => RO(7 downto 5),
          gi => GO(7 downto 5),
          bi => BO(7 downto 5),
          hsync_ext_n => HSYNC_Q_n,
          vsync_ext_n => VSYNC_Q_n,
          csync_ext_n => VIDEO_SYNC,
          ro => VGA_R,
          go => VGA_G,
          bo => VGA_B,
          hsync => VGA_HSYNC,
          vsync => VGA_VSYNC
        );
      
	-- Color is specified by writing to the port FFFF
-- 	process(RESET_n, PIX_CLK, D, A, WR_n)
-- 	begin
-- 		if (RESET_n = '0') then
-- 			port_FFFF <= "000";
-- 		else
-- 			if (PIX_CLK'event) and (PIX_CLK = '1') then
-- 				if (WR_n = '0') and (MREQ_n = '0') and (A = X"FFFF") then
-- 						port_FFFF <= D(2 downto 0);
-- 				end if;
-- 			end if;
-- 		end if;
-- 	end process;

	-- Color RAM activation register - overrides register FFFF settings
-- 	process(RESET_n, PIX_CLK, D, A, WR_n)
-- 	begin
-- 		if (RESET_n = '0') then
-- 			port_FFFE <= '0';
-- 		else
-- 			if (PIX_CLK'event) and (PIX_CLK = '1') then
-- 				if (WR_n = '0') and (MREQ_n = '0') and (A = X"FFFE") then
-- 						port_FFFE <= D(0);
-- 				end if;
-- 			end if;
-- 		end if;
-- 	end process;


-- 	CRAM: color_ram 
-- 		 Port map ( CLK_WR => PIX_CLK,
-- 						A => A, 
-- 						D => D(2 downto 0),
-- 						WR_n => WR_n,
-- 						MREQ_n => MREQ_n,
-- 						OE_n => RD_n,
-- 						VADDR => SCAN_VADDR(7 downto 2),
-- 						HADDR => SCAN_HADDR(7 downto 2),
-- 						CLK_RD => PIX_CLK,
-- 						COLORS => COLORS
-- 				  );
-- 	
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

	hyperloadfifo: entity work.fifo
    generic map(
      RAM_SIZE => 512,
      ADDRESS_WIDTH => 9
    )
    port map(
      q => hyperload_fifo_data,
      d => tape_data,
      clk => PIX_CLK,
      
      write => tape_dclk,
      reset => tape_reset,
      read => hyperload_fifo_rd,
      empty => hyperload_fifo_empty,
      full => hyperload_fifo_full
    );
    
-- 	signal hyperload_fifo_data : std_logic_vector(7 downto 0);
-- 	signal tape_data : std_logic_vector(7 downto 0);
-- 	signal hyperload_fifo_rd : std_logic;
-- 	signal hyperload_fifo_empty : std_logic;
-- 	signal hyperload_fifo_full : std_logic;

  -- glue logic tying hyperload to CPU
  D(7 downto 0) <= hyperload_fifo_data(7 downto 0) 
    when A(15 downto 0) = X"FFFD" and MREQ_n = '0' and RD_n = '0' else (others => 'Z');
	D(7 downto 0) <= "00000"&tape_busy&hyperload_fifo_empty&hyperload_fifo_full
    when A(15 downto 0) = X"FFFC" and MREQ_n = '0' and RD_n = '0' else (others => 'Z');
  hyperloading <= dswitch(12);
  alt_char_rom <= dswitch(13);

  hyperload_if: process(PIX_CLK,A,MREQ_n,WR_n) begin
    if (PIX_CLK'event and PIX_CLK = '1') then
      if (A(15 downto 0) = X"FFFC" and MREQ_n = '0' and WR_n = '0') then
        hyperload_fifo_rd <= D(0);
        tape_hreq <= D(1);
        tape_data_in_rdy <= D(2);
      elsif (A(15 downto 0) = X"FFFD" and MREQ_n = '0' and WR_n = '0') then
        tape_data_in(7 downto 0) <= D(7 downto 0);
      end if;
    end if;
  end process;

  
  ACTIVITY_LED: process(CLK_12M288B) begin
    if (CLK_12M288B'event and CLK_12M288B = '1') then
      LED <= not SD_CS_N;
    end if;
  end process;

  ctrlmodule: entity work.CtrlModule
    generic map(
      sysclk_frequency => 123,
--       ROMSIZE_BITS => 13,
      USE_UART => 0,
      USE_TAPE => 0,
      USE_HYPERLOAD => 1
    )
    port map(
      clk => PIX_CLK,
--       clk26 => CLK_50B,
      clk26 => CLK_12M288B,
      clk50 => CLK_48M333,
      reset_n => '1',
      -- Video signals for OSD
      vga_hsync => HSYNC_Q_n,
      vga_vsync => VSYNC_Q_n,
      osd_window => osd_window,
      osd_pixel => osd_pixel,
      -- PS2 keyboard
      ps2k_clk_in => PS2_CLK,
      ps2k_dat_in => PS2_DATA,
      -- SD card signals
      spi_clk => sd_clk,
      spi_mosi => sd_mosi,
      spi_miso => sd_miso,
      spi_cs => sd_cs_n,
      -- DIP switches
      dipswitches => dswitch,
      -- Control signals
      host_divert_keyboard => host_divert_keyboard,
      host_divert_sdcard => host_divert_sdcard,
      disk_data_in => (others => '0'),
      disk_sr => (others => '0'),
      -- tape interface
      ear_in => '0',
--       ear_in => micout,
--       ear_out => ear_in_sc,
      clk390k625 => '0',
      tape_data_out => tape_data,
      tape_dclk_out => tape_dclk,
      tape_reset_out => tape_reset,
      tape_hreq => tape_hreq,
      tape_busy => tape_busy,
      tape_data_in => tape_data_in,
      tape_data_in_rdy => tape_data_in_rdy,
      cpu_reset => '0',
      juart_rx => '0',
      debug => (others => '0'),
      debug2 => (others => '0'),
      memcfg => memcfg
      -- rom loading
--       host_bootdata => host_bootdata,
--       host_bootdata_ack => host_bootdata_ack,
--       host_bootdata_req => host_bootdata_req,
--       host_rom_initialised => host_rom_initialised
     );

--    assign vga_red_i = {ri2[2:0], 5'h0};
--    assign vga_green_i = {gi2[2:0], 5'h0};
--    assign vga_blue_i = {bi2[2:0], 5'h0};
   
  -- OSD Overlay
  osdoverlay: entity work.OSD_Overlay
    port map(
--      clk => CLK_50B,
     clk => CLK_12M288B,
     red_in => (others => VIDEO_DATA_R),
     green_in => (others => VIDEO_DATA_G),
     blue_in => (others => VIDEO_DATA_B),
     window_in => '1',
     osd_window_in => osd_window,
     osd_pixel_in => osd_pixel,
     hsync_in => HSYNC_Q_n,
     red_out => RO,
     green_out => GO,
     blue_out => BO,
     window_out => open,
     scanline_ena => '0'
   );
   
   clock_divider : process (CLK_12M288B) begin
    if (CLK_12M288B'event and CLK_12M288B = '1') then
      MULTIBOOT_COUNTER <= MULTIBOOT_COUNTER + 1;
    end if;
   end process;

   reset_to_bios: entity work.multiboot
    port map(
      clk_icap => MULTIBOOT_COUNTER(2),
      mrst_n => mrst_n
    );
     
end rtl;
