# RGB LED Control for iCE40 FPGA

This project implements a simple RGB LED controller using the iCE40 FPGA. The design includes a Verilog module that controls the RGB LED based on input signals for color selection. A testbench is provided to verify the functionality of the RGB LED module through simulation.

## Project Structure

- `src/rgb_led.v`: Contains the Verilog code for the RGB LED module.
- `tb/rgb_led_tb.v`: Testbench for the RGB LED module, providing various test cases.
- `pins.pcf`: Pin assignments for the iCE40 FPGA, mapping module signals to physical pins.
- `Makefile`: Build instructions for synthesizing the Verilog code and generating programming files.
- `README.md`: Documentation for the project.

## Building the Project

To build the project, use the provided Makefile. Run the following command in the project directory:

```
make
```

This will synthesize the Verilog code, generate the necessary files, and prepare the design for programming the FPGA.

## Programming the FPGA

After building the project, you can program the iCE40 FPGA using the following command:

```
make prog
```

Ensure that the FPGA is connected and recognized by your programming tool.

## Additional Notes

- Ensure that you have the necessary tools installed, such as Yosys, Arachne-PNR, and Icepack.
- Modify the `pins.pcf` file as needed to match your specific hardware setup.
- The testbench can be modified to include additional test cases for further verification of the RGB LED functionality.