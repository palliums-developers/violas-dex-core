#!/bin/bash -e

if  [ ! -n "$1" ] ;then
    echo "you have not input a word!"
    exit 0
else
    echo "the word you input is $1"
fi

addr=$1


sed -i "s/0x7257c2417e4d1038e1817c8f283ace2e/$addr/g" *.move

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")


./move-build -f exchange.move -s $addr -d $dependences

mv ./move_build_output/modules/0_Exchange.mv ./move_build_output/modules/exchange.mv

./move-build -f initialize.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/initialize.mv

./move-build -f publish_reserve.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/publish_reserve.mv

./move-build -f add_liquidity.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/add_liquidity.mv

./move-build -f remove_liquidity.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/remove_liquidity.mv

./move-build -f violas_to_token_swap.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/violas_to_token_swap.mv

./move-build -f token_to_violas_swap.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/token_to_violas_swap.mv

./move-build -f token_to_token_swap.move -s $addr -d $dependences \
            exchange.move
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/token_to_token_swap.mv

sed -i "s/$addr/0x7257c2417e4d1038e1817c8f283ace2e/g" *.move