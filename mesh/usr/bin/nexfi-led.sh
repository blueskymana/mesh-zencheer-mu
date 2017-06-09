#!/bin/sh
# leds driver interface file

LED_PATH="/sys/devices/platform/leds-gpio/leds"

GREEN_TRIGGER="nexfi:green/trigger" 
RED_TRIGGER="nexfi:red/trigger"
ZQ_GREEN_TRIGGER="ap147:led:green/trigger" 
ZQ_RED_TRIGGER="ap147:led:red/trigger"

TRI_RED="nexfi:tb-red/brightness"
TRI_GREEN="nexfi:tb-green/brightness"
TRI_BLUE="nexfi:tb-blue/brightness"
ZQ_TRI_RED="ap147:led:red/brightness"
ZQ_TRI_GREEN="ap147:led:green/brightness"

TRI_RED_TRIGGER="nexfi:tb-red/trigger"
TRI_GREEN_TRIGGER="nexfi:tb-green/trigger"


# wireless channel.
get_channel_freq()
{
    return $(iw dev adhoc0 info | grep channel | awk -F ' ' '{ print $2 }')
}

# network led control
trig_green()
{
    echo $1 > $LED_PATH/$GREEN_TRIGGER
}

# system led control
trig_red()
{
    echo $1 > $LED_PATH/$RED_TRIGGER
}

ZQ_trig_green()
{
    echo $1 > $LED_PATH/$ZQ_GREEN_TRIGGER
}

# system led control
ZQ_trig_red()
{
    echo $1 > $LED_PATH/$ZQ_RED_TRIGGER
}
# tri-base color control
turn_on_tri_red()
{
    echo 1 > $LED_PATH/$TRI_RED
    echo 1 > $LED_PATH/$TRI_GREEN
    echo 1 > $LED_PATH/$TRI_BLUE
}
ZQ_turn_on_tri_red()
{
    echo 0 > $LED_PATH/$ZQ_TRI_RED
    echo 1 > $LED_PATH/$ZQ_TRI_GREEN
}

turn_on_tri_green()
{
    echo 0 > $LED_PATH/$TRI_RED
    echo 0 > $LED_PATH/$TRI_GREEN
    echo 1 > $LED_PATH/$TRI_BLUE
}

ZQ_turn_on_tri_green()
{
    echo 1 > $LED_PATH/$ZQ_TRI_RED
    echo 0 > $LED_PATH/$ZQ_TRI_GREEN
 }
turn_on_tri_blue()
{
    echo 0 > $LED_PATH/$TRI_RED
    echo 1 > $LED_PATH/$TRI_GREEN
    echo 0 > $LED_PATH/$TRI_BLUE
}
ZQ_turn_on_tri_yellow()
{
    echo 0 > $LED_PATH/$ZQ_TRI_RED
    echo 0 > $LED_PATH/$ZQ_TRI_GREEN
 }

turn_off_tri_all()
{
    echo 0 > $LED_PATH/$TRI_RED
    echo 1 > $LED_PATH/$TRI_GREEN
    echo 1 > $LED_PATH/$TRI_BLUE
}
 ZQ_turn_off_tri_all ()
 {
    echo 1 > $LED_PATH/$ZQ_TRI_RED
    echo 1 > $LED_PATH/$ZQ_TRI_GREEN
 }
trig_tri_red()
{
    echo $1 > $LED_PATH/$TRI_RED_TRIGGER
}

