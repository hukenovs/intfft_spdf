-------------------------------------------------------------------------------
--
-- Title       : int_fly_twd
-- Design      : FFT SPDF
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
-- Description : Butterfly: multiply data and twiddles
--
-- DI -> {IA, IB} -> {IA, (IB * WW)} -> {OA, OB} -> DO
--
-- Algorithm: Decimation in frequency
--
--    X = (A+B), 
--    Y = (A-B)*W; 
--
-- Algorithm: Decimation in time
--
--    X = A+B*W, 
--    Y = A-B*W; 
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

entity int_fly_twd is
    generic (
        NFFT       : integer:=0;   --! log2 of N points
        STAGE      : integer:=0;   --! Butterfly stages
        DTW        : integer:=16;  --! Data width
        TWD        : integer:=16;  --! Twiddles width
        XSER       : string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE      : in  std_logic_vector(DTW-1 downto 0); --! Re even input data
        DI_IM      : in  std_logic_vector(DTW-1 downto 0); --! Im even input data
        DI_EN      : in  std_logic; --! Data clock enable

        WW_RE      : in  std_logic_vector(TWD-1 downto 0); --! Re even input data
        WW_IM      : in  std_logic_vector(TWD-1 downto 0); --! Im even input data

        DO_RE      : out std_logic_vector(DTW downto 0); --! Re even output data
        DO_IM      : out std_logic_vector(DTW downto 0); --! Im even output data
        DO_VL      : out std_logic; --! Output data valid
        
        RST        : in  std_logic; --! Global Reset
        CLK        : in  std_logic  --! DSP Clock
    );
end int_fly_twd;

architecture int_fly_twd of int_fly_twd is

function find_delay(sVAR : string; iDW, iTW: integer) return integer is
    variable ret_val   : integer;
    variable loDSP     : integer;
    variable hiDSP     : integer;
begin
    if (sVAR = "OLD") then loDSP := 25; else loDSP := 27; end if;
    if (sVAR = "OLD") then hiDSP := 43; else hiDSP := 45; end if;

    ---- TWIDDLE WIDTH UP TO 18 ----
    if (iTW < 19) then
        if (iDW <= loDSP) then
            ret_val := 4;
        elsif ((iDW > loDSP) and (iDW < hiDSP)) then
            ret_val := 6;
        else
            ret_val := 8;
        end if;
    ---- TWIDDLE WIDTH FROM 18 TO 25 ----
    elsif ((iTW > 18) and (iTW <= loDSP)) then
        if (iDW < 19) then
            ret_val := 4;
        elsif ((iDW > 18) and (iDW < 36)) then
            ret_val := 6;
        else
            ret_val := 8;
        end if;     
    else
        ret_val := 0; 
    end if;
    return ret_val; 
end function find_delay;

constant DATA_DELAY : integer:=find_delay(XSER, DTW, TFW);
type std_logic_delayN is array (DATA_DELAY-1 downto 0) of std_logic_vector(DTW-1 downto 0);

signal dre_zz      : std_logic_delayN;
signal dim_zz      : std_logic_delayN;
signal ena_zz      : std_logic_vector(DATA_DELAY-1 downto 0);
signal ena_dt      : std_logic;

---- Select FFT stage ----
constant NST       : integer:=NFFT-STAGE;
signal cnt_mux     : std_logic_vector(NST-1 downto 0):=(others=>'0');

signal mlt_re      : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal mlt_im      : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal del_re      : std_logic_vector(DTW-1 downto 0):=(others=>'0');
signal del_im      : std_logic_vector(DTW-1 downto 0):=(others=>'0');

begin

------------ Delay input data ------------
pr_del: process(clk) is
begin
    if rising_edge(clk) then
        dre_zz <= dre_zz(DATA_DELAY-2 downto 0) & DI_RE;
        dim_zz <= dim_zz(DATA_DELAY-2 downto 0) & DI_IM;
        ena_zz <= ena_zz(DATA_DELAY-2 downto 0) & DI_EN;
    end if;
end process;

------------ Delay Assign ------------
ena_dt <= ena_zz(DATA_DELAY-1);
del_re <= dre_zz(DATA_DELAY-1);
del_im <= dim_zz(DATA_DELAY-2);

------------ Complex Multiplier ------------
xCMLT: entity work.int_cmult_dsp48
    generic map (
        DTW       => DTW,
        TWD       => TWD,
        XSER      => XSER
    )
    port map (
        DI_RE     => DI_RE,
        DI_IM     => DI_IM,
        WW_RE     => WW_RE,
        WW_IM     => WW_IM,

        DO_RE     => mlt_re,
        DO_IM     => mlt_im,

        RST       => RST,
        CLK       => CLK
    );

------------ Counter for mux output flow ------------
pr_mux: process(clk) is
begin
    if rising_edge(clk) then
        if (RST = '1') then
            cnt_mux <= (others => '0');
        else
            if (ena_dt = '1') then
                cnt_mux <= cnt_mux + '1';
            end if;
        end if;
    end if;
end process;

------------ Output mux data ------------
pr_mux: process(clk) is
begin
    if rising_edge(clk) then
        DO_VL <= ena_dt;
        if (cnt_mux(NST-1) = '0') then
            DO_RE <= mlt_re;
            DO_IM <= mlt_im;
        else
            DO_RE <= del_re;
            DO_IM <= del_im;
        end if;
    end if;
end process;

end int_fly_twd;