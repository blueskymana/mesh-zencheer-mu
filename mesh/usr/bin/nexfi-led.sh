#!/bin/sh 

# multi-base color led mechanism.

leds_path="/sys/devices/platform/leds-gpio/leds"

netled_gpio1_brightness=ap147:green:lan3/brightness
netled_gpio2_brightness=ap147:green:lan4/brightness

netled_gpio1_trigger=ap147:green:lan3/trigger
netled_gpio2_trigger=ap147:green:lan4/trigger

netled_init() {
    echo none > $leds_path/$netled_gpio1_trigger 
    echo none > $leds_path/$netled_gpio2_trigger 
    echo 1 > $leds_path/$netled_gpio1_brightness 
    echo 1 > $leds_path/$netled_gpio2_brightness 
}

netled_green_on() {
    netled_init
    echo 0 > $leds_path/$netled_gpio1_brightness 
    echo 1 > $leds_path/$netled_gpio2_brightness 
}

netled_magenta_on() {
    netled_init
    echo 0 > $leds_path/$netled_gpio1_brightness 
    echo 0 > $leds_path/$netled_gpio2_brightness 
}

netled_red_on() {
    netled_init
    echo 1 > $leds_path/$netled_gpio1_brightness 
    echo 0 > $leds_path/$netled_gpio2_brightness 
}


netled_red_blink() {
    netled_init
    echo timer > $leds_path/$netled_gpio2_trigger 
}

# Communication Link Quality  Finite-State-Machine strategy.
tq_state_lv1="lv1"
tq_state_lv2="lv2"
tq_state_lv3="lv3"
tq_state_init="init"
priv_tq_state=$tq_state_init
curr_tq_state="tq_state_init"

tq_th_alpha=$(uci get mesh.@net-led[0].alpha)
tq_th_beta=$(uci get mesh.@net-led[0].beta)

linktq_fsm()
{
    tq=$1

    if [ $tq -gt $tq_th_alpha ];
    then
        curr_tq_state=$tq_state_lv1
    elif [ $tq -gt $tq_th_beta ];
    then
        curr_tq_state=$tq_state_lv2
    else
        curr_tq_state=$tq_state_lv3
    fi
    

    if [ "$curr_tq_state" != "$priv_tq_state" ];
    then
        case $curr_tq_state in
            $tq_state_lv1 )
                netled_green_on
                ;;
            $tq_state_lv2 )
                netled_magenta_on
                ;;
            $tq_state_lv3 )
                netled_red_on
                ;;
            * )
                echo "lnktq_fsm function error."
                ;;
        esac
        priv_tq_state=$curr_tq_state
    fi
}

# Network led  Finite-State-Machine strategy.
led_state_join="join"
led_state_alone="alone"
led_state_init="init"
priv_led_state=$led_state_init
curr_led_state=$led_state_init
timeout_thresh=$(uci get mesh.@net-led[0].timeout)


netled_fsm()
{
    max_tq=0
    nodes_val=$(batctl o | grep -v 'B.A.T' | grep -v 'Nexthop' | sed s/*//g | awk '{print $2"@"$3"@"$4}')

    for i in $nodes_val
    do
        df=$(/bin/echo $i | awk -F "@" '{print $1}')
        tq=$(/bin/echo $i | awk -F "@" '{print $2 $3}')

        tq_real=$(echo $tq | sed s/[[:space:]]//g | awk -F "(" '{print $2}' | awk -F ")" '{print $1}')
        [ $(echo $df | awk -F "\." '{print $1}') -lt $timeout_thresh ] && [ $max_tq -lt $tq_real ] && max_tq=$tq_real
    done

    # batctl o | grep -v 'B.A.T' | grep -v 'Nexthop'

    if [ $max_tq -eq 0 ]
    then
        curr_led_state=$led_state_alone 
    else
        curr_led_state=$led_state_join
    fi 

    [ "$curr_led_state" = "$led_state_join" ] && linktq_fsm $max_tq  

    if [ "$curr_led_state" != "$priv_led_state" ]
    then
        case $curr_led_state in
            $led_state_alone )
                netled_red_blink
                ;;
            * )
                ;;
        esac
        priv_led_state=$curr_led_state
    fi

}

# main program loop.
while :
do
    netled_fsm
    sleep 1
done
