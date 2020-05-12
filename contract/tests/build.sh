
cp -fr ../modules ./
cp ../token.move ./modules/
cp ../exbase.move ./modules/
cp ../exchange.move ./modules/

sed -i "s/0x7257c2417e4d1038e1817c8f283ace2e/0xeac261c89adafb5ab577bca15c0c187d/g" ./modules/*.move

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")

../move-build -f test_step0_a0_a1_a2.move -s 0xeac261c89adafb5ab577bca15c0c187d \
        -o output/step0 -d $dependences

../move-build -f test_step1_a0.move -s 0xeac261c89adafb5ab577bca15c0c187d \
        -o output/step1 -d $dependences

../move-build -f test_step2_a0.move -s 0xeac261c89adafb5ab577bca15c0c187d \
        -o output/step2 -d $dependences

rm -fr modules