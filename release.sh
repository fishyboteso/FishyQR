VERSION="$(cat FishyQR.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
rm FishyQR*.zip
mkdir FishyQR
mkdir FishyQR/luaqrcode
cp luaqrcode/qrencode.lua FishyQR/luaqrcode/qrencode.lua
cp FishyQR.txt FishyQR.lua Bindings.xml FishyQR
7z a -r FishyQR-$VERSION.zip FishyQR
rm -rf FishyQR