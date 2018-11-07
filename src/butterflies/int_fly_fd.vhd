-------------------------------------------------------------------------------
--
-- Title       : int_fly_fd
-- Design      : FFT
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Single-Path Delay-Feedback butterfly Radix-2 (FD only)
--
-------------------------------------------------------------------------------
--
--	Version 1.0  10.12.2017
--    Description: Simple butterfly Radix-2 for FFT (DIF) based on FD
--
--    Algorithm: Decimation in frequency
--
--    X = (A+B), 
--    Y = (A-B)*W;					
--
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--	Copyright (c) 2018 Kapitanov Alexander
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
--  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
--  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
--  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
--  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
--  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
-- 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity int_fly_fd is
	generic (
		TD			: time:=0.5ns; --! Simulation time
		DTW			: integer:=16; --! Data width
		XUSE		: boolean:=FALSE; --! Use Add/Sub scheme or use delay data path
		XSER 		: string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
	);
	port (
		DI_RE 		: in  std_logic_vector(DTW-1 downto 0); --! Re even input data
		DI_IM 		: in  std_logic_vector(DTW-1 downto 0); --! Im even input data
		DI_EN 		: in  std_logic; --! Data clock enable

		DO_RE 		: out std_logic_vector(DTW-1 downto 0); --! Re even output data
		DO_IM 		: out std_logic_vector(DTW-1 downto 0); --! Im even output data
		DO_VL		: out std_logic;	--! Output data valid			
		
		RST  		: in  std_logic;	--! Global Reset
		CLK 		: in  std_logic		--! DSP Clock	
	);
end int_fly_fd;

architecture int_fly_fd of int_fly_fd is

---- Find delay for add/sub butterfly function ----
function addsub_delay(iDW: integer) return integer is
	variable ret_val : integer:=0;
begin
	if (iDW < 48) then
		ret_val := 2+2;
	else 
		ret_val := 3+2;
	end if;
	return ret_val; 
end function addsub_delay;

constant ADD_DELAY	: integer:=addsub_delay(DTW);

type std_delayN is array (ADD_DELAY-1 downto 0) of std_logic_vector(DTW-1 downto 0);

---------------- Multiplexers 0/1 ----------------
signal mux_sel			: std_logic:='0';

signal mux0_ia_re		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux0_ia_im		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux0_ib_re		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux0_ib_im		: std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal mux1_ia_re		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux1_ia_im		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux1_ib_re		: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux1_ib_im		: std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal mux0_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux0_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux1_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux1_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal ib_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ib_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal iz_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal iz_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal oa_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal oa_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ob_re			: std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ob_im			: std_logic_vector(DTW-1 downto 0):=(others=>'0');

---------------- Align delays ----------------
signal dz0_re			: std_delayN;
signal dz0_im			: std_delayN;
signal dz1_re			: std_delayN;
signal dz1_im			: std_delayN;

signal di_ez			: std_logic;

signal mux_ena			: std_logic_vector(ADD_DELAY-1 downto 0):=(others=>'0');

signal cnt_en			: std_logic;
signal cnt_vl			: std_logic;

begin

pr_cnt: process(clk) is
begin
	if rising_edge(clk) then
		if (RST = '1') then
			cnt_en <= '0' after td;
		else
			if (di_en = '1') then
				cnt_en <= not cnt_en after td;
			end if;
		end if;
	end if;
end process;

pr_mux: process(clk) is
begin
	if rising_edge(clk) then
		---- Mux data A / B datapath ----
		mux_sel <= mux_ena(mux_ena'left-1) after td;
		mux_ena <= mux_ena(mux_ena'left-1 downto 0) & cnt_en after td;
		---- Align input data and ramb output ----
		dz0_re <= dz0_re(dz0_re'left-1 downto 0) & di_re after td;
		dz0_im <= dz0_im(dz0_im'left-1 downto 0) & di_im after td;
	end if;
end process;

---- Select data for input multiplexer "0" ----
mux0_ia_re <= dz0_re(dz0_re'left);
mux0_ia_im <= dz0_im(dz0_im'left);

mux0_ib_re <= ob_re;
mux0_ib_im <= ob_im;

pr_mux0: process(clk) is
begin
	if rising_edge(clk) then
		if (mux_sel = '0') then
			mux0_re <= mux0_ia_re after td;
			mux0_im <= mux0_ia_im after td;
		else
			mux0_re <= mux0_ib_re after td;
			mux0_im <= mux0_ib_im after td;
		end if;
	end if;
end process;


---- Align input data and ramb output ----
dz1_re <= dz1_re(dz1_re'left-1 downto 0) & ia_re after td when rising_edge(clk);
dz1_im <= dz1_im(dz1_im'left-1 downto 0) & ia_im after td when rising_edge(clk);

---- Select data for input multiplexer "1" ----
mux1_ia_re <= oa_re;
mux1_ia_im <= oa_im;

mux1_ib_re <= dz1_re(dz1_re'left-2);
mux1_ib_im <= dz1_im(dz1_im'left-2);

pr_mux1: process(clk) is
begin
	if rising_edge(clk) then
		if (mux_sel = '1') then
			mux1_re <= mux1_ia_re after td;
			mux1_im <= mux1_ia_im after td;
		else
			mux1_re <= mux1_ib_re after td;
			mux1_im <= mux1_ib_im after td;
		end if;
	end if;
end process;

---- Input data for Butterfly ----
ib_re <= di_re after td when rising_edge(clk) and (di_en = '1'); 
ib_im <= di_im after td when rising_edge(clk) and (di_en = '1');
ia_re <= mux0_re;
ia_im <= mux0_im;

---- Delay imitation Add/Sub logic ----
xLOGIC: if (XUSE = FALSE) generate
	type std_delayX is array (ADD_DELAY-1-2 downto 0) of std_logic_vector(DTW-1 downto 0);
	signal add_re	: std_delayX;
	signal add_im	: std_delayX;
	signal sub_re	: std_delayX;
	signal sub_im	: std_delayX;
	
begin
	add_re <= add_re(add_re'left-1 downto 0) & ia_re after td when rising_edge(clk);
    add_im <= add_im(add_im'left-1 downto 0) & ia_im after td when rising_edge(clk);
    sub_re <= sub_re(sub_re'left-1 downto 0) & ib_re after td when rising_edge(clk);
    sub_im <= sub_im(sub_im'left-1 downto 0) & ib_im after td when rising_edge(clk);

	oa_re <= add_re(add_re'left) + x"1000";
	oa_im <= add_im(add_im'left) + x"1000";
	ob_re <= sub_re(sub_re'left) + x"2000";
	ob_im <= sub_im(sub_im'left) + x"2000";
	
end generate;


---- Output data ----
pr_dout: process(clk) is
begin
	if rising_edge(clk) then
		do_re <= mux1_re after td;
		do_im <= mux1_im after td;
	end if;
end process;

------ SUM = (A + B), DIF = (A-B) --------
xADDSUB: if (XUSE = TRUE) generate
	xDSP: entity work.int_addsub_dsp48
		generic map (
			DSPW	=> DTW,
			XSER 	=> XSER
		)
		port map (
			IA_RE 	=> ia_re,
			IA_IM 	=> ia_im,
			IB_RE 	=> ib_re,
			IB_IM 	=> ib_im,

			OX_RE 	=> oa_re,
			OX_IM 	=> oa_im,
			OY_RE 	=> ob_re,
			OY_IM 	=> ob_im,

			RST  	=> rst,
			CLK 	=> clk
		);
end generate;


end int_fly_fd;