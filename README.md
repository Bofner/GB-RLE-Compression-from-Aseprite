# Game Boy RLE Compression from Aseprite
# Asepriteからゲームボーイのランレングス圧縮
 Turn Aseprite files into a run length encoding compressed .inc file using Aseprite's scripting feature.
 
 AsepriteのスクリプトでAsepriteのファイルはランレングス圧縮の.incファイルになることができます。
 
 Actual conversion from Aseprite to Game Boy data is done using boombuler's gbexport script, which allows for both tiles and tile maps.
 
 Asepriteのファイルからゲームボーイのデータに変わる方法はboombulerさんのgbexportのスクリプトを使えましたからタイルとマップデータに変わられます。
 
 This can be found at https://github.com/boombuler/aseprite-gbexport
 
 上のリンクにそのオリジナルのスクリプトにあります。
 
 I've modified the code to skip the conversion and instead write the data in a special format that can handle both raw data or RLE compressed data. 
 I've included assembly code for interpreting the .inc file as well, which I highly recommend putting into your game's code if you wish to use this script. 
 
 このプログラムはランレングス圧縮のデータか生データを特別の.incファイルに書きます。このスクリプトを使えたかったらこのリポジトリの中にあるアセンブリコードを自分のゲームのどこかに
 入れたほうがいいです。

 ## How to use:
 ## 使え方:

 Start by having an indexed image that contains 4 colors. They don't have to be greyscale, so long as there are only 4. 
 
 最初にAsepriteで4色インデクスの写真は必要です。何でもの4色は大丈夫です。白黒じゃなくてもいいです。
 
 ![](https://github.com/Bofner/GB-RLE-Compression-from-Aseprite/blob/main/images/export.jpg)

 Next, select the script.
 
 次にスクリプトを選んでください。
 
![](https://github.com/Bofner/GB-RLE-Compression-from-Aseprite/blob/main/images/scripts.jpg)

 The script allows for exporting a map, choosing your file names, and exporting in 8x16 if you want to export tiles for 8x16 size sprites. 
 
 タイルとマップファイルを書き出せます。書き出すファイルの名前選べます。スプライトを書き出す場合、8x16のフォーマットできます。

 ![](https://github.com/Bofner/GB-RLE-Compression-from-Aseprite/blob/main/images/export.jpg)
  

## Notes:
## ノート：
 
 I use WLA-DX, so that's's the way it exports for now. Perhaps I'll update it for RGBDS in the future.
 
 僕はWLA-DXのアセンブラーを使いますから.incファウルのフォーマットはWLA-DXのフォーマットです。いつもRGBDSの書き出すフォーマットのサポートを付け足すかもしれません。

 I've also included the hardware.inc file from RGBDS, but updated for WLA-DX.
 
 そしてRGBDSのhardware.incファイルはWLA-DXのフォーマットに変わったファイルもこのリポジトリにあります。
 
 ASM decompression code is also included for use in your assembly files.
 
 アセンブリの解凍コードもあります。このスクリプトを使ったら、このアセンブリコードもぜひ使ってください。
