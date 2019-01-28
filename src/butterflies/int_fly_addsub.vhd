-------------------------------------------------------------------------------
--
-- Title       : int_fly_addsub
-- Design      : FFT SPDF
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
-- Version 1.0 : 11.01.2019
--
-- Description : Single-Path Delay-Feedback butterfly Radix-2 (Simple FD)
--
-- X = (A+B)
-- Y = (A-B)
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

entity int_fly_addsub is
    generic (
        NFFT       : integer:=0;  --! log2 of N points
        STAGE      : integer:=0;  --! Butterfly stages        
        DTW        : integer:=16; --! Data width
        XUSE       : boolean:=FALSE; --! Use Add/Sub scheme or use delay data path
        XSER       : string:="OLD" --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    );
    port (
        DI_RE      : in  std_logic_vector(DTW-1 downto 0); --! Re even input data
        DI_IM      : in  std_logic_vector(DTW-1 downto 0); --! Im even input data
        DI_EN      : in  std_logic; --! Data clock enable

        DO_RE      : out std_logic_vector(DTW downto 0); --! Re even output data
        DO_IM      : out std_logic_vector(DTW downto 0); --! Im even output data
        DO_VL      : out std_logic; --! Output data valid
        
        RST        : in  std_logic; --! Global Reset
        CLK        : in  std_logic --! DSP Clock
    );
end int_fly_addsub;

architecture int_fly_addsub of int_fly_addsub is

begin

xFD1: if (STAGE = 0) generate
    xFD: entity work.int_fly_fd
        generic map (
            DTW          => DTW,
            XUSE         => XUSE,
            XSER         => XSER
        )
        port map (
            RST          => RST,
            CLK          => CLK,

            DI_RE        => DI_RE,
            DI_IM        => DI_IM,
            DI_EN        => DI_EN,
            
            DO_RE        => DO_RE,
            DO_IM        => DO_IM,
            DO_VL        => DO_VL
        );
end generate;

xFD2: if (STAGE = 1) generate
    xFD2: entity work.int_fly_fd2
        generic map (
            DTW          => DTW,
            XUSE         => XUSE,
            XSER         => XSER
        )
        port map (
            RST          => RST,
            CLK          => CLK,

            DI_RE        => DI_RE,
            DI_IM        => DI_IM,
            DI_EN        => DI_EN,

            DO_RE        => DO_RE,
            DO_IM        => DO_IM,
            DO_VL        => DO_VL
        );
end generate;

xHIGH: if (STAGE > 1) generate
    xSPD: entity work.int_fly_spd
        generic map (
            STAGE        => STAGE,
            NFFT         => NFFT,
            DTW          => DTW,
            XUSE         => XUSE,
            XSER         => XSER
        )   
        port map (
            RST          => RST,
            CLK          => CLK,

            DI_RE        => DI_RE,
            DI_IM        => DI_IM,
            DI_EN        => DI_EN,

            DO_RE        => DO_RE,
            DO_IM        => DO_IM,
            DO_VL        => DO_VL
        );
end generate;

--xFD1: if (STAGE = (NFFT-1)) generate
--    xFD: entity work.int_fly_fd
--        generic map ( DTW, XUSE, XSER )
--        port map ( RST,CLK, DI_RE, DI_IM, DI_EN, DO_RE, DO_IM, DO_VL);
--end generate;

--xFD2: if (STAGE = (NFFT-2)) generate
--    xFD: entity work.int_fly_fd2
--        generic map ( DTW, XUSE, XSER )
--        port map ( RST,CLK, DI_RE, DI_IM, DI_EN, DO_RE, DO_IM, DO_VL);
--end generate;

--xHIGH: if (STAGE < (NFFT-2) generate
--    xSPD: entity work.int_fly_spd
--        generic map ( NFFT, STAGE, DTW, XUSE, XSER )
--        port map ( RST,CLK, DI_RE, DI_IM, DI_EN, DO_RE, DO_IM, DO_VL);
--end generate;

end int_fly_addsub;