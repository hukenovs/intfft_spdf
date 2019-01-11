-------------------------------------------------------------------------------
--
-- Title       : int_fly_fd2
-- Design      : FFT
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : SPDF Radix-2 FFT Butterfly (Double FD mode)
--
-------------------------------------------------------------------------------
--
--    Version 1.0  12.10.2018
--    Description: SPDF Radix-2 FFT Butterfly (Double FD mode)
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
--  GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--  Copyright (c) 2018 Kapitanov Alexander
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

entity int_fly_fd2 is
    generic (
        TD        : time:=0.5ns; --! Simulation time
        DTW       : integer:=16; --! Data width
        XUSE      : boolean:=FALSE; --! Use Add/Sub scheme or use delay data path
        XSER      : string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE     : in  std_logic_vector(DTW-1 downto 0); --! Re even input data
        DI_IM     : in  std_logic_vector(DTW-1 downto 0); --! Im even input data
        DI_EN     : in  std_logic; --! Data clock enable

        DO_RE     : out std_logic_vector(DTW-1 downto 0); --! Re even output data
        DO_IM     : out std_logic_vector(DTW-1 downto 0); --! Im even output data
        DO_VL     : out std_logic; --! Output data valid            
        
        RST       : in  std_logic; --! Global Reset
        CLK       : in  std_logic --! DSP Clock    
    );
end int_fly_fd2;

architecture int_fly_fd2 of int_fly_fd2 is

---- Find delay for add/sub butterfly function ----
function addsub_delay(iDW: integer) return integer is
    variable ret_val : integer:=0;
begin
    if (iDW < 48) then
        ret_val := 2;
    else 
        ret_val := 3;
    end if;
    return ret_val; 
end function addsub_delay;

constant ADD_DELAY    : integer:=addsub_delay(DTW);

---------------- Multiplexers 0/1 ----------------
signal mux_re       : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mux_im       : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal ib_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ib_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ia_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal iz_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal iz_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal oa_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal oa_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ob_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ob_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');

signal oz_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal oz_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ot_re        : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal ot_im        : std_logic_vector(DTW-1 downto 0):=(others=>'0');

---------------- Align delays ----------------
signal di_zn        : std_logic_vector(ADD_DELAY downto 0):=(others=>'0');
signal di_ez        : std_logic;

signal mux_ena      : std_logic_vector(ADD_DELAY downto 0):=(others=>'0');
signal mux_sel      : std_logic;

signal cnt_en       : std_logic;
signal cnt_vl       : std_logic;

begin

pr_cnt: process(clk) is
begin
    if rising_edge(clk) then
        if (RST = '1') then
            cnt_en <= '0';
            cnt_vl <= '0';
        else
            if (di_en = '1') then
                if (cnt_en = '1') then
                    cnt_vl <= not cnt_vl;
                end if;
                cnt_en <= not cnt_en;
            end if;
        end if;
    end if;
end process;

pr_mux: process(clk) is
begin
    if rising_edge(clk) then
        di_ez <= di_zn(di_zn'left);
        di_zn <= di_zn(di_zn'left-1 downto 0) & di_en;
        mux_sel <= mux_ena(mux_ena'left);
        mux_ena <= mux_ena(mux_ena'left-1 downto 0) & cnt_vl;
    end if;
end process;

-------- Select data for input multiplexer "1" --------
pr_mux1: process(clk) is
begin
    if rising_edge(clk) then
        if (di_ez = '1') then
            if (mux_sel = '0') then
                mux_re <= oa_re;
                mux_im <= oa_im;
            else
                mux_re <= oz_re;
                mux_im <= oz_im;
            end if;
        end if;
    end if;
end process;

-------- IA / IB & OA / OB ports for Add/Sub logic --------
iz_re <= di_re when rising_edge(clk) and di_en = '1';
iz_im <= di_im when rising_edge(clk) and di_en = '1';
ia_re <= iz_re when rising_edge(clk);
ia_im <= iz_im when rising_edge(clk);
ib_re <= di_re;
ib_im <= di_im;

ot_re <= ob_re when rising_edge(clk);
ot_im <= ob_im when rising_edge(clk);
oz_re <= ot_re when rising_edge(clk);
oz_im <= ot_im when rising_edge(clk);

-------- Delay imitation Add/Sub logic --------
xLOGIC: if (XUSE = FALSE) generate
    type std_delayX is array (ADD_DELAY-1 downto 0) of std_logic_vector(DTW-1 downto 0);
    signal add_re    : std_delayX;
    signal add_im    : std_delayX;
    signal sub_re    : std_delayX;
    signal sub_im    : std_delayX;

begin
    add_re <= add_re(add_re'left-1 downto 0) & ia_re when rising_edge(clk);
    add_im <= add_im(add_im'left-1 downto 0) & ia_im when rising_edge(clk);
    sub_re <= sub_re(sub_re'left-1 downto 0) & ib_re when rising_edge(clk);
    sub_im <= sub_im(sub_im'left-1 downto 0) & ib_im when rising_edge(clk);

    oa_re <= add_re(add_re'left);
    oa_im <= add_im(add_im'left);
    ob_re <= sub_re(sub_re'left);
    ob_im <= sub_im(sub_im'left);
    
end generate;

-------- Output data --------
do_re <= mux_re;
do_im <= mux_im;
do_vl <= di_ez when rising_edge(clk);

-------- SUM = (A + B), DIF = (A-B) --------
xADDSUB: if (XUSE = TRUE) generate
    xDSP: entity work.int_addsub_dsp48
        generic map (
            DSPW      => DTW,
            XSER      => XSER
        )
        port map (
            IA_RE     => ia_re,
            IA_IM     => ia_im,
            IB_RE     => ib_re,
            IB_IM     => ib_im,

            OX_RE     => oa_re,
            OX_IM     => oa_im,
            OY_RE     => ob_re,
            OY_IM     => ob_im,

            RST       => rst,
            CLK       => clk
        );
end generate;

end int_fly_fd2;