-------------------------------------------------------------------------------
--
-- Title       : ramb_dp_one_clk
-- Design      : fpfftk
-- Author      : Kapitanov
-- Company     :
--
-------------------------------------------------------------------------------
--
-- Description : version 1.0
--
-------------------------------------------------------------------------------
--
--	Version 1.0  12.02.2016
--			   	 Description: A parameterized, dual-port, single-clock RAM.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	The MIT License (MIT)
--	Copyright (c) 2016 Kapitanov Alexander 													 
--		                                          				 
-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), 
-- to deal in the Software without restriction, including without limitation 
-- the rights to use, copy, modify, merge, publish, distribute, sublicense, 
-- and/or sell copies of the Software, and to permit persons to whom the 
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in 
-- all copies or substantial portions of the Software.
--
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
-- IN THE SOFTWARE.
-- 	                                                 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
 
entity ramb_dp_one_clk is
	generic (
	    DATA    : integer := 16;
	    ADDR    : integer := 10;
		TD		: time:=0.5ns
		);
	port (
	    -- rst     : in  std_logic;
		CLK     : in  std_logic;	    
		-- Port A
	    A_WR    : in  std_logic;		
		A_ADDR  : in  std_logic_vector(ADDR-1 downto 0);
	    A_DIN   : in  std_logic_vector(DATA-1 downto 0);  
	    -- Port B
		B_RD    : in  std_logic;		
	    B_ADDR  : in  std_logic_vector(ADDR-1 downto 0);
	    B_DOUT  : out std_logic_vector(DATA-1 downto 0)
	);
end ramb_dp_one_clk;
 
architecture ramb_rtl of ramb_dp_one_clk is
-- Shared mem signal
type mem_type is array ((2**ADDR)-1 downto 0) of std_logic_vector(DATA-1 downto 0);
shared variable mem : mem_type:=(others => (others => '0'));
	
attribute ram_style : string;
attribute ram_style of mem : variable is "block";	

begin
 
-- Port A write --
pr_wa: process(clk)
begin
    if (clk'event and clk='1') then
		if (b_rd = '1') then		
			b_dout <= mem(conv_integer(b_addr)) after td;
		end if;			
		if (a_wr = '1') then
			mem(conv_integer(a_addr)) := a_din;
		end if;
    end if;
end process;

end ramb_rtl;