trig_tri_green()
{
    echo $1 > $LED_PATH/$TRI_GREEN_TRIGGER
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

ping_mac() {
    mac=$1
    a=$(/usr/sbin/batctl ping -c 1 -t 1 "$mac")
    return $?
}

net_led_fsm()
{
    nexhop=$(batctl n | sed '1,2 d' | grep -v "range")
    
    #all_nodes_mac=$(/usr/sbin/batctl n | grep -v 'B.A.T' | grep -v 'Neighbor' | awk '{print $2,$4}')
    all_nodes_mac=$(/usr/sbin/batctl o | grep -v 'B.A.T' | grep -v 'Nexthop' | awk '{print $2"@"$4}')
    mac_resp=1

    #for mac in $all_nodes_mac
        #do ping_mac $mac
        #ping_resp=$?
        #echo "ping mac:" $mac " resp:" $ping_resp
        #if [ $ping_resp == 0 ];
        #then
  #          echo "set mac_resp to 0"
        #    mac_resp=0
        #    break
        #fi
  #  done
  
  for node in $all_nodes_mac
        do
        mac_addr=$(/bin/echo $node | awk -F '@' '{print $1}')
        tp=$(/bin/echo $node | awk -F '@' '{print $2}')
        echo $mac_addr
        tp_real=${tp:1:3}
        ping_mac $mac_addr
        ping_resp=$?

        if [ $ping_resp == 0 ];
        then
                echo "set mac_resp to 0"
                ZQ_trig_red "default-on"
                if [ $tp_real -gt 200 ];
                then
                        ZQ_turn_on_tri_green
                        echo "tp_real grea than 200"
                else
                        ZQ_turn_on_tri_yellow
                        echo "tp_real less than 200"
                fi
                mac_resp=0
                break
        fi
done

    echo "mac_resp: " $mac_resp

    if [ -z "$nexhop" ]
    then
        curr_state=$state_alone 
    else
        if [ $mac_resp == 0 ];
        then
            curr_state=$state_join
        else
            curr_state=$state_alone
        fi
    fi 

    if [ "$curr_state" != "$priv_state" ]
    then
        case $curr_state in
            $state_join )
                  ZQ_trig_red "default-on"
                if [ $tp_real -gt 200 ];
                then          
                                                                        ZQ_turn_on_tri_green 
                else
                                                                 ZQ_turn_on_tri_yellow 
                fi
                #trig_green "default-on"
                #sleep 10
                #ZQ_trig_red "default-on"
                #ZQ_turn_on_tri_green       
                ;;
            $state_alone )
                #trig_green "timer"
                ZQ_turn_off_tri_all
                ZQ_trig_red "timer"
                ;;
            * )
                echo "net_led_fsm function state error."
                ;;
        esac

        priv_state=$curr_state
    fi
}

# tri-base color finite state machine.
state_tri_red="tri-red"
state_tri_blue="tri-blue"
state_tri_green="tri-green"
state_tri_none="tri_none"
tri_priv_state=$state_tri_none

tri_led_fsm_init()
{
    tri_priv_state=$state_tri_none
}


tri_led_fsm()
{
    get_channel_freq
    channel=$?

    tri_curr_state=$state_tri_none
    case $channel in
        "3" )
           tri_curr_state=$state_tri_red 
            ;;
        "8" )
            tri_curr_state=$state_tri_green
            ;;
        "11" )
            tri_curr_state=$state_tri_blue
            ;;
        * )
            tri_curr_state=$state_tri_none
            ;;
    esac

    if [ "$tri_priv_state" != "$tri_curr_state" ]
    then
        case $tri_curr_state in
            $state_tri_blue )
                turn_on_tri_blue 
                ;;
            $state_tri_red )
                turn_on_tri_red
                ;;
            $state_tri_green )
                turn_on_tri_green 
                ;;
            * )
                #turn_off_tri_all
                ;;
        esac
        
        tri_priv_state=$tri_curr_state
    fi
}


LEDPIPE="/tmp/ledfifo"
state_tbled_red_blink_on="tbled:red:blink:on:0"
state_tbled_red_blink_off="tbled:red:blink:off"
state_tbled_green_blink_on_1="tbled:green:blink:on:1"
state_tbled_none="none"
priv_state_led_sync=$state_tbled_none
blink_time="0"
is_blink="0"

led_sync_fsm_init()
{
    priv_state_led_sync=$state_led_none
}
#syc led fsm
led_sync_fsm()
{
    curr_state=""
    read -t 1 curr_state <> $LEDPIPE 
    if [ -z "$curr_state" ];
    then
        curr_state=$state_tbled_none
    fi

    if [ "$curr_state" = "$state_tbled_red_blink_on" ];
    then
        turn_off_tri_all
        trig_tri_red timer
        priv_state_led_sync=$state_tbled_red_blink_on
    elif [ "$curr_state" = "$state_tbled_red_blink_off" ];
    then
        trig_tri_red none
        net_led_fsm_init
        tri_led_fsm_init
        priv_state_led_sync=$state_tbled_none
    fi

    if [ "$curr_state" = "$state_tbled_green_blink_on_1" ];
    then
        blink_time="2"
        if [ "$is_blink" = "0" ];
        then
            is_blink="1"
            turn_off_tri_all
            trig_tri_green timer
            priv_state_led_sync=$state_tbled_green_blink_on_1
        fi
    fi

    if [ $blink_time -gt "0" ];
    then
        blink_time=`expr $blink_time - 1`
    fi

    if [ "$is_blink" = "1" ] && [ $blink_time -eq "0" ];
    then
        turn_off_tri_all
        trig_tri_green none
        led_sync_fsm_init
        net_led_fsm_init
        tri_led_fsm_init
        is_blink="0"
        priv_state_led_sync=$state_tbled_none
    fi

    if [ "$priv_state_led_sync" = "$state_tbled_none" ];
    then
        net_led_fsm
        tri_led_fsm
    fi
}



ZQ_trig_red "timer"
ZQ_trig_green "none"
ZQ_turn_off_tri_all

while :
do
    led_sync_fsm
done
