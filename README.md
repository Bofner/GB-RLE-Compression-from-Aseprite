# Game Boy RLE Compression from Aseprite
 Turn Aseprite files into a run length encoding compressed .inc file using Aseprite's scripting feature
 
 Actual conversion from Aseprite to Game Boy data is done using boombuler's gbexport script
 
 This can be found at https://github.com/boombuler/aseprite-gbexport
 
 I've modified the code to output as a binary file that is then compressed using RLE
 
 I use WLA-DX, so thta's the way it exports for now. Perhaps I'll update it for RGBDS in the future

 I've also included the hardware.inc file from RGBDS, but updated for WLA-DX
 
 ASM decmpression code is also included for use in your assembly files.
