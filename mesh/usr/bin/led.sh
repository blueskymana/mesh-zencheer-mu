#!/bin/sh

LED_PATH="/sys/devices/platform/leds-gpio/leds"
WPS_TRIGGER="db120:green:wps/trigger" 

# network led control
trig_green()
{
    echo $1 > $LED_PATH/$WPS_TRIGGER
}

# network led finite state machine.
state_join="join"
state_alone="alone"
state_none="none"
priv_state=$state_none

net_led_fsm_init()
{
    priv_state=$state_none
}

net_led_fsm()
{
    timeout=1
    neighbors=$(batctl n | sed '1,2 d' | grep -v "range" | awk -F " " '{print $3}' | awk -F "\." '{print $1}')

    for i in $neighbors;
    do
        if [ $i -lt 3 ];
        then
            timeout=0
            break
        fi
    done

    if [ $timeout -eq 1 ];
    then
        curr_state=$state_alone 
    else
        curr_state=$state_join
    fi 

    if [ "$curr_state" != "$priv_state" ]
    then
        case $curr_state in
            $state_join )
                trig_green "default-on"
                ;;
            $state_alone )
                trig_green "timer"
                ;;
            * )
                echo "net_led_fsm function state error."
                ;;
        esac

        priv_state=$curr_state
    fi
}

trig_green "none"
net_led_fsm_init

while :
do
    net_led_fsm
    sleep 1
done
