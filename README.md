# Integer SPDF-FFT/IFFT Radix-2
**SPDF DIT DIF Radix-2 FFT IFFT**  
Integer (Scaled / Unscaled) Radix-2 **Single Path Delay Feedback** FFT / IFFT cores 

# Integer FFT/IFFT cores
This project contains **fully pipelined** integer **unscaled** and **scaled (truncated LSB)** FFT/IFFT cores for FPGA, Scheme: Radix-2, Decimation in frequency and decimation in time;    
Integer data type and twiddles with configurable data width.  
No need to align data and twiddles between FFT stages.  
Improved area resources: Calculate twiddles with Taylor series (2-order) when (stages > 11) instead of store all data in BRAMs.  

**Code language** - VHDL
**Vendor**: Xilinx, 6/7-series, Ultrascale, Ultrascale+;  

> _Smallest FPGA resourses and highest processing frequency that you ever seen!_   

License: GNU GPL 3.0.

### Main information

| **Title**         | Universal integer SPDF FFT cores (Xilinx FPGAs) |
| -- | -- |
| **Author**        | Alexander Kapitanov                             |
| **Contact**       | sallador@bk.ru                                  |
| **Project lang**  | VHDL                                            |
| **Vendor**        | Xilinx: 6/7-series, Ultrascale, US+             |
| **Release Date**  | 15 Jan 2019                                     |

### List of complements:
- FFTs:
   * int_spdf_fftNk – Full-precision or Scaled FFT, Radix-2, DIF, input flow - normal, output flow - bit-reversed.
   * int_spdf_ifftNk – Full-precision or Scaled IFFT, Radix-2, DIT, input flow - bit-reversed, output flow - normal.
- Butterflies:
   * int_spdf_dif2 – Full-precision or Scaled butterfly Radix-2, decimation in frequency,
   * int_spdf_dit2 – Full-precision or Scaled butterfly Radix-2, decimation in time,

- Arithmetic:
   * int_fly_twd – Multiply data and twiddles,
   * int_fly_addsub – Single-path delay feedback and adder / subtractor,
     * int_fly_fd – SPDF for stage = 0, (based on FDs),
     * int_fly_fd2 – SPDF for stage = 1, (based on double-FDs),
     * int_fly_spd – SPDF for stages > 1, (based on Distributed RAM and Block RAM),

- Complex multipliers:
   * int_cmult_dsp48 – main integer complex multiplier contains several cmults:
     * int_cmult18x25_dsp48 – simple 25 x 18 two’s-complement half-complex-multiplier,
     * int_cmult_dbl18_dsp48 – double 42(44) x 18 two’s-complement half-complex-multiplier,
     * int_cmult_dbl35_dsp48 – double 25(27) x 35 two’s-complement half-complex-multiplier,
     * int_cmult_trpl18_dsp48 – triple 59(61) x 18 two’s-complement half-complex-multiplier,
     * int_cmult_trpl52_dsp48 – triple 25(27) x 52 two’s-complement half-complex-multiplier,
> "half" means that you should set output flow: Re or Im part.

- Multipliers:
  * mlt42x18_dsp48e1 – 42 x 18 two’s-complement multiplier (DSP48E1), del.: 4 taps, res.: 2 DSPs.
  * mlt59x18_dsp48e1 – 59 x 18 two’s-complement multiplier (DSP48E1), del.: 5 taps, res.: 3 DSPs.
  * mlt35x25_dsp48e1 – 35 x 25 two’s-complement multiplier (DSP48E1), del.: 4 taps, res.: 2 DSPs.
  * mlt52x25_dsp48e1 – 52 x 25 two’s-complement multiplier (DSP48E1), del.: 5 taps, res.: 3 DSPs.
  * mlt44x18_dsp48e2 – 44 x 18 two’s-complement multiplier (DSP48E2), del.: 4 taps, res.: 2 DSPs.
  * mlt61x18_dsp48e2 – 61 x 18 two’s-complement multiplier (DSP48E2), del.: 5 taps, res.: 3 DSPs.
  * mlt35x27_dsp48e2 – 35 x 27 two’s-complement multiplier (DSP48E2), del.: 4 taps, res.: 2 DSPs.
  * mlt52x27_dsp48e2 – 52 x 27 two’s-complement multiplier (DSP48E2), del.: 5 taps, res.: 3 DSPs.

- Adder:
  * int_addsub_dsp48 – based on DSP48, up to 96-bit two’s-complement addition/substraction.

- Twiddles:
  * rom_twiddle_int – 1/4-periodic signal, twiddle factor generator based on memory and sometimes uses DSP48 units for large FFTs
  * row_twiddle_tay – twiddle factor generator which used Taylor scheme for calculation twiddles.

- Bit-reverse:
  * int_bitrev_ord – simple converter data from bit-reverse to natural order.

### Link (Russian collaborative IT blog)
  * https://habr.com/users/capitanov/  
  
### Authors:
  * Kapitanov Alexander  
  
### Release:
  * 2019/15/01.  

### License:
  * GNU GPL 3.0.  
