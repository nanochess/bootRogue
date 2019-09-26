nasm -f bin %1.asm -Dcom_file=1 -l rogue.lst -o rogue.com
nasm -f bin %1.asm -o rogue.img
find /v /c "" %1.asm
rem rogue

