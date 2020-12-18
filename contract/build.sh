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

./move-build exchange.move -s $addr -d $dependences

mv ./move_build_output/modules/0_Exchange.mv ./move_build_output/modules/exchange.mv

./move-build initialize.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/initialize.mv

./move-build add_currency.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/add_currency.mv

./move-build add_liquidity.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/add_liquidity.mv

./move-build remove_liquidity.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/remove_liquidity.mv

./move-build swap.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/swap.mv

./move-build set_next_rewardpool.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/set_next_rewardpool.mv

./move-build withdraw_mine_reward.move -s $addr -d $dependences exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/withdraw_mine_reward.mv

sed -i "s/$addr/0x7257c2417e4d1038e1817c8f283ace2e/g" *.move