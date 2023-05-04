rm FishyQR.zip
mkdir FishyQR
mkdir FishyQR/luaqrcode
cp luaqrcode/qrencode.lua FishyQR/luaqrcode/qrencode.lua
cp FishyQR.txt FishyQR.lua Bindings.xml FishyQR
7z a -r FishyQR.zip FishyQR
rm -rf FishyQR